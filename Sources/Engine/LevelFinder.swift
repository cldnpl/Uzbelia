import Foundation

/// «Scopri il tuo livello»: a short quiz that reads the course from A1 upwards and
/// says where the learner should actually start.
///
/// The questions are drawn unit by unit in course order, so the answers form a curve
/// rather than a score: right at the beginning, wrong further on, and the turn is
/// where she belongs. Someone who has never seen the language stops at the first
/// rung and starts at A1, which is exactly right.
enum LevelFinder {

    /// One rung of the ladder: a unit, and the questions asked about it.
    struct Rung {
        let unitID: String
        let level: CEFR
        let pairs: [Pair]
    }

    /// Identifiable so a screen can present it directly, rather than flipping a
    /// separate flag and hoping both land in the same update.
    struct Quiz: Identifiable {
        let id = UUID()
        var exercises: [Exercise]
        var rungs: [Rung]
        /// Where a learner lands when the quiz says she knows nothing yet.
        var floor: (level: CEFR, unitID: String)?
    }

    /// Two questions per unit, sampled across the whole course.
    ///
    /// A course of thirty-odd units would make a sixty-question quiz, so units are
    /// taken at a stride: enough rungs to find the turn, short enough to sit through.
    static func quiz(curriculum: Curriculum,
                     native: Language,
                     settings: Settings,
                     rungs wanted: Int = 12,
                     perRung: Int = 2) -> Quiz {
        var ordered: [(unit: Unit, level: CEFR)] = []
        for pack in curriculum.levels {
            for unit in pack.units where !unit.allPairs.isEmpty {
                ordered.append((unit, pack.level))
            }
        }
        guard !ordered.isEmpty else { return Quiz(exercises: [], rungs: [], floor: nil) }

        let stride = max(1, Int((Double(ordered.count) / Double(wanted)).rounded()))
        var picked: [(unit: Unit, level: CEFR)] = []
        var index = 0
        while index < ordered.count, picked.count < wanted {
            picked.append(ordered[index])
            index += stride
        }
        if let last = ordered.last, picked.last?.unit.id != last.unit.id { picked.append(last) }

        // No microphone in a placement quiz, and no dictation either: this is about
        // what she knows, not about what she can do in the room she is sitting in.
        var quizSettings = settings
        quizSettings.speakingExercises = false
        quizSettings.listeningExercises = false

        var exercises: [Exercise] = []
        var rungs: [Rung] = []
        for (unit, level) in picked {
            let pairs = Array(unit.allPairs.shuffled().prefix(perRung))
            let built = ExerciseFactory.build(pairs: pairs,
                                              pool: curriculum.pairsUpTo(unitID: unit.id),
                                              native: native,
                                              settings: quizSettings,
                                              maxCount: perRung,
                                              includeMatch: false,
                                              productionBias: 0.35)
            guard !built.isEmpty else { continue }
            exercises += built
            rungs.append(Rung(unitID: unit.id, level: level, pairs: built.map(\.pair)))
        }

        let floor = ordered.first.map { (level: $0.level, unitID: $0.unit.id) }
        return Quiz(exercises: exercises, rungs: rungs, floor: floor)
    }

    /// Reads the answers back as a place in the course.
    ///
    /// The learner is put at the first unit she did *not* know, so the quiz can only
    /// ever skip material she demonstrably has. Getting one rung wrong by accident
    /// costs nothing: it places her a little earlier than she deserves, and the path
    /// lets her test out of it later.
    static func placement(quiz: Quiz, mistakes: [Pair]) -> (level: CEFR, unitID: String)? {
        guard !quiz.rungs.isEmpty else { return nil }
        let missed = Set(mistakes.map(\.id))

        var lastKnown: Rung?
        for rung in quiz.rungs {
            let wrong = rung.pairs.filter { missed.contains($0.id) }.count
            // half of the rung wrong is not knowing it
            if Double(wrong) * 2 >= Double(rung.pairs.count) { break }
            lastKnown = rung
        }

        guard let lastKnown else { return quiz.floor }
        // she knew this rung, so she starts at the one after it
        guard let next = quiz.rungs.first(where: { rung in
            guard let i = quiz.rungs.firstIndex(where: { $0.unitID == lastKnown.unitID }),
                  let j = quiz.rungs.firstIndex(where: { $0.unitID == rung.unitID }) else { return false }
            return j == i + 1
        }) else {
            return (lastKnown.level, lastKnown.unitID)      // she knew the lot
        }
        return (next.level, next.unitID)
    }

    /// Opens the course up to the placement: every level below it, and every node
    /// before the unit marked as done so the path starts there.
    static func apply(_ placement: (level: CEFR, unitID: String), state: AppState) {
        state.unlock(level: placement.level)
        guard let unit = state.curriculum.unit(id: placement.unitID),
              let firstNode = unit.nodes(level: placement.level, index: 0).first else { return }

        var toClear: [String] = []
        for level in CEFR.allCases where level <= placement.level {
            for id in state.nodeIDs(for: level) {
                if level == placement.level, id == firstNode.id { break }
                toClear.append(id)
            }
        }
        guard !toClear.isEmpty else { return }
        let target = TestTarget(kind: .skipTo(nodeID: firstNode.id),
                                level: placement.level,
                                nodesToClear: toClear,
                                title: unit.title,
                                questionCount: 0)
        state.markPassedTest(target, accuracy: 0.85)
    }
}
