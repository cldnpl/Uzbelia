import Foundation

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

    /// The vocabulary the review checks the learner's answers against.
    static func vocabulary(for plan: CallPlan, state: AppState) -> [Pair] {
        var out: [Pair] = []
        if let focus = plan.focusUnit { out += focus.allPairs }
        for q in plan.questions { out += q.suggestedVocabulary }
        return out
    }
}
