import XCTest
@testable import Uzbelia

/// The feedback banner leans on these: whatever the learner picks, types or says
/// has to come back with a translation.
final class GlossaryTests: XCTestCase {

    private let course = [
        Pair(it: "Sono felice", uz: "Xursandman"),
        Pair(it: "Sono stanco", uz: "Charchadim"),
        Pair(it: "felice", uz: "xursand"),
        Pair(it: "molto", uz: "juda"),
        Pair(it: "acqua", uz: "suv"),
        Pair(it: "parco / giardino", uz: "bog'")
    ]

    override func setUp() {
        super.setUp()
        Glossary.prime(with: course)
        Glossary.learn(course)      // priming twice must stay harmless
    }

    func testPhraseTranslatesBothWays() {
        XCTAssertEqual(Glossary.look(up: "Xursandman", from: .uz)?.text, "Sono felice")
        XCTAssertEqual(Glossary.look(up: "Sono stanco", from: .it)?.text, "Charchadim")
    }

    func testLookUpIgnoresCaseApostrophesAndPunctuation() {
        XCTAssertEqual(Glossary.look(up: "  xursandman! ", from: .uz)?.text, "Sono felice")
        XCTAssertEqual(Glossary.look(up: "BOGʻ.", from: .uz)?.text, "parco / giardino")
    }

    func testUnknownTextHasNoTranslation() {
        XCTAssertNil(Glossary.look(up: "qwertyuiop", from: .uz))
    }

    func testWordByWordIsFlaggedAsLiteral() {
        let gloss = Glossary.look(up: "juda xursand", from: .uz)
        XCTAssertEqual(gloss?.text, "molto felice")
        XCTAssertEqual(gloss?.literal, true)
    }

    func testHalfKnownPhraseIsNotGuessed() {
        XCTAssertNil(Glossary.look(up: "juda zzzzz", from: .uz))
    }

    // MARK: - Exercise-aware look-up

    func testExerciseAnswerAlwaysHasAMeaningEvenOffCurriculum() {
        let line = Pair(it: "Ci vediamo domani", uz: "Ertaga ko'rishamiz")   // story line
        let ex = Exercise(kind: .type, pair: line,
                          prompt: line.it, promptLanguage: .it,
                          answer: line.uz, answerLanguage: .uz)
        XCTAssertEqual(ex.meaning(of: line.uz)?.text, "Ci vediamo domani")
    }

    func testWrongOptionIsTranslatedToo() {
        let ex = Exercise(kind: .choice, pair: course[0],
                          prompt: "Sono felice", promptLanguage: .it,
                          answer: "Xursandman", answerLanguage: .uz,
                          options: ["Xursandman", "Charchadim"])
        XCTAssertEqual(ex.meaning(of: "Charchadim")?.text, "Sono stanco")
    }

    func testAlternativeAnswerStillResolvesThroughItsOwnPair() {
        let ex = Exercise(kind: .type, pair: course[5],
                          prompt: "bog'", promptLanguage: .uz,
                          answer: "parco / giardino", answerLanguage: .it)
        XCTAssertEqual(ex.meaning(of: "giardino")?.text, "bog'")
    }

    func testFillBlankSolutionIsTheWholeSentence() {
        let ex = Exercise(kind: .fillBlank, pair: course[0],
                          prompt: "____", promptLanguage: .uz,
                          answer: "Xursandman", answerLanguage: .uz,
                          blankIndex: 0)
        XCTAssertEqual(ex.solution, "Xursandman")
        XCTAssertEqual(ex.meaning(of: ex.solution)?.text, "Sono felice")
    }
}
