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
        reaction = text.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Self.reactions.randomElement()
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

    func hangUp() {
        phase = records.isEmpty ? .ended : .reviewing
    }

    // MARK: - The report

    func buildReview(curriculum: Curriculum, apiKey: String) async {
        let local = CallReviewer.review(turns: records, native: native,
                                        curriculum: curriculum, level: level)
        if ClaudeClient.isConfigured(apiKey), !records.isEmpty {
            do {
                let remote = try await ClaudeClient.review(key: apiKey, turns: records,
                                                           target: target, native: native,
                                                           level: level)
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
