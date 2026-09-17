import Foundation

/// Everything the assistant is told before it writes a single word.
///
/// A call that knows which chapter the learner is on, how long her streak is, which
/// words she keeps missing and what Anorcha already asked her last week cannot come
/// out the same twice — which is the whole point of generating it.
struct CallContext {
    var level: CEFR
    var unitTitle: String = ""
    var lessonTopics: [String] = []
    /// Words from the current chapter, reshuffled per call so the angle shifts too.
    var vocabulary: [String] = []
    var earlierUnits: [String] = []
    /// Words she has actually got wrong lately: worth steering the conversation onto.
    var weakWords: [String] = []
    var streak: Int = 0
    var dayPart: String = "day"
    /// Questions from earlier calls, verbatim, so the model can go somewhere else.
    var avoid: [String] = []
    /// A slant drawn at random. The single strongest source of variety between calls:
    /// same chapter, same vocabulary, genuinely different conversation.
    var angle: String = CallContext.angles.randomElement() ?? ""

    static let angles = [
        "open on a small concrete detail of her day",
        "build the call around a memory she could tell",
        "make her compare two things she knows",
        "ask for her opinion and then for the reason behind it",
        "have her describe a place in her own words",
        "get her planning something that has not happened yet",
        "centre it on a person in her life",
        "ask about a habit and how it started",
        "let her tell one very small story",
        "put her in a situation and ask what she would do",
        "ask her to explain something to you as if you had never heard of it",
        "start from something she likes and dig into why",
    ]

    /// The briefing block both prompts share.
    var briefing: String {
        var lines = [
            "CEFR level: \(level.label)",
            "Current chapter: \(unitTitle.isEmpty ? "the beginning of the course" : unitTitle)",
        ]
        if !lessonTopics.isEmpty {
            lines.append("Lessons in it: \(lessonTopics.prefix(12).joined(separator: ", "))")
        }
        if !vocabulary.isEmpty {
            lines.append("Vocabulary she has just studied: \(vocabulary.prefix(60).joined(separator: ", "))")
        }
        if !earlierUnits.isEmpty {
            lines.append("Chapters already behind her: \(earlierUnits.suffix(6).joined(separator: ", "))")
        }
        if !weakWords.isEmpty {
            lines.append("Words she keeps getting wrong, worth drawing out: \(weakWords.prefix(12).joined(separator: ", "))")
        }
        lines.append("Time of day where she is: \(dayPart)")
        if streak > 1 { lines.append("She has practised \(streak) days in a row.") }
        lines.append("Angle for THIS call: \(angle).")
        if !avoid.isEmpty {
            lines.append("Already asked in earlier calls — do not repeat these, or close variants:\n"
                         + avoid.suffix(30).map { "- \($0)" }.joined(separator: "\n"))
        }
        return lines.joined(separator: "\n")
    }
}

/// Builds a fresh call every time: the learner picks a level, and the questions are
/// drawn from the unit they have actually reached in that level, shuffled with a few
/// from earlier units so two calls are never the same.
enum CallPlanner {

    static func plan(level: CEFR,
                     state: AppState,
                     questionCount: Int = 8) -> CallPlan {
        let bank = state.questions
        let units = state.curriculum.levels.first { $0.level == level }?.units ?? []
        guard !units.isEmpty else {
            return CallPlan(level: level, focusUnit: nil, questions: [])
        }

        // Where is the learner inside this level? The furthest unit they have opened.
        let reachedIndex = units.lastIndex { state.hasReached(unitID: $0.id) } ?? 0
        let focus = units[reachedIndex]
        // Earlier units of the same level, for variety and revision.
        let earlier = Array(units[0..<reachedIndex])

        var questions: [CallQuestion] = []

        // 1. An opener for the level.
        if let opener = bank.generic(level, "open").randomElement() {
            questions.append(CallQuestion(text: opener, origin: .opening))
        }

        // 2. The body: mostly the current unit, some revision of earlier ones.
        let fromFocus = pick(bank.questions(forUnit: focus.id),
                             count: max(3, questionCount - 4))
        questions += fromFocus.map {
            CallQuestion(text: $0, origin: .unit(focus.id),
                         suggestedVocabulary: Array(focus.allPairs.shuffled().prefix(12)))
        }

        var revision: [CallQuestion] = []
        for unit in earlier.shuffled().prefix(2) {
            if let q = bank.questions(forUnit: unit.id).randomElement() {
                revision.append(CallQuestion(text: q, origin: .unit(unit.id),
                                             suggestedVocabulary: Array(unit.allPairs.shuffled().prefix(8))))
            }
        }
        questions += revision

        // 3. Keep the opener first, shuffle the rest, then cap.
        let opener = questions.first
        var body = Array(questions.dropFirst()).shuffled()
        body = Array(body.prefix(max(1, questionCount - 2)))

        // 4. Sprinkle a follow-up in the middle: it makes the call feel like a dialogue.
        if let follow = bank.generic(level, "follow").randomElement(), body.count >= 3 {
            body.insert(CallQuestion(text: follow, origin: .followUp),
                        at: Int.random(in: 2...max(2, body.count - 1)))
        }

        var all: [CallQuestion] = []
        if let opener { all.append(opener) }
        all += body
        if let closing = bank.generic(level, "close").randomElement() {
            all.append(CallQuestion(text: closing, origin: .closing))
        }

        return CallPlan(level: level, focusUnit: focus, questions: all)
    }

    private static func pick(_ items: [Bilingual], count: Int) -> [Bilingual] {
        Array(items.shuffled().prefix(count))
    }

    /// Gathers what the assistant needs to know about this learner, right now.
    static func context(for plan: CallPlan, level: CEFR, state: AppState,
                        target: Language) -> CallContext {
        var ctx = CallContext(level: level)
        if let unit = plan.focusUnit {
            ctx.unitTitle = unit.title[target]
            ctx.lessonTopics = unit.lessons.map { $0.title[target] }
            ctx.vocabulary = unit.allPairs.shuffled().prefix(60).map { $0[target] }
            let units = state.curriculum.levels.first { $0.level == level }?.units ?? []
            ctx.earlierUnits = units.prefix { $0.id != unit.id }.map { $0.title[target] }
        }
        ctx.weakWords = (state.duePairs(limit: 12) + state.mistakesBank.suffix(12))
            .map { $0[target] }
        ctx.streak = state.streak
        ctx.dayPart = dayPart()
        ctx.avoid = state.recentCallQuestions
        return ctx
    }

    private static func dayPart(now: Date = .now, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: now) {
        case 5..<12: return "morning"
        case 12..<18: return "afternoon"
        case 18..<23: return "evening"
        default: return "late night"
        }
    }

    /// The vocabulary the review checks the learner's answers against.
    static func vocabulary(for plan: CallPlan, state: AppState) -> [Pair] {
        var out: [Pair] = []
        if let focus = plan.focusUnit { out += focus.allPairs }
        for q in plan.questions { out += q.suggestedVocabulary }
        return out
    }
}
