import XCTest
@testable import Uzbelia

/// The free-conversation video call: question planning and the end-of-call report.
final class CallPlannerTests: XCTestCase {

    private func freshState() -> AppState {
        let s = AppState(persistent: false)
        s.chooseCourse(native: .it)
        return s
    }

    func testEveryUnitHasContextualQuestions() {
        let state = freshState()
        XCTAssertEqual(state.questions.units.count, state.curriculum.allUnits.count)
        for unit in state.curriculum.allUnits {
            let qs = state.questions.questions(forUnit: unit.id)
            XCTAssertGreaterThanOrEqual(qs.count, 6, "\(unit.id) has too few call questions")
            for q in qs {
                XCTAssertFalse(q.it.isEmpty || q.uz.isEmpty)
                XCTAssertTrue(q.it.contains("?") || q.it.contains("."),
                              "\(unit.id): '\(q.it)' does not read like a prompt")
            }
        }
        for level in CEFR.allCases {
            for slot in ["open", "follow", "close"] {
                XCTAssertGreaterThanOrEqual(state.questions.generic(level, slot).count, 2,
                                            "\(level.label).\(slot) needs variants")
            }
        }
    }

    func testACallIsBuiltAroundTheChapterYouReached() {
        let state = freshState()
        // walk the learner up to the food unit
        let food = state.curriculum.unit(id: "a1u4")!
        let target = PlacementTest.target(skippingTo: food.nodes(level: .a1, index: 0)[0], state: state)!
        state.markPassedTest(target, accuracy: 0.9)

        let plan = CallPlanner.plan(level: .a1, state: state)
        XCTAssertEqual(plan.focusUnit?.id, "a1u4")
        XCTAssertGreaterThanOrEqual(plan.questions.count, 5)

        let fromFocus = plan.questions.filter { $0.unitID == "a1u4" }
        XCTAssertGreaterThanOrEqual(fromFocus.count, 3,
                                    "most questions should come from the current chapter")
        XCTAssertTrue(plan.questions.first?.origin == .opening)
        XCTAssertTrue(plan.questions.last?.origin == .closing)
        XCTAssertFalse(plan.questions.contains { $0.unitID == "a1u8" },
                       "a call must not ask about chapters the learner has not reached")
    }

    func testTwoCallsAreNeverIdentical() {
        let state = freshState()
        let food = state.curriculum.unit(id: "a1u4")!
        let target = PlacementTest.target(skippingTo: food.nodes(level: .a1, index: 0)[0], state: state)!
        state.markPassedTest(target, accuracy: 0.9)

        var signatures = Set<String>()
        for _ in 0..<12 {
            let plan = CallPlanner.plan(level: .a1, state: state)
            signatures.insert(plan.questions.map { $0.text.uz }.joined(separator: "|"))
        }
        XCTAssertGreaterThan(signatures.count, 8, "calls repeat themselves too often")
    }

    func testEveryLevelCanBeCalled() {
        let state = freshState()
        state.unlock(level: .b2)
        for level in CEFR.allCases {
            let plan = CallPlanner.plan(level: level, state: state)
            XCTAssertFalse(plan.questions.isEmpty, "\(level.label) produced no questions")
            XCTAssertNotNil(plan.focusUnit)
        }
    }
}

final class CallReviewerTests: XCTestCase {

    private var curriculum: Curriculum!
    override func setUp() {
        super.setUp()
        curriculum = ContentStore.loadCurriculum()
    }

    private func review(_ answers: [String], native: Language = .it, level: CEFR = .a1) -> CallReview {
        let turns = answers.map {
            CallTurnRecord(question: Bilingual(it: "Domanda?", uz: "Savol?"),
                           answer: $0, seconds: 5, typed: true)
        }
        return CallReviewer.review(turns: turns, native: native,
                                   curriculum: curriculum, level: level)
    }

    func testSkippedAnswersAreReported() {
        let r = review(["", "   "])
        XCTAssertEqual(r.turns.filter { $0.status == .skipped }.count, 2)
        XCTAssertEqual(r.stats.answered, 0)
    }

    func testAnsweringInTheWrongLanguageIsCaught() {
        let r = review(["mi chiamo Claudia e vivo a Roma"])       // Italian, learning Uzbek
        XCTAssertEqual(r.turns[0].status, .wrongLanguage)
        XCTAssertTrue(r.turns[0].corrections.contains { $0.kind == .language })
    }

    func testSpellingSlipsGetTheRightSuggestion() {
        let r = review(["rahmet, men yaxshiman"])
        let fix = r.turns[0].corrections.first { $0.kind == .spelling }
        XCTAssertEqual(fix?.original, "rahmet")
        XCTAssertEqual(fix?.suggestion, "rahmat")
    }

    func testUzbekGrammarRules() {
        let plural = review(["menda uchta kitoblar bor"])
        XCTAssertTrue(plural.turns[0].corrections.contains {
            $0.kind == .grammar && $0.suggestion.contains("uchta kitob")
        }, "the plural after a numeral should be corrected")

        let split = review(["men yaxshi man bugun"])
        XCTAssertTrue(split.turns[0].corrections.contains {
            $0.kind == .grammar && $0.suggestion.contains("yaxshiman")
        }, "a detached personal ending should be joined")
    }

    func testItalianGrammarRulesForUzbekSpeakers() {
        let aux = review(["ieri ho andato a scuola"], native: .uz, level: .a2)
        XCTAssertTrue(aux.turns[0].corrections.contains {
            $0.kind == .grammar && $0.suggestion.contains("sono andato")
        }, "motion verbs take essere")

        let city = review(["io vivo in Roma"], native: .uz, level: .a2)
        XCTAssertTrue(city.turns[0].corrections.contains {
            $0.kind == .grammar && $0.suggestion.contains("a roma")
        }, "cities take a")

        let age = review(["io sono venticinque anni"], native: .uz, level: .a2)
        XCTAssertTrue(age.turns[0].corrections.contains {
            $0.kind == .grammar && $0.suggestion.contains("ho venticinque anni")
        }, "age is said with avere")
    }

    func testAGoodAnswerIsLeftAlone() {
        let r = review(["men bugun juda yaxshiman va ishga boraman"])
        XCTAssertEqual(r.turns[0].status, .good)
        XCTAssertFalse(r.turns[0].corrections.contains { $0.kind == .grammar },
                       "a correct sentence must not be 'corrected'")
    }

    func testShortAnswersAreFlaggedButNotPunished() {
        let one = review(["ha"], level: .b1)
        XCTAssertEqual(one.turns[0].status, .tooShort)
        XCTAssertFalse(one.tips.contains { $0.it.contains("brevi") },
                       "a single short answer is not a habit worth nagging about")

        // it only becomes advice when it is a pattern
        let many = review(["ha", "yaxshi", "bilmayman"], level: .b1)
        XCTAssertEqual(many.turns.filter { $0.status == .tooShort }.count, 3)
        XCTAssertTrue(many.tips.contains { $0.it.contains("brevi") })
    }

    func testStatsAndHeadline() {
        let r = review(["men Toshkentdanman va bu yerda yashayman",
                        "men har kuni ishga boraman",
                        ""])
        XCTAssertEqual(r.stats.total, 3)
        XCTAssertEqual(r.stats.answered, 2)
        XCTAssertGreaterThan(r.stats.words, 8)
        XCTAssertGreaterThan(r.stats.distinctWords, 5)
        XCTAssertFalse(r.headline.it.isEmpty)
        XCTAssertFalse(r.tips.isEmpty)
    }

    func testAValidWordTheCourseDoesNotTeachIsLeftAlone() {
        // "deyman" (I say) is correct Uzbek but absent from the corpus: it must not be
        // "fixed" into "yeyman" (I eat) just because they are one letter apart.
        let r = review(["men rahmet deyman"])
        let fixes = r.turns[0].corrections.filter { $0.kind == .spelling }
        XCTAssertTrue(fixes.contains { $0.original == "rahmet" && $0.suggestion == "rahmat" },
                      "a real typo should still be caught")
        XCTAssertFalse(fixes.contains { $0.original == "deyman" },
                       "a word with a different initial letter is not a typo")
    }

    func testTheReviewerNeverCorrectsWhatItCannotJustify() {
        // a name it has never seen must not be "fixed" into something random
        let r = review(["men Klaudiyaman"])
        XCTAssertFalse(r.turns[0].corrections.contains {
            $0.kind == .spelling && $0.suggestion.count < 4
        })
    }
}

final class CallEngineFlowTests: XCTestCase {

    func testAFullCallRecordsEveryAnswer() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        let plan = CallPlanner.plan(level: .a1, state: state)
        let engine = CallEngine(level: .a1, native: .it, plan: plan)

        XCTAssertEqual(engine.phase, .dialling)
        engine.answerCall()
        XCTAssertEqual(engine.phase, .anorchaSpeaking)

        for i in 0..<plan.questions.count {
            engine.anorchaFinishedSpeaking()
            XCTAssertEqual(engine.phase, .yourTurn)
            engine.submit(i == 1 ? "" : "men yaxshiman", typed: true)
            XCTAssertEqual(engine.phase, .reacting)
            engine.advance()
        }
        XCTAssertEqual(engine.phase, .reviewing)
        XCTAssertEqual(engine.records.count, plan.questions.count)
        XCTAssertEqual(engine.xpEarned, 10 + (plan.questions.count - 1) * 5)
    }

    func testHangingUpEarlyStillReviewsWhatWasSaid() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        let plan = CallPlanner.plan(level: .a1, state: state)
        let engine = CallEngine(level: .a1, native: .it, plan: plan)
        engine.answerCall()
        engine.anorchaFinishedSpeaking()
        engine.submit("men italiyalikman", typed: true)
        engine.advance()
        engine.hangUp()
        XCTAssertEqual(engine.phase, .reviewing)
        XCTAssertEqual(engine.records.count, 1)
    }
}
