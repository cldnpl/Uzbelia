import XCTest
@testable import Uzbelia

/// Checks the answer grader and the spaced-repetition scheduler.
final class GraderTests: XCTestCase {

    func testUzbekApostrophesAreEquivalent() {
        XCTAssertEqual(Grader.grade("o'zbek", expected: "oʻzbek"), .correct)
        XCTAssertEqual(Grader.grade("O‘ZBEK", expected: "o'zbek"), .correct)
    }

    func testPunctuationAndCaseIgnored() {
        XCTAssertEqual(Grader.grade("salom, qalaysan", expected: "Salom, qalaysan?"), .correct)
        XCTAssertEqual(Grader.grade("  Sto   bene grazie ", expected: "Sto bene, grazie."), .correct)
    }

    func testItalianAccentsForgiven() {
        XCTAssertEqual(Grader.grade("perche", expected: "perché"), .correct)
        XCTAssertEqual(Grader.grade("e tu?", expected: "È tu?"), .correct)
    }

    func testSmallTypoIsAlmost() {
        if case .almost = Grader.grade("rahmet", expected: "rahmat") {} else {
            XCTFail("a one-letter slip should be accepted with a correction")
        }
        if case .almost = Grader.grade("ozbek", expected: "o'zbek") {} else {
            XCTFail("a missing apostrophe should be accepted with a correction")
        }
    }

    func testShortWordsAreNotForgiven() {
        if case .wrong = Grader.grade("ha", expected: "yo'q") {} else {
            XCTFail("different short words must be wrong")
        }
    }

    func testEmptyAnswerIsWrong() {
        if case .wrong = Grader.grade("   ", expected: "salom") {} else { XCTFail() }
    }

    func testAlternativesAccepted() {
        XCTAssertEqual(Grader.grade("ciao", expected: "ciao / salve"), .correct)
        XCTAssertEqual(Grader.grade("salve", expected: "ciao / salve"), .correct)
    }

    func testPronunciationScore() {
        XCTAssertEqual(Grader.pronunciationScore(transcript: "salom qalaysan",
                                                 expected: "Salom, qalaysan?"), 1, accuracy: 0.001)
        XCTAssertEqual(Grader.pronunciationScore(transcript: "salom",
                                                 expected: "Salom, qalaysan?"), 0.5, accuracy: 0.001)
        XCTAssertEqual(Grader.pronunciationScore(transcript: "", expected: "salom"), 0, accuracy: 0.001)
    }
}

final class SRSTests: XCTestCase {

    func testStrengthGrowsWithCorrectAnswers() {
        var item = SRSItem(pairID: "x")
        for _ in 0..<6 { item.grade(correct: true) }
        XCTAssertGreaterThanOrEqual(item.strength, 0.9)
        XCTAssertGreaterThan(item.due, .now)
    }

    func testLapseDropsStrengthAndBringsItemForward() {
        var item = SRSItem(pairID: "x")
        for _ in 0..<4 { item.grade(correct: true) }
        let strong = item.strength
        let dueWhenStrong = item.due
        item.grade(correct: false)
        XCTAssertLessThan(item.strength, strong)
        XCTAssertLessThan(item.due, dueWhenStrong)
        XCTAssertEqual(item.lapses, 1)
    }

    func testStrengthStaysInRange() {
        var item = SRSItem(pairID: "x")
        for i in 0..<40 { item.grade(correct: i % 3 != 0) }
        XCTAssertTrue((0...1).contains(item.strength))
    }
}
