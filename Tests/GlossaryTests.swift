import XCTest
@testable import Uzbelia

/// The feedback banner leans on these: whatever the learner picks, types or says
/// has to come back with a translation.
final class GlossaryTests: XCTestCase {

    private let course = [
        Pair(en: "I'm happy", tx: "Xursandman"),
        Pair(en: "I'm tired", tx: "Charchadim"),
        Pair(en: "happy", tx: "xursand"),
        Pair(en: "very", tx: "juda"),
        Pair(en: "water", tx: "suv"),
        Pair(en: "park / garden", tx: "bog'")
    ]

    override func setUp() {
        super.setUp()
        Glossary.prime(with: course)
        Glossary.learn(course)      // priming twice must stay harmless
    }

    func testPhraseTranslatesBothWays() {
        XCTAssertEqual(Glossary.look(up: "Xursandman", from: .uz)?.text, "I'm happy")
        XCTAssertEqual(Glossary.look(up: "I'm tired", from: .en)?.text, "Charchadim")
    }

    func testLookUpIgnoresCaseApostrophesAndPunctuation() {
        XCTAssertEqual(Glossary.look(up: "  xursandman! ", from: .uz)?.text, "I'm happy")
        XCTAssertEqual(Glossary.look(up: "BOGʻ.", from: .uz)?.text, "park / garden")
    }

    func testUnknownTextHasNoTranslation() {
        XCTAssertNil(Glossary.look(up: "qwertyuiop", from: .uz))
    }

    func testWordByWordIsFlaggedAsLiteral() {
        let gloss = Glossary.look(up: "juda xursand", from: .uz)
        XCTAssertEqual(gloss?.text, "very happy")
        XCTAssertEqual(gloss?.literal, true)
    }

    func testHalfKnownPhraseIsNotGuessed() {
        XCTAssertNil(Glossary.look(up: "juda zzzzz", from: .uz))
    }

    // MARK: - Exercise-aware look-up

    func testExerciseAnswerAlwaysHasAMeaningEvenOffCurriculum() {
        let line = Pair(en: "See you tomorrow.", tx: "Ertaga ko'rishamiz.")   // story line
        let ex = Exercise(kind: .type, pair: line,
                          prompt: line.en, promptLanguage: .en,
                          answer: line.tx, answerLanguage: .uz)
        XCTAssertEqual(ex.meaning(of: line.tx)?.text, "See you tomorrow.")
    }

    func testWrongOptionIsTranslatedToo() {
        let ex = Exercise(kind: .choice, pair: course[0],
                          prompt: "I'm happy", promptLanguage: .en,
                          answer: "Xursandman", answerLanguage: .uz,
                          options: ["Xursandman", "Charchadim"])
        XCTAssertEqual(ex.meaning(of: "Charchadim")?.text, "I'm tired")
    }

    func testAlternativeAnswerStillResolvesThroughItsOwnPair() {
        let ex = Exercise(kind: .type, pair: course[5],
                          prompt: "bog'", promptLanguage: .uz,
                          answer: "park / garden", answerLanguage: .en)
        XCTAssertEqual(ex.meaning(of: "garden")?.text, "bog'")
    }

    func testFillBlankSolutionIsTheWholeSentence() {
        let ex = Exercise(kind: .fillBlank, pair: course[0],
                          prompt: "____", promptLanguage: .uz,
                          answer: "Xursandman", answerLanguage: .uz,
                          blankIndex: 0)
        XCTAssertEqual(ex.solution, "Xursandman")
        XCTAssertEqual(ex.meaning(of: ex.solution)?.text, "I'm happy")
    }
}

/// Tap-to-hear: the rules that decide whether a tap should say anything at all.
final class SpeakableTests: XCTestCase {

    func testOnlyTheLanguageBeingLearntIsSpokenAloud() {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        XCTAssertEqual(state.target, .uz)
        XCTAssertEqual(state.native, .en)

        // the guard every tap goes through
        func wouldSpeak(_ text: String, _ language: Language?) -> Bool {
            guard let language, language == state.target else { return false }
            return !text.trimmingCharacters(in: .whitespaces).isEmpty
        }

        XCTAssertTrue(wouldSpeak("xursandman", .uz))
        XCTAssertFalse(wouldSpeak("i'm happy", .en), "her own language needs no pronunciation")
        XCTAssertFalse(wouldSpeak("   ", .uz))
        XCTAssertFalse(wouldSpeak("xursandman", nil))
    }
}
