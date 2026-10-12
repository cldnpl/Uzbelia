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
    let native: Language = .en
    let target: Language

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

    init(chapter: WritingChapter, target: Language) {
        self.chapter = chapter
        self.target = target
    }

    // MARK: - Where we are

    /// Messages she has written so far.
    var written: Int { records.count }
    var remaining: Int { max(0, chapter.turns - written) }
    var progress: Double { Double(written) / Double(max(1, chapter.turns)) }
    /// The last thing Anorcha said, which is what the next reply answers.
    private var lastFromAnorcha: Bilingual? {
        guard let message = messages.last(where: { $0.who == .anorcha }) else { return nil }
        return Bilingual(en: message.translation ?? message.text, tx: message.text)
    }

    var wordsInDraft: Int {
        draft.split(separator: "\n").reduce(0) {
            $0 + WordSplitter.words(in: String($1), language: target).count
        }
    }
    /// Long enough to be an answer, and in the alphabet of the language being learned.
    var canSend: Bool {
        phase == .yourTurn && wordsInDraft >= chapter.minimumWords
    }

    var xpEarned: Int {
        let words = records.reduce(0) { $0 + WordSplitter.words(in: $1.answer, language: target).count }
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
        let opener = Phrases.list("chat.opener.\(chapter.theme.id)").first
            ?? Bilingual(en: chapter.theme.title.en, tx: chapter.theme.title.en)
        if messages.isEmpty { return opener }
        if closing { return Phrases.any("chat.goodbyes") ?? opener }
        let asked = records.count
        var follow = Phrases.list("chat.thread.\(chapter.theme.id)")
        if follow.isEmpty { follow = Phrases.list("chat.followUps") }
        guard !follow.isEmpty else { return opener }
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
        review = CallReviewer.review(turns: records, target: target,
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
        let said = Set(records.flatMap {
            WordSplitter.words(in: Grader.normalise($0.answer), language: target)
        })
        guard !said.isEmpty else { return [] }
        return chapter.vocabulary.filter { pair in
            let words = WordSplitter.words(in: Grader.normalise(pair[target]),
                                           language: target)
            return !words.isEmpty && words.allSatisfy { said.contains($0) }
        }
    }

}
