import Foundation
import Observation

/// Drives one writing chapter: the exchange of messages, and the report at the end.
///
/// The shape is the video call's, with the microphone taken out and the keyboard put
/// in — which means the whole end-of-conversation reviewer, offline and online both,
/// works here unchanged. What is different is that nothing she writes is graded as
/// she writes it: a chat that marks you wrong after every message is not a chat.
@MainActor
@Observable
final class ChatEngine {

    struct Message: Identifiable, Hashable {
        enum Who: Hashable { case anorcha, learner }
        let id = UUID()
        var who: Who
        /// Always in the language being learned.
        var text: String
        /// Anorcha's line in the learner's own language, behind a tap.
        var translation: String?
    }

    enum Phase: Equatable {
        case opening        // Anorcha is writing the first message
        case yourTurn
        case thinking       // Anorcha is writing her reply
        case reviewing
        case done
    }

    let chapter: WritingChapter
    let native: Language
    var target: Language { native.other }

    private(set) var messages: [Message] = []
    private(set) var phase: Phase = .opening
    private(set) var records: [CallTurnRecord] = []
    private(set) var review: CallReview?
    private(set) var startedAt = Date()

    /// What she is typing right now.
    var draft = ""
    /// Which of Anorcha's messages have been turned over to show the translation.
    var revealed: Set<UUID> = []
    /// Switched off after one failed request, so a dead key costs one wait and not six.
    private var live = true

    init(chapter: WritingChapter, native: Language) {
        self.chapter = chapter
        self.native = native
    }

    // MARK: - Where we are

    /// Messages she has written so far.
    var written: Int { records.count }
    var remaining: Int { max(0, chapter.turns - written) }
    var progress: Double { Double(written) / Double(max(1, chapter.turns)) }
    /// The last thing Anorcha said, which is what the next reply answers.
    private var lastFromAnorcha: Bilingual? {
        guard let message = messages.last(where: { $0.who == .anorcha }) else { return nil }
        return Bilingual(it: native == .it ? (message.translation ?? message.text) : message.text,
                         uz: native == .it ? message.text : (message.translation ?? message.text))
    }

    var wordsInDraft: Int {
        draft.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }
    /// Long enough to be an answer, and in the alphabet of the language being learned.
    var canSend: Bool {
        phase == .yourTurn && wordsInDraft >= chapter.minimumWords
    }

    var xpEarned: Int {
        let words = records.reduce(0) { $0 + $1.answer.split(separator: " ").count }
        return 20 + min(40, words)
    }

    // MARK: - The conversation

    func begin(provider: AIProvider, apiKey: String) async {
        guard messages.isEmpty else { return }
        startedAt = .now
        let opening = await compose(provider: provider, apiKey: apiKey, closing: false)
        append(anorcha: opening)
        phase = .yourTurn
    }

    /// Files what she wrote and asks Anorcha for the next message.
    func send(provider: AIProvider, apiKey: String) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .yourTurn, !text.isEmpty, let question = lastFromAnorcha else { return }

        messages.append(Message(who: .learner, text: text))
        records.append(CallTurnRecord(question: question, answer: text,
                                      seconds: 0, typed: true))
        draft = ""

        guard written < chapter.turns else {
            phase = .reviewing
            return
        }
        phase = .thinking
        let closing = written == chapter.turns - 1
        let reply = await compose(provider: provider, apiKey: apiKey, closing: closing)
        append(anorcha: reply)
        phase = .yourTurn
    }

    /// Ends the chapter early. What she has written is still reviewed and still counts.
    func finishEarly() {
        phase = records.isEmpty ? .done : .reviewing
    }

    private func append(anorcha line: Bilingual) {
        messages.append(Message(who: .anorcha,
                                text: line[target],
                                translation: line[native]))
    }

    /// Anorcha's next message: written by the assistant when there is one, and taken
    /// from the course's own question bank when there is not — so a writing chapter
    /// is a writing chapter offline too, just a less surprising one.
    private func compose(provider: AIProvider, apiKey: String, closing: Bool) async -> Bilingual {
        if live, AIClient.isConfigured(provider: provider, key: apiKey) {
            do {
                let turn = try await AIClient.chatMessage(provider: provider, key: apiKey,
                                                          briefing: chapter.briefing(native: native),
                                                          history: records,
                                                          target: target, native: native,
                                                          level: chapter.level,
                                                          closing: closing)
                return turn.reaction
            } catch {
                live = false
            }
        }
        return offlineLine(closing: closing)
    }

    /// The fallback script. Not a conversation, but a sequence of real prompts on the
    /// chapter's own subject — enough to keep her writing for the whole chapter.
    private func offlineLine(closing: Bool) -> Bilingual {
        if messages.isEmpty { return chapter.theme.opener }
        if closing { return Self.closings.randomElement() ?? chapter.theme.opener }
        let asked = records.count
        let follow = Self.followUps[chapter.theme.id] ?? Self.genericFollowUps
        return follow[(asked - 1 + follow.count) % follow.count]
    }

    // MARK: - The report

    func buildReview(curriculum: Curriculum, provider: AIProvider, apiKey: String) async {
        guard !records.isEmpty else {
            phase = .done
            return
        }
        if AIClient.isConfigured(provider: provider, key: apiKey) {
            if let remote = try? await AIClient.review(provider: provider, key: apiKey,
                                                       turns: records, target: target,
                                                       native: native, level: chapter.level) {
                review = remote
                phase = .done
                return
            }
        }
        review = CallReviewer.review(turns: records, native: native,
                                     curriculum: curriculum, level: chapter.level)
        phase = .done
    }

    /// How well it went, for the crown on the node: everything answered and nothing
    /// badly wrong is a clean run.
    var accuracy: Double {
        guard let review, !review.turns.isEmpty else { return records.isEmpty ? 0 : 0.7 }
        return Double(review.goodAnswers) / Double(review.turns.count)
    }

    /// The words she actually used, so the chapter feeds spaced repetition like any
    /// other node does — a word written under her own steam is a word she knows.
    func practisedPairs(from curriculum: Curriculum) -> [Pair] {
        let said = Set(records.flatMap { Grader.normalise($0.answer).split(separator: " ").map(String.init) })
        guard !said.isEmpty else { return [] }
        return chapter.vocabulary.filter { pair in
            let words = Grader.normalise(pair[target]).split(separator: " ").map(String.init)
            return !words.isEmpty && words.allSatisfy { said.contains($0) }
        }
    }

    // MARK: - Offline script

    private static let genericFollowUps: [Bilingual] = [
        Bilingual(it: "Ah sì? E perché?", uz: "Rostdanmi? Nega?"),
        Bilingual(it: "Raccontami di più.", uz: "Ko'proq aytib ber."),
        Bilingual(it: "E poi cos'è successo?", uz: "Keyin nima bo'ldi?"),
        Bilingual(it: "Con chi eri?", uz: "Kim bilan eding?"),
        Bilingual(it: "Tu cosa ne pensi?", uz: "Sen nima deb o'ylaysan?"),
    ]

    private static let closings: [Bilingual] = [
        Bilingual(it: "Bello sentirti! Ci scriviamo domani?", uz: "Gaplashganimiz yaxshi bo'ldi! Ertaga yozishamizmi?"),
        Bilingual(it: "Va bene, ora devo andare. A presto!", uz: "Mayli, endi ketishim kerak. Ko'rishguncha!"),
        Bilingual(it: "Grazie per avermelo raccontato. A dopo!", uz: "Aytib berganing uchun rahmat. Keyinroq gaplashamiz!"),
    ]

    private static let followUps: [String: [Bilingual]] = [
        "day": [
            Bilingual(it: "E la mattina com'era?", uz: "Ertalab qanday o'tdi?"),
            Bilingual(it: "Hai mangiato qualcosa di buono?", uz: "Mazali biror narsa yedingmi?"),
            Bilingual(it: "Chi hai visto oggi?", uz: "Bugun kimni ko'rding?"),
            Bilingual(it: "E domani cosa fai?", uz: "Ertaga nima qilasan?"),
        ],
        "plan": [
            Bilingual(it: "A che ora ti va bene?", uz: "Soat nechada qulay?"),
            Bilingual(it: "Dove ci troviamo?", uz: "Qayerda uchrashamiz?"),
            Bilingual(it: "Chi altro invitiamo?", uz: "Yana kimni taklif qilamiz?"),
            Bilingual(it: "Come ci arrivi?", uz: "U yerga qanday borasan?"),
        ],
        "favour": [
            Bilingual(it: "Quando ti servirebbe?", uz: "Qachon kerak bo'ladi?"),
            Bilingual(it: "Ti è già successo prima?", uz: "Avval ham shunday bo'lganmi?"),
            Bilingual(it: "Come posso aiutarti?", uz: "Qanday yordam bera olaman?"),
            Bilingual(it: "Sei sicura? Dimmi tutto.", uz: "Ishonchingiz komilmi? Hammasini ayting."),
        ],
        "place": [
            Bilingual(it: "Com'è il tempo lì?", uz: "U yerda ob-havo qanday?"),
            Bilingual(it: "Che cosa vedi dalla finestra?", uz: "Derazadan nima ko'rinadi?"),
            Bilingual(it: "Ci torneresti?", uz: "Yana borarmiding?"),
            Bilingual(it: "Con chi ci sei andata?", uz: "U yerga kim bilan bording?"),
        ],
        "food": [
            Bilingual(it: "Cucini tu o ordiniamo?", uz: "O'zing pishirasanmi yoki buyurtma qilamizmi?"),
            Bilingual(it: "Che cosa c'è in frigo?", uz: "Muzlatgichda nima bor?"),
            Bilingual(it: "Qual è il tuo piatto preferito?", uz: "Eng yoqtirgan taoming qaysi?"),
            Bilingual(it: "A che ora mangiamo?", uz: "Soat nechada ovqatlanamiz?"),
        ],
        "news": [
            Bilingual(it: "Come hai reagito?", uz: "Qanday munosabat bildirding?"),
            Bilingual(it: "L'hai detto a qualcuno?", uz: "Birovga aytdingmi?"),
            Bilingual(it: "E adesso cosa farai?", uz: "Endi nima qilasan?"),
            Bilingual(it: "Te lo aspettavi?", uz: "Buni kutgandingmi?"),
        ],
        "problem": [
            Bilingual(it: "Quando è cominciato?", uz: "Qachon boshlandi?"),
            Bilingual(it: "Hai già provato qualcosa?", uz: "Biror narsa qilib ko'rdingmi?"),
            Bilingual(it: "Vuoi che ti aiuti?", uz: "Yordam berishimni xohlaysanmi?"),
            Bilingual(it: "Secondo te di chi è la colpa?", uz: "Sencha kim aybdor?"),
        ],
        "memory": [
            Bilingual(it: "Chi c'era con noi?", uz: "Biz bilan kim bor edi?"),
            Bilingual(it: "In che stagione era?", uz: "Qaysi faslda edi?"),
            Bilingual(it: "Che cosa ricordi meglio?", uz: "Eng yaxshi nimani eslaysan?"),
            Bilingual(it: "Lo rifaresti?", uz: "Yana shunday qilarmiding?"),
        ],
    ]
}
