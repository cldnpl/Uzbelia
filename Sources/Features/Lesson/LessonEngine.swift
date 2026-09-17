import Foundation
import Observation

struct SessionRequest: Identifiable {
    enum Mode { case lesson, practice, test }
    let id = UUID()
    var node: PathNode?
    var unit: Unit?
    var level: CEFR?
    var mode: Mode = .lesson
    var customExercises: [Exercise] = []
    var customTitle: Bilingual?
    var consumesHearts: Bool = true
    var xpReward: Int = 15
    /// Which of the five passes over a lesson node this is.
    var focus: SessionFocus = .discover
    var sessionNumber: Int = 1
    var sessionsTotal: Int = 1
    var testTarget: TestTarget?
}

@Observable
final class LessonEngine {
    var exercises: [Exercise] = []
    var index = 0
    var verdict: Verdict?
    var finished = false

    // answer drafts
    var typed = ""
    var chosen: String?
    var built: [Int] = []           // indices into the current exercise's tokens
    var matched: Set<String> = []
    var matchLeft: String?
    var matchRight: String?
    var matchWrong: Bool = false
    var speechScore: Double?
    var spoken = ""                 // what the recogniser heard on a .speak question
    var skippedSpeaking = false
    /// True while a rejected free answer is being reconsidered. Nothing is recorded
    /// and no heart is lost until that comes back.
    var checking = false

    // stats
    private(set) var completed: Set<UUID> = []
    private(set) var attempts = 0
    private(set) var hits = 0
    private(set) var mistakes: [Pair] = []
    private(set) var perSkill: [Skill: (hit: Int, total: Int)] = [:]
    let startedAt = Date()
    private let totalUnique: Int

    init(exercises: [Exercise]) {
        self.exercises = exercises
        self.totalUnique = max(1, exercises.count)
    }

    var current: Exercise? { index < exercises.count ? exercises[index] : nil }
    var progress: Double { Double(completed.count) / Double(totalUnique) }
    var accuracy: Double { attempts == 0 ? 1 : Double(hits) / Double(attempts) }
    var minutes: Int { max(1, Int(Date().timeIntervalSince(startedAt) / 60)) }
    var mistakePairs: [Pair] { mistakes }

    var canCheck: Bool {
        guard let ex = current, verdict == nil, !checking else { return false }
        switch ex.kind {
        case .choice, .listenChoice, .fillBlank: return chosen != nil
        case .type, .listenType: return !typed.trimmingCharacters(in: .whitespaces).isEmpty
        case .wordBank: return !built.isEmpty
        case .speak: return speechScore != nil
        case .match: return false
        }
    }

    var builtSentence: String {
        guard let ex = current else { return "" }
        return built.compactMap { ex.tokens.indices.contains($0) ? ex.tokens[$0] : nil }.joined(separator: " ")
    }

    /// What the learner actually gave for the current question, whatever the format.
    /// The feedback banner translates it back, so a wrong pick still teaches something.
    var givenAnswer: String {
        guard let ex = current else { return "" }
        switch ex.kind {
        case .choice, .listenChoice, .fillBlank: return chosen ?? ""
        case .type, .listenType: return typed.trimmingCharacters(in: .whitespacesAndNewlines)
        case .wordBank: return builtSentence
        case .speak: return spoken
        case .match: return ""
        }
    }

    // MARK: - Checking

    /// Marks the answer without recording anything. Split from `commit` so a free
    /// answer can be reconsidered — a colloquial wording the course never listed is
    /// still right — before it counts against her.
    func grade() -> Verdict {
        guard let ex = current else { return .correct }
        switch ex.kind {
        case .choice, .listenChoice, .fillBlank:
            return (chosen.map { Grader.normalise($0) == Grader.normalise(ex.answer) } ?? false)
                ? .correct : .wrong(ex.answer)
        case .wordBank:
            return Grader.grade(builtSentence, expected: ex.answer, tolerant: false)
        case .type, .listenType:
            return Grader.grade(typed, expected: ex.answer)
        case .speak:
            let score = speechScore ?? 0
            return score >= 0.65 ? .correct : (score >= 0.4 ? .almost(ex.answer) : .wrong(ex.answer))
        case .match:
            return .correct
        }
    }

    /// Records the verdict and shows it.
    func commit(_ v: Verdict) {
        guard let ex = current else { return }
        register(v, for: ex)
        verdict = v
    }

    @discardableResult
    func check() -> Verdict {
        let v = grade()
        commit(v)
        return v
    }

    private func register(_ v: Verdict, for ex: Exercise) {
        attempts += 1
        let ok = v.isAccepted
        if ok { hits += 1 } else { mistakes.append(ex.pair) }
        var bucket = perSkill[ex.trainsSkill] ?? (0, 0)
        bucket.total += 1
        if ok { bucket.hit += 1 }
        perSkill[ex.trainsSkill] = bucket
        if ok { completed.insert(ex.id) }
    }

    /// Takes back the miss just recorded, because the answer was right after all.
    ///
    /// The course lists one wording; she is allowed to know another. Nothing here is
    /// guesswork — she has looked at the two versions side by side and said hers is
    /// good too, and the app believes her.
    func acceptAnswerAnyway(note: String? = nil) {
        guard let ex = current, case .wrong = verdict else { return }
        if let last = mistakes.lastIndex(of: ex.pair) { mistakes.remove(at: last) }
        hits += 1
        var bucket = perSkill[ex.trainsSkill] ?? (0, 0)
        bucket.hit += 1
        perSkill[ex.trainsSkill] = bucket
        completed.insert(ex.id)
        verdict = .alternative(canonical: ex.answer, note: note)
    }

    /// Records a matching-game result without the check/continue cycle.
    func registerMatch(pair: Pair, correct: Bool) {
        attempts += 1
        if correct { hits += 1 } else { mistakes.append(pair) }
        var bucket = perSkill[.reading] ?? (0, 0)
        bucket.total += 1
        if correct { bucket.hit += 1 }
        perSkill[.reading] = bucket
    }

    func completeMatch() {
        if let ex = current { completed.insert(ex.id) }
        advance(requeue: false)
    }

    func skipSpeaking() {
        guard let ex = current else { return }
        completed.insert(ex.id)
        skippedSpeaking = true
        advance(requeue: false)
    }

    // MARK: - Moving on

    func advance(requeue: Bool = true) {
        if requeue, let ex = current, case .wrong = verdict {
            var again = ex
            if ex.kind == .speak {
                // a missed pronunciation comes back as a written translation, asked
                // from the other language so the answer is not sitting on screen
                again.kind = .type
                again.promptLanguage = ex.answerLanguage.other
                again.prompt = ex.pair[ex.answerLanguage.other]
                again.audioText = nil
                again.audioLanguage = nil
            }
            exercises.append(again)
        }
        resetDrafts()
        index += 1
        if index >= exercises.count { finished = true }
    }

    func resetDrafts() {
        verdict = nil
        typed = ""
        chosen = nil
        built = []
        matched = []
        matchLeft = nil
        matchRight = nil
        matchWrong = false
        speechScore = nil
        spoken = ""
        checking = false
    }

    // MARK: - Rewards

    func xpEarned(base: Int) -> Int {
        var xp = base
        if accuracy >= 0.95 { xp += 8 }
        else if accuracy >= 0.8 { xp += 4 }
        if let speaking = perSkill[.speaking], speaking.total > 0 { xp += 3 }
        return xp
    }
}
