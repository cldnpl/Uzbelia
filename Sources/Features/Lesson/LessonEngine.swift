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
    /// The colour of a practice run that drills a single skill.
    var accent: UnitAccent?
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

    // the short text, which is corrected over several rounds before it is marked
    /// What the checker said last time, about the text as it was then.
    var composeReport: CompositionReport?
    /// How many times she has asked for a check on this text.
    var composeRound = 0
    /// True once she has asked to see the corrected text.
    var composeRevealed = false
    /// How many rounds of clues before the fix is shown anyway.
    static let composeRounds = 3

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
        case .choice, .listenChoice, .listenMeaning, .fillBlank: return chosen != nil
        case .type, .listenType: return !typed.trimmingCharacters(in: .whitespaces).isEmpty
        case .wordBank, .listenBuild: return !built.isEmpty
        case .speak, .speakRepeat: return speechScore != nil
        case .match: return false
        case .compose:
            // long enough to be a text, and changed since the last check
            return composeWords >= (ex.composition?.minimumWords ?? 3)
                && typed != composeReport?.text
        }
    }

    /// Words in the text being written.
    var composeWords: Int {
        typed.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
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
        case .choice, .listenChoice, .listenMeaning, .fillBlank: return chosen ?? ""
        case .type, .listenType, .compose: return typed.trimmingCharacters(in: .whitespacesAndNewlines)
        case .wordBank, .listenBuild: return builtSentence
        case .speak, .speakRepeat: return spoken
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
        case .choice, .listenChoice, .listenMeaning, .fillBlank:
            return (chosen.map { Grader.normalise($0) == Grader.normalise(ex.answer) } ?? false)
                ? .correct : .wrong(ex.answer)
        case .wordBank:
            return translation(builtSentence, for: ex, tolerant: false)
        case .listenBuild:
            // what she heard has one right wording: the one that was said
            return Grader.grade(builtSentence, expected: ex.answer, tolerant: false)
        case .type:
            return translation(typed, for: ex, tolerant: true)
        case .listenType:
            return Grader.grade(typed, expected: ex.answer)
        case .speak, .speakRepeat:
            let score = speechScore ?? 0
            return score >= 0.65 ? .correct : (score >= 0.4 ? .almost(ex.answer) : .wrong(ex.answer))
        case .match:
            return .correct
        case .compose:
            return composeVerdict
        }
    }

    /// A translation she wrote herself. Her own wording is right whenever it says the
    /// same thing — `itim` for `mening itim`, `assalomu alaykum` for `salom` — and is
    /// marked right straight away, not wrong-with-an-appeal.
    private func translation(_ given: String, for ex: Exercise, tolerant: Bool) -> Verdict {
        let plain = Grader.grade(given, expected: ex.answer, tolerant: tolerant)
        if case .correct = plain { return plain }
        switch Equivalence.compare(given, with: ex.answer, in: ex.answerLanguage, prompt: ex.prompt) {
        case .same(let canonical)?:
            return .alternative(canonical: canonical, note: nil)
        case .nearly(let canonical)? where tolerant:
            if case .almost = plain { return plain }
            return .almost(canonical)
        default:
            return plain
        }
    }

    /// The verdict on the text once the rounds are over: clean at the first check is
    /// right, clean after some clues is right with help, and a text she needed to see
    /// corrected is a miss — counted, but never charged a heart or sent round again.
    private var composeVerdict: Verdict {
        let corrected = composeReport?.corrected ?? ""
        if composeRevealed { return .wrong(corrected) }
        guard composeReport?.isClean == true else { return .wrong(corrected) }
        return composeRound <= 1 ? .correct : .almost(typed.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Files one round of checking. Returns true when the text is finished — clean,
    /// or out of rounds — and the verdict can be committed.
    @discardableResult
    func recordComposeRound(_ report: CompositionReport) -> Bool {
        composeRound += 1
        composeReport = report
        return report.isClean
    }

    /// She asks to see the corrected text: the exercise ends there.
    func revealComposition() {
        composeRevealed = true
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
        // a text she asked to see corrected is not asked again, so it is done too
        if ok || ex.kind == .compose { completed.insert(ex.id) }
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

    /// "Not right now." Drops the question on screen and rewrites every later one that
    /// needs the same skill, so the rest of the lesson can be done in silence.
    func setAside(_ skill: Skill, native: Language) {
        for index in exercises.indices where index > self.index && exercises[index].trainsSkill == skill {
            exercises[index] = exercises[index].withoutAudio(native: native)
        }
        if skill == .speaking { skippedSpeaking = true }
        if let ex = current, ex.trainsSkill == skill {
            completed.insert(ex.id)
            advance(requeue: false)
        }
    }

    // MARK: - Moving on

    func advance(requeue: Bool = true) {
        if requeue, let ex = current, case .wrong = verdict, ex.kind != .compose {
            var again = ex
            again.isRetry = true
            if ex.kind == .speak || ex.kind == .speakRepeat {
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
        composeReport = nil
        composeRound = 0
        composeRevealed = false
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
