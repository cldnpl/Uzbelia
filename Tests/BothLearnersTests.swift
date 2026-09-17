import XCTest
@testable import Uzbelia

/// Two people, one app, opposite directions: she learns Uzbek, he learns Italian.
/// Everything the course does has to work just as well read backwards.
final class BothDirectionsTests: XCTestCase {

    private func learner(native: Language) -> AppState {
        let state = AppState(persistent: false)
        state.chooseCourse(native: native)
        return state
    }

    func testTheCourseRunsInBothDirections() {
        for native in Language.allCases {
            let state = learner(native: native)
            XCTAssertEqual(state.native, native)
            XCTAssertEqual(state.target, native.other)
            XCTAssertFalse(state.curriculum.allUnits.isEmpty, "\(native) has no course")
        }
    }

    func testEveryPairIsWrittenOnBothSides() {
        let curriculum = ContentStore.loadCurriculum()
        for pair in curriculum.allPairs {
            XCTAssertFalse(pair.it.trimmingCharacters(in: .whitespaces).isEmpty,
                           "'\(pair.uz)' has no Italian side")
            XCTAssertFalse(pair.uz.trimmingCharacters(in: .whitespaces).isEmpty,
                           "'\(pair.it)' has no Uzbek side")
        }
    }

    func testEveryTitleAndBlurbIsWrittenInBothLanguages() {
        let curriculum = ContentStore.loadCurriculum()
        for pack in curriculum.levels {
            XCTAssertFalse(pack.level.blurb.it.isEmpty || pack.level.blurb.uz.isEmpty)
            for unit in pack.units {
                XCTAssertFalse(unit.title.it.isEmpty || unit.title.uz.isEmpty, unit.id)
                for lesson in unit.lessons {
                    XCTAssertFalse(lesson.title.it.isEmpty || lesson.title.uz.isEmpty, lesson.id)
                }
            }
        }
    }

    func testALessonBuildsProperlyForAnUzbekSpeakerLearningItalian() {
        let state = learner(native: .uz)
        guard let unit = state.curriculum.allUnits.first,
              let node = unit.nodes(level: .a1, index: 0).first else {
            return XCTFail("no lesson to build")
        }
        let session = ExerciseFactory.session(for: node, unit: unit,
                                              curriculum: state.curriculum,
                                              native: .uz, settings: state.settings)
        XCTAssertFalse(session.isEmpty)
        for ex in session where ex.kind != .match {
            XCTAssertFalse(ex.answer.isEmpty, "\(ex.kind) has nothing to answer")
            // a translation crosses the two languages; dictation, fill-in-the-blank and
            // pronunciation all stay inside the language being learnt, by design
            if [Exercise.Kind.choice, .wordBank, .type].contains(ex.kind) {
                XCTAssertNotEqual(ex.promptLanguage, ex.answerLanguage,
                                  "\(ex.kind) asks and answers in the same language")
            } else {
                XCTAssertEqual(ex.answerLanguage, .it,
                               "\(ex.kind) should be practising the language he is learning")
            }
            // he is learning Italian, so that is the side the audio must be on
            if let audio = ex.audioLanguage { XCTAssertEqual(audio, .it) }
        }
    }

    func testTheInstructionsAndSkillNamesExistInBothLanguages() {
        let ex = Exercise(kind: .type, pair: Pair(it: "ciao", uz: "salom"),
                          prompt: "salom", promptLanguage: .uz,
                          answer: "ciao", answerLanguage: .it)
        for kind in [Exercise.Kind.choice, .listenChoice, .wordBank, .type,
                     .listenType, .speak, .match, .fillBlank] {
            var probe = ex
            probe.kind = kind
            XCTAssertFalse(probe.instruction.it.isEmpty || probe.instruction.uz.isEmpty,
                           "\(kind) has no instruction in one of the two languages")
        }
        for skill in Skill.allCases {
            XCTAssertFalse(skill.label.it.isEmpty || skill.label.uz.isEmpty)
        }
    }

    func testTheReviewCorrectsItalianForHimAndUzbekForHer() {
        let curriculum = ContentStore.loadCurriculum()
        func review(_ answer: String, native: Language) -> CallReview {
            CallReviewer.review(turns: [CallTurnRecord(question: Bilingual(it: "?", uz: "?"),
                                                       answer: answer, seconds: 5, typed: true)],
                                native: native, curriculum: curriculum, level: .a2)
        }
        // he writes Italian: the Italian rules apply
        XCTAssertTrue(review("ieri ho andato a scuola", native: .uz)
            .turns[0].corrections.contains { $0.suggestion.contains("sono andato") })
        // she writes Uzbek: the Uzbek ones do
        XCTAssertTrue(review("men yaxshi man bugun", native: .it)
            .turns[0].corrections.contains { $0.suggestion.contains("yaxshiman") })
    }

    func testAnswersAreGradedInWhicheverLanguageIsBeingLearnt() {
        XCTAssertEqual(Grader.grade("sto bene, grazie", expected: "Sto bene, grazie."), .correct)
        XCTAssertEqual(Grader.grade("yaxshiman rahmat", expected: "Yaxshiman, rahmat."), .correct)
    }

    func testTheTwoOfThemKeepSeparateProgress() {
        let her = learner(native: .it)
        let him = learner(native: .uz)
        her.addXP(50, minutes: 5)
        XCTAssertEqual(her.xp, 50)
        XCTAssertEqual(him.xp, 0, "progress lives on each phone, not in the app itself")
    }
}
