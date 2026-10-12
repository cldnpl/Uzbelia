import XCTest
@testable import Uzbelia

/// A translation in her own words is right when it says the same thing. These are
/// the wordings that used to come back red with "mine is right too" underneath.
final class EquivalenceTests: XCTestCase {

    private func isSame(_ given: String, _ expected: String, _ language: Language,
                        prompt: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard case .same? = Equivalence.compare(given, with: expected, in: language, prompt: prompt) else {
            return XCTFail("'\(given)' should be accepted for '\(expected)'", file: file, line: line)
        }
    }

    private func isNotSame(_ given: String, _ expected: String, _ language: Language,
                           prompt: String = "", file: StaticString = #filePath, line: UInt = #line) {
        if case .same? = Equivalence.compare(given, with: expected, in: language, prompt: prompt) {
            XCTFail("'\(given)' must not be accepted for '\(expected)'", file: file, line: line)
        }
    }

    // MARK: - The two cases she reported

    func testMyDogWithoutMening() {
        isSame("itim", "Mening itim.", .uz, prompt: "My dog.")
        isSame("Itim!", "Mening itim.", .uz, prompt: "My dog.")
    }

    func testHelloIAmClaudiaWithTheLongGreetingAndNoPronoun() {
        isSame("assalomu alaykum claudiaman", "Salom, men Klaudiyaman.", .uz, prompt: "Hello, I'm Claudia.")
        isSame("Assalomu alaykum, Klaudiyaman", "Salom, men Klaudiyaman.", .uz, prompt: "Hello, I'm Claudia.")
        isSame("Salom, mening ismim Klaudiya", "Salom, men Klaudiyaman.", .uz, prompt: "Hello, I'm Claudia.")
    }

    // MARK: - Uzbek

    func testAPronounThatAgreesMayBeAddedOrLeftOut() {
        isSame("Mening itim", "Itim.", .uz)
        isSame("Men italiyalikman", "Italiyalikman.", .uz)
        isSame("Italiyalikman", "Men italiyalikman.", .uz)
        isSame("Biz do'stmiz", "Do'stmiz.", .uz)
    }

    func testAPronounThatDoesNotAgreeIsWrong() {
        isNotSame("Sening itim", "Mening itim.", .uz)
        isNotSame("Sen Klaudiyaman", "Men Klaudiyaman.", .uz)
        isNotSame("Sen italiyalikman", "Men italiyalikman.", .uz)
    }

    func testAPronounThatIsThePointStays() {
        isNotSame("ham", "Men ham.", .uz)
        isNotSame("chi?", "Sen-chi?", .uz)
        isNotSame("bilan boraman", "U bilan boraman.", .uz)
    }

    func testThatIsNotHe() {
        // "that book": u is a demonstrative and cannot go
        isNotSame("Kitob qiziq", "U kitob qiziq.", .uz, prompt: "That book is interesting.")
        isNotSame("Yerda", "U yerda.", .uz, prompt: "There.")
    }

    func testGreetingsThanksAndApologies() {
        isSame("Assalomu alaykum!", "Salom!", .uz)
        isSame("Salom!", "Assalomu alaykum!", .uz)
        isSame("assalomu aleykum", "Salom!", .uz)
        isSame("Tashakkur!", "Rahmat!", .uz)
        isSame("Uzr", "Kechirasiz!", .uz)
        // goodbye is never hello
        isNotSame("Xayr!", "Salom!", .uz, prompt: "Hello!")
    }

    func testATimeWordCanMove() {
        isSame("Ertaga men Toshkentga boraman", "Men ertaga Toshkentga boraman.", .uz)
        isNotSame("Toshkentga boraman", "Men ertaga Toshkentga boraman.", .uz)
        isNotSame("Kecha Toshkentga boraman", "Men ertaga Toshkentga boraman.", .uz)
    }

    func testNumbersInFiguresAndCountedNouns() {
        isSame("Mening 3ta kitobim bor", "Mening uchta kitobim bor.", .uz)
        isSame("Uch kitobim bor", "Mening uchta kitobim bor.", .uz)
        isSame("20 yoshdaman", "Men yigirma yoshdaman.", .uz)
        isNotSame("Ikki kitobim bor", "Mening uchta kitobim bor.", .uz)
    }

    func testSomethingElseEntirelyIsStillWrong() {
        isNotSame("xayrli tun", "Yaxshiman.", .uz)
        isNotSame("hammasi joyida", "Yaxshiman.", .uz)
        isNotSame("ertagacha", "Ertaga ko'rishguncha!", .uz)
        isNotSame("itim", "Mening mushugim.", .uz)
    }

    // MARK: - English

    func testEnglishContractions() {
        isSame("I'm Claudia", "I am Claudia.", .en)
        isSame("I am Claudia", "I'm Claudia.", .en)
        isSame("Im Claudia", "I'm Claudia.", .en)          // the apostrophe she skipped
        isSame("I don't know", "I do not know.", .en)
        isSame("She's Italian", "She is Italian.", .en)
        isSame("hi im claudia", "Hello, I'm Claudia.", .en)
        isNotSame("You're Claudia", "I'm Claudia.", .en)
        isNotSame("I'm going to Rome with him", "I'm going to Rome with her.", .en)
        isNotSame("And?", "And you?", .en)
    }

    func testEnglishSameThingOtherWords() {
        isSame("I'm Claudia", "My name is Claudia.", .en)
        isSame("Thanks!", "Thank you!", .en)
        isSame("Thanks a lot!", "Thank you very much!", .en)
        isSame("Hey!", "Hello!", .en)
        isSame("Bye!", "Goodbye!", .en)
        isSame("OK", "Okay.", .en)
        isSame("I can't swim", "I cannot swim.", .en)
        isSame("Tomorrow I'm going to Tashkent", "I'm going to Tashkent tomorrow.", .en)
        isSame("I'm 20 years old", "I'm twenty years old.", .en)
        isSame("I'm 21", "I'm twenty-one.", .en)
    }

    func testExcuseMeDependsOnWhatWasSaid() {
        // "excuse me" is "sorry" when the Uzbek was an apology…
        isSame("Excuse me!", "Sorry!", .en, prompt: "Kechirasiz!")
        isSame("Pardon me", "Sorry.", .en, prompt: "Uzr.")
        // …and not when "sorry" is "what a pity"
        isNotSame("Excuse me!", "Sorry!", .en, prompt: "Afsus!")
        isNotSame("Hi!", "Goodbye!", .en, prompt: "Xayr!")
    }

    // MARK: - Spelling on top

    func testASlipOnTopOfARightWordingIsNearlyRight() {
        guard case .nearly? = Equivalence.compare("Toshkentga boramen", with: "Men Toshkentga boraman.",
                                                  in: .uz) else {
            return XCTFail("one letter off on a long word is a spelling slip, not a wrong answer")
        }
        guard case .nearly? = Equivalence.compare("Hayrli tun", with: "Xayrli tun!", in: .uz) else {
            return XCTFail("h for x is the classic slip")
        }
    }

    func testNumberWords() {
        // "twenty-one" normalises to "twenty one", which is what the figures become
        XCTAssertEqual(Equivalence.englishNumber(21), "twenty one")
        XCTAssertEqual(Equivalence.englishNumber(15), "fifteen")
        XCTAssertEqual(Equivalence.englishNumber(40), "forty")
        XCTAssertEqual(Equivalence.englishNumber(100), "one hundred")
        XCTAssertEqual(Equivalence.englishNumber(2000), "two thousand")
        XCTAssertEqual(Equivalence.uzbekNumber(25), "yigirma besh")
        XCTAssertEqual(Equivalence.uzbekNumber(300), "uch yuz")
        XCTAssertEqual(Equivalence.uzbekNumber(1000), "ming")
    }

    // MARK: - In a lesson

    private func question(_ kind: Exercise.Kind, en: String, uz: String) -> Exercise {
        Exercise(kind: kind, pair: Pair(en: en, tx: uz),
                 prompt: en, promptLanguage: .en, answer: uz, answerLanguage: .uz,
                 tokens: kind == .wordBank ? ["itim", "mening", "uyim"] : [])
    }

    func testTheLessonMarksItRightStraightAway() {
        let ex = question(.type, en: "My dog.", uz: "Mening itim.")
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "itim"
        engine.commit(engine.grade())
        XCTAssertEqual(engine.verdict, .alternative(canonical: "Mening itim.", note: nil))
        XCTAssertTrue(engine.verdict?.isAccepted ?? false)
        XCTAssertTrue(engine.mistakePairs.isEmpty, "not a mistake, not even for a moment")
        XCTAssertEqual(engine.accuracy, 1)
        engine.advance()
        XCTAssertTrue(engine.finished, "an accepted wording does not come back")
    }

    func testTheWordBankToo() {
        let ex = question(.wordBank, en: "My dog.", uz: "Mening itim.")
        let engine = LessonEngine(exercises: [ex])
        engine.built = [0]                        // just "itim"
        XCTAssertEqual(engine.grade(), .alternative(canonical: "Mening itim.", note: nil))
    }

    func testDictationStillWantsWhatWasSaid() {
        let ex = question(.listenType, en: "My dog.", uz: "Mening itim.")
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "itim"
        guard case .wrong = engine.grade() else {
            return XCTFail("dictation is not a translation: you write what you hear")
        }
    }

    func testANameSpelledHerWayIsNotASpellingMistake() {
        let ex = question(.type, en: "I'm Claudia.", uz: "Men Klaudiyaman.")
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "Men Claudiaman"
        XCTAssertEqual(engine.grade(), .alternative(canonical: "Men Klaudiyaman.", note: nil))
    }

    func testAContractionInEnglishIsHerOwnWordingAndNotASlip() {
        // the way back, from Uzbek into English
        let ex = Exercise(kind: .type, pair: Pair(en: "I am Claudia.", tx: "Men Klaudiyaman."),
                          prompt: "Men Klaudiyaman.", promptLanguage: .uz,
                          answer: "I am Claudia.", answerLanguage: .en)
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "I'm Claudia"
        XCTAssertEqual(engine.grade(), .alternative(canonical: "I am Claudia.", note: nil))
    }
}

/// Right and wrong sound like right and wrong.
final class AnswerSoundTests: XCTestCase {

    func testBothSoundsShipWithTheApp() {
        for name in ["correct", "wrong"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "mp3"),
                            "\(name).mp3 is missing from the app bundle")
        }
    }

    func testTheVoiceWaitsForTheChimeOnlyWhenThereIsAChime() {
        let before = Feedback.soundsEnabled
        defer { Feedback.soundsEnabled = before }
        Feedback.soundsEnabled = true
        XCTAssertGreaterThan(Feedback.chimeGap, 0.3)
        Feedback.soundsEnabled = false
        XCTAssertEqual(Feedback.chimeGap, 0)
    }
}
