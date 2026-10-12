import XCTest
@testable import Uzbelia

/// One app, several courses, every one of them taught from English. Whatever a course
/// does has to hold for whichever one she picks, and moving between them must never
/// mix two courses' progress or lose either.
final class CoursesTests: XCTestCase {

    private func learner(_ course: Language = .uz) -> AppState {
        let state = AppState(persistent: false)
        state.chooseCourse(course)
        return state
    }

    func testEveryCourseInTheBundleIsTaughtFromEnglish() {
        // the course is global state: leave Uzbek loaded for the tests that follow
        defer { _ = learner(.uz) }
        let bundled = Language.courses.filter(ContentStore.hasCourse)
        XCTAssertTrue(bundled.contains(.uz), "the Uzbek course must ship with the app")
        XCTAssertFalse(Language.courses.contains(.en), "English is the interface, not a course")
        for course in bundled {
            let state = learner(course)
            XCTAssertEqual(state.native, .en)
            XCTAssertEqual(state.target, course)
            XCTAssertEqual(Language.current, course)
            XCTAssertEqual(course.other, .en)
            XCTAssertEqual(Language.en.other, course, "English pairs up with the course being taken")
            XCTAssertFalse(state.curriculum.allUnits.isEmpty, "\(course) has no units")
        }
    }

    func testEveryPairIsWrittenOnBothSides() {
        let curriculum = ContentStore.loadCurriculum(.uz)
        for pair in curriculum.allPairs {
            XCTAssertFalse(pair.en.trimmingCharacters(in: .whitespaces).isEmpty,
                           "'\(pair.tx)' has no English side")
            XCTAssertFalse(pair.tx.trimmingCharacters(in: .whitespaces).isEmpty,
                           "'\(pair.en)' has no Uzbek side")
        }
    }

    func testEveryTitleAndBlurbIsWritten() {
        let curriculum = ContentStore.loadCurriculum(.uz)
        for pack in curriculum.levels {
            XCTAssertFalse(pack.level.blurb.en.isEmpty)
            for unit in pack.units {
                XCTAssertFalse(unit.title.en.isEmpty || unit.title.tx.isEmpty, unit.id)
                for lesson in unit.lessons {
                    XCTAssertFalse(lesson.title.en.isEmpty || lesson.title.tx.isEmpty, lesson.id)
                }
            }
        }
    }

    func testALessonBuildsProperlyForAnEnglishSpeakerLearningUzbek() {
        let state = learner(.uz)
        guard let unit = state.curriculum.allUnits.first,
              let node = unit.nodes(level: .a1, index: 0).first else {
            return XCTFail("no lesson to build")
        }
        let session = ExerciseFactory.session(for: node, unit: unit,
                                              curriculum: state.curriculum,
                                              native: state.native, settings: state.settings)
        XCTAssertFalse(session.isEmpty)
        for ex in session where ex.kind != .match {
            XCTAssertFalse(ex.answer.isEmpty, "\(ex.kind) has nothing to answer")
            // a translation crosses the two languages; dictation, fill-in-the-blank and
            // pronunciation all stay inside the language being learnt, by design
            if [Exercise.Kind.choice, .wordBank, .type, .listenMeaning].contains(ex.kind) {
                XCTAssertNotEqual(ex.promptLanguage, ex.answerLanguage,
                                  "\(ex.kind) asks and answers in the same language")
            } else {
                XCTAssertEqual(ex.answerLanguage, .uz,
                               "\(ex.kind) should be practising the language she is learning")
            }
            // she is learning Uzbek, so that is the side the audio must be on
            if let audio = ex.audioLanguage { XCTAssertEqual(audio, .uz) }
        }
    }

    func testEveryInstructionAndSkillHasALabel() {
        let ex = Exercise(kind: .type, pair: Pair(en: "hello", tx: "salom"),
                          prompt: "hello", promptLanguage: .en,
                          answer: "salom", answerLanguage: .uz)
        for kind in [Exercise.Kind.choice, .listenChoice, .wordBank, .type, .listenType,
                     .speak, .match, .fillBlank, .listenMeaning, .listenBuild, .speakRepeat, .compose] {
            var probe = ex
            probe.kind = kind
            XCTAssertFalse(probe.instruction.en.isEmpty, "\(kind) has no instruction")
        }
        for skill in Skill.allCases {
            XCTAssertFalse(skill.label.en.isEmpty)
        }
    }

    func testTheReviewCorrectsUzbekWithTheUzbekRulesOnly() {
        let curriculum = ContentStore.loadCurriculum(.uz)
        let review = CallReviewer.review(turns: [CallTurnRecord(question: Bilingual(en: "?", tx: "?"),
                                                                answer: "men yaxshi man bugun",
                                                                seconds: 5, typed: true)],
                                         target: .uz, curriculum: curriculum, level: .a2)
        XCTAssertTrue(review.turns[0].corrections.contains { $0.suggestion.contains("yaxshiman") })
        // the rules were written for Uzbek: another course never has them applied
        XCTAssertTrue(CallReviewer.grammarChecks("men yaxshi man bugun", target: .ms).isEmpty)
    }

    func testAnswersAreGradedInEitherLanguage() {
        XCTAssertEqual(Grader.grade("i'm fine, thank you", expected: "I'm fine, thank you."), .correct)
        XCTAssertEqual(Grader.grade("yaxshiman rahmat", expected: "Yaxshiman, rahmat."), .correct)
    }

    func testTwoLearnersKeepSeparateProgress() {
        let her = learner()
        let him = learner()
        her.addXP(50, minutes: 5)
        XCTAssertEqual(her.xp, 50)
        XCTAssertEqual(him.xp, 0, "progress lives on each phone, not in the app itself")
    }

    // MARK: - Moving between courses

    func testSwitchingCourseShelvesTheOldOneAndBringsItBackWhole() {
        var saved = PersistedState()
        saved.switchCourse(to: .uz)
        saved.xp = 120
        saved.records["a1u1l1"] = LessonRecord(completions: 3)
        saved.unlockedLevels.insert("a2")

        saved.switchCourse(to: .th)
        XCTAssertEqual(saved.course, .th)
        XCTAssertTrue(saved.records.isEmpty, "a new course starts from its first lesson")
        XCTAssertEqual(saved.unlockedLevels, ["a1"])
        XCTAssertEqual(saved.shelved["uz"]?.records["a1u1l1"]?.completions, 3)
        XCTAssertEqual(saved.xp, 120, "her XP is hers, not the course's")

        saved.switchCourse(to: .uz)
        XCTAssertEqual(saved.records["a1u1l1"]?.completions, 3, "nothing is lost on the shelf")
        XCTAssertTrue(saved.unlockedLevels.contains("a2"))
        XCTAssertNotNil(saved.shelved["th"])
        XCTAssertNil(saved.shelved["uz"], "the course being taken is not also on the shelf")
    }

    func testASaveFromTheItalianDaysCarriesOnInTheEnglishCourse() throws {
        let legacy = #"""
        {"nativeLanguage":"it","xp":40,"onboarded":true,
         "srs":{"ciao|salom":{"pairID":"ciao|salom","strength":0.8,"reps":4}},
         "mistakesBank":[["grazie","rahmat"]],
         "wordGlosses":{"uz|salom":"ciao"}}
        """#
        let saved = try JSONDecoder().decode(PersistedState.self, from: Data(legacy.utf8))
        XCTAssertEqual(saved.course, .uz, "an Italian learning Uzbek carries on with Uzbek")
        XCTAssertTrue(saved.needsEnglishRebase)
        XCTAssertEqual(saved.xp, 40)

        // her word memory moves from the Italian side onto the English one
        let state = AppState(persistent: false)
        state.adopt(saved)
        XCTAssertFalse(state.snapshot.needsEnglishRebase)
        XCTAssertEqual(state.snapshot.srs["hello|salom"]?.reps, 4)
        XCTAssertEqual(state.snapshot.srs["hello|salom"]?.pairID, "hello|salom")
        XCTAssertNil(state.snapshot.srs["ciao|salom"])
        XCTAssertEqual(state.mistakesBank.map(\.tx), ["rahmat"])
        XCTAssertTrue(state.mistakesBank.allSatisfy { state.curriculum.allPairs.contains($0) })
        XCTAssertTrue(state.snapshot.wordGlosses.isEmpty, "Italian glosses mean nothing to her now")

        let uzbekSpeaker = #"{"nativeLanguage":"uz","xp":40}"#
        let other = try JSONDecoder().decode(PersistedState.self, from: Data(uzbekSpeaker.utf8))
        XCTAssertNil(other.course, "the Italian course is gone: that learner picks a course again")
        XCTAssertFalse(other.needsEnglishRebase)
    }
}
