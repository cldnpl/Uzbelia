import Foundation
import Observation

/// One line of the call as it was actually said, in the order it was said: what the
/// assistant reads to know where the conversation is.
struct CallLine: Hashable {
    enum Speaker: Hashable { case anorcha, learner }
    var speaker: Speaker
    var text: String
}

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
    let native: Language = .en
    let target: Language

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
    /// Off without a key; it switches itself off only after two turns in a row have
    /// failed even on a second try, so one slow answer from the network does not
    /// send the rest of the call back to the script.
    var live = false
    private var failuresInARow = 0
    /// Everything said so far, both sides, in order.
    private(set) var transcript: [CallLine] = []

    var showSubtitles = true
    var showTranslation = false
    var typed = ""
    private var turnStartedAt: Date?

    init(level: CEFR, target: Language, plan: CallPlan) {
        self.level = level
        self.target = target
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
        noteQuestion()
    }

    /// Writes the question about to be asked into the transcript.
    private func noteQuestion() {
        guard let question else { return }
        transcript.append(CallLine(speaker: .anorcha, text: question.spoken(in: target)))
    }

    func anorchaFinishedSpeaking() {
        guard phase == .anorchaSpeaking else { return }
        turnStartedAt = .now
        phase = .yourTurn
    }

    /// Records a free answer — nothing is graded here, the review happens at the end.
    func submit(_ text: String, typed isTyped: Bool, skipped: Bool = false) {
        guard let question else { return }
        let seconds = Int(Date().timeIntervalSince(turnStartedAt ?? .now))
        let answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
        records.append(CallTurnRecord(question: question.text,
                                      answer: answer,
                                      seconds: max(0, seconds),
                                      typed: isTyped))
        transcript.append(CallLine(speaker: .learner,
                                   text: answer.isEmpty ? (skipped ? Self.skippedMark : Self.silentMark)
                                                        : answer))
        self.typed = ""
        // in a live call the reaction is written from what she just said, so it arrives
        // a moment later; offline, one of the canned ones does the job at once
        reaction = (live || answer.isEmpty) ? nil : Self.cannedReaction()
        phase = .reacting
    }

    func skip() {
        submit("", typed: false, skipped: true)
    }

    func advance() {
        if let reaction { transcript.append(CallLine(speaker: .anorcha, text: reaction[target])) }
        reaction = nil
        index += 1
        phase = index < plan.questions.count ? .anorchaSpeaking : .reviewing
        if phase == .anorchaSpeaking { noteQuestion() }
    }

    /// How an empty answer appears in the transcript the assistant reads.
    static let skippedMark = "(she skipped this question)"
    static let silentMark = "(nothing came through — the microphone may have missed it)"

    /// Writes Anorcha's next turn from the conversation so far: a reaction to what was
    /// actually said, and the question that grows out of it. When the next line is the
    /// goodbye, the goodbye is written too, so it can mention something she said.
    ///
    /// Everything here is best-effort. No key, no network, a mangled reply: the call
    /// carries on with the planned question — which is itself part of a thread on the
    /// same chapter, never a random one.
    func composeNextTurn(provider: AIProvider, apiKey: String) async {
        guard phase == .reacting, reaction == nil, !thinking else { return }
        guard live, let context, !records.isEmpty,
              AIClient.isConfigured(provider: provider, key: apiKey) else { return }
        // out of requests for today: carry on with the planned threads, at once
        guard AIBudget.canSpend(.conversation) else { live = false; return }
        let slot = index + 1
        // she has answered the goodbye: there is nothing left to say
        guard slot < plan.questions.count else { return }
        let goodbye = slot == plan.questions.count - 1

        thinking = true
        defer { thinking = false }
        for attempt in 0..<2 {
            do {
                let turn = try await AIClient.nextTurn(provider: provider, key: apiKey,
                                                       context: context, transcript: transcript,
                                                       target: target, native: native,
                                                       closing: goodbye)
                guard phase == .reacting, index + 1 == slot else { return }   // she hung up meanwhile
                reaction = turn.reaction
                if let line = turn.question {
                    plan.questions[slot] = CallQuestion(text: line, origin: goodbye ? .closing : .generated)
                }
                failuresInARow = 0
                return
            } catch AIClient.Failure.overBudget {
                live = false
                break
            } catch {
                if attempt == 0 { try? await Task.sleep(for: .milliseconds(700)) }
            }
        }
        failuresInARow += 1
        if failuresInARow >= 2 { live = false }
        if !(records.last?.answer.isEmpty ?? true) { reaction = Self.cannedReaction() }
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
        let local = CallReviewer.review(turns: records, target: target,
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
        transcript = []
        failuresInARow = 0
        review = nil
        reaction = nil
        typed = ""
        startedAt = .now
        phase = .anorchaSpeaking
        noteQuestion()
    }

    // MARK: - Small talk between questions

    /// "I see", "Really?": from the course's own phrases.
    static func cannedReaction() -> Bilingual? {
        Phrases.any("call.reactions")
    }
}
