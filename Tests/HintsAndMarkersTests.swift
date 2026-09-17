import XCTest
@testable import Uzbelia

/// Tapping a word to see what it means, in either language.
final class WordHintTests: XCTestCase {

    private let course = [
        Pair(it: "A domani!", uz: "Ertaga ko'rishguncha!"),   // an expression, taught whole
        Pair(it: "domani", uz: "ertaga"),
        Pair(it: "sera", uz: "kech"),
        Pair(it: "Il film è finito tardi.", uz: "Kino kech tugadi."),
        Pair(it: "film", uz: "kino")
    ]

    override func setUp() {
        super.setUp()
        Glossary.prime(with: course)
    }

    func testAWordInsideASentenceHasItsOwnMeaning() {
        XCTAssertEqual(Glossary.look(up: "kech", from: .uz)?.text, "sera")
        XCTAssertEqual(Glossary.look(up: "kino", from: .uz)?.text, "film")
    }

    func testItWorksInBothLanguages() {
        // she taps an Uzbek word, he taps an Italian one
        XCTAssertEqual(Glossary.look(up: "ertaga", from: .uz)?.text, "domani")
        XCTAssertEqual(Glossary.look(up: "domani", from: .it)?.text, "ertaga")
        XCTAssertEqual(Glossary.look(up: "film", from: .it)?.text, "kino")
    }

    func testAnExpressionTheCourseTeachesWholeIsRecognisedAsSuch() {
        // word by word "ertaga ko'rishguncha" is nothing like "a domani"
        let whole = Glossary.look(up: "Ertaga ko'rishguncha!", from: .uz)
        XCTAssertEqual(whole?.text, "A domani!")
        XCTAssertEqual(whole?.literal, false, "it is an entry of its own, not a sum of words")
    }

    func testAnOrdinarySentenceIsNotPassedOffAsAnExpression() {
        // a line the course does not list must never produce an expression card:
        // the card is only ever shown for a non-literal hit
        let madeUp = Glossary.look(up: "kech kino", from: .uz)
        XCTAssertEqual(madeUp?.literal, true, "word by word, and flagged as such")

        let taught = Glossary.look(up: "Kino kech tugadi.", from: .uz)
        XCTAssertEqual(taught?.literal, false, "this one the course really does teach")
        XCTAssertEqual(taught?.text, "Il film è finito tardi.")
    }

    func testTappingSomethingTheCourseNeverTaughtOpensNothing() {
        XCTAssertNil(Glossary.look(up: "qwertyuiop", from: .uz))
        let empty = WordHint(word: "qwertyuiop", meaning: nil, phrase: nil, phraseMeaning: nil)
        XCTAssertTrue(empty.isEmpty)
    }

    func testAHintWithEitherHalfIsWorthShowing() {
        XCTAssertFalse(WordHint(word: "kech", meaning: "sera").isEmpty)
        XCTAssertFalse(WordHint(word: "x", meaning: nil, phrase: "y", phraseMeaning: "z").isEmpty)
    }

    func testHintsCanBeTurnedOffAndTheSettingSurvivesARoundTrip() throws {
        var settings = Settings()
        XCTAssertTrue(settings.wordHints, "on by default")
        settings.wordHints = false
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        XCTAssertFalse(back.wordHints)
    }

    func testAnOlderSaveWithoutTheSettingKeepsHintsOn() throws {
        let legacy = #"{"sounds":true,"speakingExercises":true}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(legacy.utf8))
        XCTAssertTrue(settings.wordHints)
    }
}

/// A word met for the first time, and a word met again after getting it wrong.
final class NewAndMistakeMarkerTests: XCTestCase {

    private let pair = Pair(it: "grazie", uz: "rahmat")

    private func learner() -> AppState {
        let s = AppState(persistent: false)
        s.chooseCourse(native: .it)
        return s
    }

    func testAWordIsNewUntilItHasBeenAnswered() {
        let state = learner()
        XCTAssertTrue(state.isNew(pair))
        state.gradePair(pair, correct: true)
        XCTAssertFalse(state.isNew(pair), "she has met it now")
    }

    func testGettingItWrongAlsoStopsItBeingNew() {
        let state = learner()
        state.gradePair(pair, correct: false)
        XCTAssertFalse(state.isNew(pair))
    }

    func testAMissIsRememberedAsAPastMistakeAcrossSessions() {
        let state = learner()
        XCTAssertFalse(state.isPastMistake(pair))
        state.finishSession(nodeID: "a1u1l1", xpEarned: 10, accuracy: 0.5,
                            minutes: 2, mistakes: [pair])
        XCTAssertTrue(state.isPastMistake(pair))
    }

    func testAMissedQuestionComesBackMarkedAsARetry() {
        let ex = Exercise(kind: .type, pair: pair, prompt: "grazie", promptLanguage: .it,
                          answer: "rahmat", answerLanguage: .uz)
        let engine = LessonEngine(exercises: [ex])
        XCTAssertFalse(ex.isRetry)

        engine.typed = "xayrli tun"
        engine.commit(engine.grade())
        engine.advance()

        XCTAssertEqual(engine.exercises.count, 2, "it is asked again before the lesson ends")
        XCTAssertTrue(engine.exercises[1].isRetry, "and it says why it is back")
        XCTAssertEqual(engine.exercises[1].pair, pair)
    }

    func testAnAnsweredQuestionDoesNotComeBack() {
        let ex = Exercise(kind: .type, pair: pair, prompt: "grazie", promptLanguage: .it,
                          answer: "rahmat", answerLanguage: .uz)
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "rahmat"
        engine.commit(engine.grade())
        engine.advance()
        XCTAssertEqual(engine.exercises.count, 1)
        XCTAssertTrue(engine.finished)
    }

    func testAWordingSheTalkedTheAppIntoAcceptingIsNotAMistakeEither() {
        let ex = Exercise(kind: .type, pair: pair, prompt: "grazie", promptLanguage: .it,
                          answer: "rahmat", answerLanguage: .uz)
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "tashakkur"
        engine.commit(engine.grade())
        engine.acceptAnswerAnyway()
        engine.advance()
        XCTAssertEqual(engine.exercises.count, 1, "an accepted answer is not repeated")
    }
}
