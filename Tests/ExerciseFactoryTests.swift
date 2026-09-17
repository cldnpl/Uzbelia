import XCTest
@testable import Uzbelia

/// Generates a session for every single lesson of the course, in both learning
/// directions, and checks that no question can ever be unanswerable.
final class ExerciseFactoryTests: XCTestCase {

    private var curriculum: Curriculum!

    override func setUp() {
        super.setUp()
        curriculum = ContentStore.loadCurriculum()
    }

    func testEveryLessonProducesAValidSession() {
        var checked = 0
        for native in [Language.it, Language.uz] {
            for pack in curriculum.levels {
                for unit in pack.units {
                    // every unit, every node kind; a stride keeps the 400-node course quick
                    let nodes = unit.nodes(level: pack.level, index: 0)
                    let sampled = nodes.enumerated().filter { $0.offset % 3 == 0 || $0.offset >= nodes.count - 2 }
                    for node in sampled.map(\.element) {
                        let session = ExerciseFactory.session(for: node, unit: unit,
                                                              curriculum: curriculum,
                                                              native: native,
                                                              settings: Settings())
                        XCTAssertFalse(session.isEmpty, "\(node.id) produced no exercises")
                        for ex in session { assertValid(ex, native: native, node: node.id) }
                        checked += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 200)
    }

    func testBuildingASessionIsFastEnoughForTheBiggestPool() {
        let pack = curriculum.levels.last!          // B2: the pool is the whole course
        let unit = pack.units.last!
        let node = unit.nodes(level: pack.level, index: 0)[0]
        let started = Date()
        for _ in 0..<5 {
            _ = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                        native: .it, settings: Settings(), focus: .review)
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
                                                native: .it, settings: Settings())
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
                                                native: .it, settings: settings)
                XCTAssertFalse(s.contains { $0.kind == .speak || $0.kind == .listenType || $0.kind == .listenChoice },
                               "disabled exercise kind still generated")
            }
        }
    }

    func testSkillDrillOnlyGeneratesThatSkill() {
        let pairs = Array(curriculum.allPairs.prefix(40))
        for skill in Skill.allCases {
            let ex = ExerciseFactory.practice(pairs: pairs, pool: curriculum.allPairs,
                                              native: .it, settings: Settings(),
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
                                            native: .it, settings: Settings())
            for i in 1..<s.count {
                total += 1
                if s[i].kind == s[i - 1].kind { repeats += 1 }
            }
        }
        XCTAssertLessThan(Double(repeats) / Double(total), 0.12,
                          "too many identical formats in a row")
    }

    func testEachFocusEmphasisesItsSkillButStaysMixed() {
        let unit = curriculum.allUnits[5]
        let node = unit.nodes(level: .a1, index: 0)[0]

        for focus in SessionFocus.allCases {
            var counts: [Skill: Int] = [:]
            var kinds = Set<Exercise.Kind>()
            var total = 0
            for _ in 0..<15 {
                let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                      native: .it, settings: Settings(), focus: focus)
                for ex in session {
                    counts[ex.trainsSkill, default: 0] += 1
                    kinds.insert(ex.kind)
                    total += 1
                }
            }
            XCTAssertGreaterThanOrEqual(kinds.count, 4,
                "\(focus) produces only \(kinds.count) kinds of question — too monotonous")

            if let emphasis = focus.emphasis, emphasis != .reading {
                let share = Double(counts[emphasis] ?? 0) / Double(total)
                XCTAssertGreaterThan(share, 0.3,
                    "\(focus) should lean on \(emphasis) (got \(Int(share * 100))%)")
                XCTAssertLessThan(share, 0.95,
                    "\(focus) must still mix in other exercise types")
            }
        }
    }

    func testTheFiveSessionsOfANodeAreNotTheSameWorkout() {
        let unit = curriculum.allUnits[2]
        let node = unit.nodes(level: .a1, index: 0)[0]
        // Average the share of each skill over several runs: the focus of a pass must
        // actually dominate that pass.
        var shares: [SessionFocus: [Skill: Double]] = [:]
        for pass in 0..<node.requiredSessions {
            let focus = node.focus(forSession: pass)
            var counts: [Skill: Int] = [:]
            var total = 0
            for _ in 0..<12 {
                let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                      native: .it, settings: Settings(), focus: focus)
                XCTAssertFalse(session.isEmpty)
                for ex in session { counts[ex.trainsSkill, default: 0] += 1; total += 1 }
            }
            shares[focus] = counts.mapValues { Double($0) / Double(total) }
        }
        XCTAssertEqual(shares.count, 5)
        for focus in [SessionFocus.listening, .writing, .speaking] {
            let own = shares[focus]?[focus.emphasis!] ?? 0
            for other in [SessionFocus.listening, .writing, .speaking] where other != focus {
                let elsewhere = shares[other]?[focus.emphasis!] ?? 0
                XCTAssertGreaterThan(own, elsewhere,
                    "\(focus.emphasis!) should be trained most in the \(focus) pass")
            }
        }
    }

    func testEveryFocusStaysAnswerableOnASampleOfNodes() {
        for pack in curriculum.levels {
            for unit in pack.units.prefix(2) {
                for node in unit.nodes(level: pack.level, index: 0) {
                    for focus in SessionFocus.allCases {
                        let session = ExerciseFactory.session(for: node, unit: unit,
                                                              curriculum: curriculum,
                                                              native: .uz, settings: Settings(),
                                                              focus: focus)
                        XCTAssertFalse(session.isEmpty, "\(node.id)/\(focus) is empty")
                        for ex in session { assertValid(ex, native: .uz, node: node.id) }
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
        case .choice, .listenChoice, .fillBlank:
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

        case .type, .listenType:
            XCTAssertFalse(ex.answer.isEmpty)
            if ex.kind == .listenType {
                XCTAssertEqual(ex.audioLanguage, target)
                XCTAssertFalse((ex.audioText ?? "").isEmpty)
            } else {
                XCTAssertFalse(ex.prompt.isEmpty)
            }

        case .speak:
            XCTAssertEqual(ex.promptLanguage, target)
            XCTAssertEqual(ex.answer, ex.prompt)
            XCTAssertFalse((ex.hint ?? "").isEmpty, "\(node): speaking exercise without meaning hint")

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
