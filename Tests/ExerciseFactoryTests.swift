import XCTest
@testable import Uzbelia

/// Generates a session for every single lesson of the course and checks that no
/// question can ever be unanswerable.
final class ExerciseFactoryTests: XCTestCase {

    private var curriculum: Curriculum!

    override func setUp() {
        super.setUp()
        curriculum = ContentStore.loadCurriculum(.uz)
        // the factory reads the course's language from here; AppState sets it on load
        Language.current = .uz
    }

    func testEveryLessonProducesAValidSession() {
        var checked = 0
        for pack in curriculum.levels {
            for unit in pack.units {
                // every unit, every node kind; a stride keeps the 400-node course quick
                let nodes = unit.nodes(level: pack.level, index: 0)
                let sampled = nodes.enumerated().filter { $0.offset % 3 == 0 || $0.offset >= nodes.count - 2 }
                // the writing chapter is a conversation and builds no exercises
                for node in sampled.map(\.element) where !node.isWriting {
                    let session = ExerciseFactory.session(for: node, unit: unit,
                                                          curriculum: curriculum,
                                                          native: .en,
                                                          settings: Settings())
                    XCTAssertFalse(session.isEmpty, "\(node.id) produced no exercises")
                    for ex in session { assertValid(ex, native: .en, node: node.id) }
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThan(checked, 150)
    }

    /// The later passes are made mostly of practice sentences; every one of those
    /// questions has to be answerable too.
    func testEveryLaterPassProducesAValidSession() {
        var checked = 0
        for pack in curriculum.levels {
            for unit in pack.units {
                for node in unit.nodes(level: pack.level, index: 0) where !node.isWriting {
                    let session = ExerciseFactory.session(for: node, unit: unit,
                                                          curriculum: curriculum,
                                                          native: .en,
                                                          settings: Settings(),
                                                          focus: .review)
                    XCTAssertFalse(session.isEmpty, "\(node.id) produced no exercises")
                    for ex in session { assertValid(ex, native: .en, node: node.id) }
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThan(checked, 350)
    }

    func testBuildingASessionIsFastEnoughForTheBiggestPool() {
        let pack = curriculum.levels.last!          // B2: the pool is the whole course
        let unit = pack.units.last!
        let node = unit.nodes(level: pack.level, index: 0)[0]
        let started = Date()
        for _ in 0..<5 {
            _ = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                        native: .en, settings: Settings(), focus: .review)
        }
        let each = Date().timeIntervalSince(started) / 5
        XCTAssertLessThan(each, 1.0, "a session takes \(Int(each * 1000))ms to build")
    }

    func testSessionsMixTheFourSkills() {
        // Over a whole unit's worth of sessions every skill must appear.
        let unit = curriculum.allUnits[3]
        var skills = Set<Skill>()
        for _ in 0..<12 {
            for node in unit.nodes(level: .a1, index: 0) {
                let s = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                native: .en, settings: Settings())
                skills.formUnion(s.map(\.trainsSkill))
            }
        }
        XCTAssertEqual(skills, Set(Skill.allCases))
    }

    func testDisablingSpeakingAndListeningIsRespected() {
        var settings = Settings()
        settings.speakingExercises = false
        settings.listeningExercises = false
        let unit = curriculum.allUnits[0]
        for _ in 0..<10 {
            for node in unit.nodes(level: .a1, index: 0) {
                let s = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                native: .en, settings: settings)
                XCTAssertFalse(s.contains { $0.kind == .speak || $0.kind == .listenType || $0.kind == .listenChoice },
                               "disabled exercise kind still generated")
            }
        }
    }

    func testSkillDrillOnlyGeneratesThatSkill() {
        let pairs = Array(curriculum.allPairs.prefix(40))
        for skill in Skill.allCases {
            let ex = ExerciseFactory.practice(pairs: pairs, pool: curriculum.allPairs,
                                              native: .en, settings: Settings(),
                                              count: 12, restrictTo: skill)
            XCTAssertFalse(ex.isEmpty)
            for e in ex {
                XCTAssertEqual(e.trainsSkill, skill, "\(e.kind) does not train \(skill)")
            }
        }
    }

    func testTheSameFormatIsNotRepeatedBackToBack() {
        let unit = curriculum.allUnits[10]
        var repeats = 0, total = 0
        for _ in 0..<20 {
            let node = unit.nodes(level: .a2, index: 0)[0]
            let s = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                            native: .en, settings: Settings())
            // a format is the kind of question and the direction it is asked in
            for i in 1..<s.count {
                total += 1
                if s[i].kind == s[i - 1].kind, s[i].promptLanguage == s[i - 1].promptLanguage { repeats += 1 }
            }
        }
        XCTAssertLessThan(Double(repeats) / Double(total), 0.12,
                          "too many identical formats in a row")
    }

    /// The label is a promise. A pass called "Listening" is listening and nothing else,
    /// "Writing" writing and nothing else, and so on — at every level. Only the review
    /// pass mixes.
    func testEachLabelledPassIsMadeOnlyOfItsOwnSkill() {
        for pack in curriculum.levels {
            for unit in pack.units.prefix(2) {
                for node in unit.nodes(level: pack.level, index: 0) {
                    guard case .lesson = node.kind else { continue }
                    for focus in SessionFocus.allCases {
                        guard let skill = focus.skill else { continue }
                        let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                              native: .en, settings: Settings(), focus: focus)
                        XCTAssertFalse(session.isEmpty, "\(node.id)/\(focus) is empty")
                        for ex in session {
                            XCTAssertEqual(ex.trainsSkill, skill,
                                           "\(node.id): a \(focus) pass contains a \(ex.kind) question")
                        }
                    }
                }
            }
        }
    }

    func testTheReviewPassStillMixesEverything() {
        let unit = curriculum.allUnits[5]
        let node = unit.nodes(level: .a1, index: 0)[0]
        var skills = Set<Skill>(), kinds = Set<Exercise.Kind>()
        for _ in 0..<15 {
            for ex in ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                              native: .en, settings: Settings(), focus: .review) {
                skills.insert(ex.trainsSkill); kinds.insert(ex.kind)
            }
        }
        XCTAssertEqual(skills, Set(Skill.allCases))
        XCTAssertGreaterThanOrEqual(kinds.count, 6, "the review pass should use many formats")
    }

    /// A focused pass is not one format repeated: listening and speaking each have
    /// several, reading has its own, writing has translations and a text.
    func testAFocusedPassStillVariesItsFormats() {
        let unit = curriculum.allUnits[5]
        let node = unit.nodes(level: .a1, index: 0)[0]
        let expected: [SessionFocus: Int] = [.discover: 3, .listening: 3, .writing: 2, .speaking: 2]
        for (focus, minimum) in expected {
            var kinds = Set<Exercise.Kind>()
            for _ in 0..<15 {
                kinds.formUnion(ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                        native: .en, settings: Settings(), focus: focus).map(\.kind))
            }
            XCTAssertGreaterThanOrEqual(kinds.count, minimum, "\(focus) uses only \(kinds)")
        }
    }

    func testLessonsAreShortButNotTrivial() {
        for unit in curriculum.allUnits.prefix(6) {
            for node in unit.nodes(level: .a1, index: 0) {
                guard case .lesson = node.kind else { continue }
                for focus in SessionFocus.allCases {
                    let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                          native: .en, settings: Settings(), focus: focus)
                    XCTAssertLessThanOrEqual(session.count, focus.length, "\(node.id)/\(focus) is too long")
                    XCTAssertGreaterThanOrEqual(session.count, 6, "\(node.id)/\(focus) is too short")
                }
            }
        }
    }

    func testTheWritingPassEndsOnAShortText() {
        var withText = 0, total = 0
        for unit in curriculum.allUnits.prefix(8) {
            for node in unit.nodes(level: .a1, index: 0) {
                guard case .lesson = node.kind else { continue }
                let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                      native: .en, settings: Settings(), focus: .writing)
                total += 1
                if session.last?.kind == .compose { withText += 1 }
                XCTAssertLessThanOrEqual(session.filter { $0.kind == .compose }.count, 1)
            }
        }
        XCTAssertGreaterThan(Double(withText) / Double(total), 0.9, "nearly every lesson has sentences for a text")
    }

    func testASkillSwitchedOffTurnsItsPassIntoAReview() {
        var settings = Settings()
        settings.listeningExercises = false
        settings.speakingExercises = false
        XCTAssertEqual(SessionFocus.listening.available(with: settings), .review)
        XCTAssertEqual(SessionFocus.speaking.available(with: settings), .review)
        XCTAssertEqual(SessionFocus.writing.available(with: settings), .writing)

        let unit = curriculum.allUnits[2]
        let node = unit.nodes(level: .a1, index: 0)[0]
        let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                              native: .en, settings: settings, focus: .listening)
        XCTAssertFalse(session.isEmpty)
        XCTAssertFalse(session.contains { $0.trainsSkill == .listening || $0.trainsSkill == .speaking })
    }

    func testTheFiveSessionsOfANodeAreNotTheSameWorkout() {
        let unit = curriculum.allUnits[2]
        let node = unit.nodes(level: .a1, index: 0)[0]
        var shares: [SessionFocus: [Skill: Double]] = [:]
        for pass in 0..<node.requiredSessions {
            let focus = node.focus(forSession: pass)
            var counts: [Skill: Int] = [:]
            var total = 0
            for _ in 0..<6 {
                let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                      native: .en, settings: Settings(), focus: focus)
                XCTAssertFalse(session.isEmpty)
                for ex in session { counts[ex.trainsSkill, default: 0] += 1; total += 1 }
            }
            shares[focus] = counts.mapValues { Double($0) / Double(total) }
        }
        XCTAssertEqual(shares.count, 5)
        for focus in [SessionFocus.discover, .listening, .writing, .speaking] {
            XCTAssertEqual(shares[focus]?[focus.skill!] ?? 0, 1, accuracy: 0.0001,
                           "the \(focus) pass should be all \(focus.skill!)")
        }
    }

    func testEveryFocusStaysAnswerableOnASampleOfNodes() {
        for pack in curriculum.levels {
            for unit in pack.units.prefix(2) {
                // the writing chapter is a conversation, not a set of exercises
                for node in unit.nodes(level: pack.level, index: 0) where !node.isWriting {
                    for focus in SessionFocus.allCases {
                        let session = ExerciseFactory.session(for: node, unit: unit,
                                                              curriculum: curriculum,
                                                              native: .en, settings: Settings(),
                                                              focus: focus)
                        XCTAssertFalse(session.isEmpty, "\(node.id)/\(focus) is empty")
                        for ex in session { assertValid(ex, native: .en, node: node.id) }
                    }
                }
            }
        }
    }

    // MARK: - Invariants

    private func assertValid(_ ex: Exercise, native: Language, node: String) {
        let target = native.other
        if ex.kind != .match {
            XCTAssertFalse(ex.answer.isEmpty, "\(node): \(ex.kind) has no answer")
        }

        switch ex.kind {
        case .choice, .listenChoice, .listenMeaning, .fillBlank:
            XCTAssertEqual(ex.options.count, 4, "\(node): \(ex.kind) needs four options")
            let normalised = ex.options.map(Grader.normalise)
            XCTAssertEqual(Set(normalised).count, 4, "\(node): duplicate options \(ex.options)")
            XCTAssertTrue(normalised.contains(Grader.normalise(ex.answer)),
                          "\(node): correct answer missing from the options")
            XCTAssertFalse(ex.options.contains { $0.contains("?") && $0.hasSuffix(" ?") },
                           "\(node): placeholder distractor leaked in")
            XCTAssertFalse(ex.options.contains("…"), "\(node): empty decoy leaked in")
            if ex.kind == .fillBlank {
                XCTAssertTrue(ex.prompt.contains("____"), "\(node): gap missing from the sentence")
            }

        case .wordBank:
            let answerTokens = Grader.tokenize(ex.answer).map(Grader.normalise).sorted()
            var bank = ex.tokens.map(Grader.normalise)
            for token in answerTokens {
                guard let i = bank.firstIndex(of: token) else {
                    return XCTFail("\(node): word bank cannot build '\(ex.answer)' (missing '\(token)')")
                }
                bank.remove(at: i)
            }
            XCTAssertGreaterThan(ex.tokens.count, answerTokens.count,
                                 "\(node): word bank has no decoys")
            XCTAssertFalse(ex.prompt.isEmpty)

        case .listenBuild:
            let answerTokens = Grader.tokenize(ex.answer).map(Grader.normalise).sorted()
            var bank = ex.tokens.map(Grader.normalise)
            for token in answerTokens {
                guard let i = bank.firstIndex(of: token) else {
                    return XCTFail("\(node): cannot rebuild '\(ex.answer)' (missing '\(token)')")
                }
                bank.remove(at: i)
            }
            XCTAssertEqual(ex.audioLanguage, target)
            XCTAssertEqual(ex.audioText, ex.answer, "\(node): what is heard is what is built")

        case .type, .listenType:
            XCTAssertFalse(ex.answer.isEmpty)
            if ex.kind == .listenType {
                XCTAssertEqual(ex.audioLanguage, target)
                XCTAssertFalse((ex.audioText ?? "").isEmpty)
            } else {
                XCTAssertFalse(ex.prompt.isEmpty)
            }

        case .speak, .speakRepeat:
            XCTAssertEqual(ex.promptLanguage, target)
            XCTAssertEqual(ex.answer, ex.prompt)
            XCTAssertFalse((ex.hint ?? "").isEmpty, "\(node): speaking exercise without meaning hint")

        case .compose:
            guard let task = ex.composition else { return XCTFail("\(node): a text with no brief") }
            XCTAssertGreaterThanOrEqual(task.outline.count, 2, "\(node): a text needs at least two things to say")
            XCTAssertFalse(task.starter.isEmpty)
            XCTAssertTrue(task.outline[0][target].hasPrefix(task.starter),
                          "\(node): the start of the text must be the start of the model")
            XCTAssertFalse(task.wordBank.isEmpty)
            XCTAssertEqual(ex.answer, task.model)

        case .match:
            XCTAssertGreaterThanOrEqual(ex.matchPairs.count, 4)
            XCTAssertLessThanOrEqual(ex.matchPairs.count, 5)
            XCTAssertEqual(Set(ex.matchPairs.map { Grader.normalise($0[target]) }).count,
                           ex.matchPairs.count, "\(node): duplicate item in the matching game")
            XCTAssertEqual(Set(ex.matchPairs.map { Grader.normalise($0[native]) }).count,
                           ex.matchPairs.count, "\(node): duplicate translation in the matching game")
        }
    }
}
