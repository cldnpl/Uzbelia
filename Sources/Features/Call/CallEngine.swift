import Foundation
import Observation

/// Drives one free-conversation call: Anorcha asks, the learner answers in their own
/// words, and at the end everything said gets reviewed.
@Observable
final class CallEngine {

    enum Phase: Equatable {
        case dialling
        case anorchaSpeaking
        case yourTurn
        case reacting        // short acknowledgement between questions
        case reviewing       // building the report
        case ended
    }

    let level: CEFR
    let native: Language
    var target: Language { native.other }

    private(set) var plan: CallPlan
    private(set) var index = 0
    private(set) var phase: Phase = .dialling
    private(set) var records: [CallTurnRecord] = []
    private(set) var startedAt: Date?
    private(set) var review: CallReview?
    private(set) var reaction: Bilingual?
    /// True while Anorcha is writing her next turn.
    private(set) var thinking = false

    /// What the assistant knows about this learner. Set once the plan is built.
    var context: CallContext?
    /// Whether Anorcha writes each turn as the call goes instead of reading a script.
    /// Off without a key, and it switches itself off after a failed request.
    var live = false

    var showSubtitles = true
    var showTranslation = false
    var typed = ""
    private var turnStartedAt: Date?

    init(level: CEFR, native: Language, plan: CallPlan) {
        self.level = level
        self.native = native
        self.plan = plan
    }

    var question: CallQuestion? { index < plan.questions.count ? plan.questions[index] : nil }
    var progress: Double { Double(index) / Double(max(1, plan.questions.count)) }
    var questionNumber: Int { min(index + 1, plan.questions.count) }
    var questionTotal: Int { plan.questions.count }
    var elapsed: String {
        guard let startedAt else { return "00:00" }
        let s = Int(Date().timeIntervalSince(startedAt))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
    var xpEarned: Int { 10 + records.filter { !$0.answer.isEmpty }.count * 5 }

    // MARK: - Flow

    func answerCall() {
        startedAt = .now
        phase = .anorchaSpeaking
    }

    func anorchaFinishedSpeaking() {
        guard phase == .anorchaSpeaking else { return }
        turnStartedAt = .now
        phase = .yourTurn
    }

    /// Records a free answer — nothing is graded here, the review happens at the end.
    func submit(_ text: String, typed isTyped: Bool) {
        guard let question else { return }
        let seconds = Int(Date().timeIntervalSince(turnStartedAt ?? .now))
        records.append(CallTurnRecord(question: question.text,
                                      answer: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                      seconds: max(0, seconds),
                                      typed: isTyped))
        self.typed = ""
        // in a live call the reaction is written from what she just said, so it arrives
        // a moment later; offline, one of the canned ones does the job at once
        let saidSomething = !text.trimmingCharacters(in: .whitespaces).isEmpty
        reaction = (live || !saidSomething) ? nil : Self.reactions.randomElement()
        phase = .reacting
    }

    func skip() {
        submit("", typed: false)
    }

    func advance() {
        reaction = nil
        index += 1
        phase = index < plan.questions.count ? .anorchaSpeaking : .reviewing
    }

    /// Writes Anorcha's next turn from the conversation so far: a reaction to what was
    /// actually said, and the question that follows from it.
    ///
    /// Everything here is best-effort. No key, no network, a mangled reply — the call
    /// simply carries on with the planned question and a canned "capisco".
    func composeNextTurn(provider: AIProvider, apiKey: String) async {
        guard phase == .reacting, reaction == nil, !thinking else { return }
        guard live, let context, let last = records.last,
              !last.answer.trimmingCharacters(in: .whitespaces).isEmpty,
              AIClient.isConfigured(provider: provider, key: apiKey) else { return }

        thinking = true
        defer { thinking = false }
        let slot = index + 1
        do {
            let turn = try await AIClient.nextTurn(provider: provider, key: apiKey,
                                                   context: context, history: records,
                                                   target: target, native: native,
                                                   closing: slot >= plan.questions.count)
            reaction = turn.reaction
            // the last planned line says goodbye: never overwrite it with a new question
            if let question = turn.question, slot < plan.questions.count - 1 {
                plan.questions[slot] = CallQuestion(text: question, origin: .generated)
            }
        } catch {
            live = false                       // one failure is enough: stop paying for more
            reaction = Self.reactions.randomElement()
        }
    }

    /// Every question actually put to the learner, in the language she is learning.
    /// Fed back into the next call so Anorcha does not ask the same things again.
    func askedQuestions() -> [String] {
        records.map { $0.question[target] }
    }

    func hangUp() {
        phase = records.isEmpty ? .ended : .reviewing
    }

    // MARK: - The report

    func buildReview(curriculum: Curriculum, provider: AIProvider, apiKey: String) async {
        let local = CallReviewer.review(turns: records, native: native,
                                        curriculum: curriculum, level: level)
        if AIClient.isConfigured(provider: provider, key: apiKey), !records.isEmpty {
            do {
                let remote = try await AIClient.review(provider: provider, key: apiKey,
                                                       turns: records, target: target,
                                                       native: native, level: level)
                await MainActor.run { self.review = remote; self.phase = .ended }
                return
            } catch {
                // fall through to the offline report
            }
        }
        await MainActor.run { self.review = local; self.phase = .ended }
    }

    func restart(with newPlan: CallPlan) {
        plan = newPlan
        index = 0
        records = []
        review = nil
        reaction = nil
        typed = ""
        startedAt = .now
        phase = .anorchaSpeaking
    }

    // MARK: - Small talk between questions

    static let reactions: [Bilingual] = [
        Bilingual(it: "Capisco.", uz: "Tushunarli."),
        Bilingual(it: "Interessante!", uz: "Qiziq!"),
        Bilingual(it: "Ah, davvero?", uz: "Rostdanmi?"),
        Bilingual(it: "Bene, bene.", uz: "Yaxshi, yaxshi."),
        Bilingual(it: "Ho capito, grazie.", uz: "Tushundim, rahmat."),
        Bilingual(it: "Che bello.", uz: "Zo'r ekan."),
    ]
}
