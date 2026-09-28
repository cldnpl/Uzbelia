import XCTest
@testable import Uzbelia

/// A translation in her own words is right when it says the same thing. These are
/// the wordings that used to come back red with "anche la mia è giusta" underneath.
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
        isSame("itim", "Mening itim.", .uz, prompt: "Il mio cane.")
        isSame("Itim!", "Mening itim.", .uz, prompt: "Il mio cane.")
    }

    func testHelloIAmClaudiaWithTheLongGreetingAndNoPronoun() {
        isSame("assalomu alaykum claudiaman", "Salom, men Klaudiyaman.", .uz, prompt: "Ciao, sono Claudia.")
        isSame("Assalomu alaykum, Klaudiyaman", "Salom, men Klaudiyaman.", .uz, prompt: "Ciao, sono Claudia.")
        isSame("Salom, mening ismim Klaudiya", "Salom, men Klaudiyaman.", .uz, prompt: "Ciao, sono Claudia.")
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
        // "quel libro": u is a demonstrative and cannot go
        isNotSame("Kitob qiziq", "U kitob qiziq.", .uz, prompt: "Quel libro è interessante.")
        isNotSame("Yerda", "U yerda.", .uz, prompt: "Là.")
    }

    func testGreetingsThanksAndApologies() {
        isSame("Assalomu alaykum!", "Salom!", .uz)
        isSame("Salom!", "Assalomu alaykum!", .uz)
        isSame("assalomu aleykum", "Salom!", .uz)
        isSame("Tashakkur!", "Rahmat!", .uz)
        isSame("Uzr", "Kechirasiz!", .uz)
        isSame("Xayr!", "Salom!", .uz, prompt: "Ciao!")
        isNotSame("Xayr!", "Salom!", .uz, prompt: "Buongiorno!")
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

    // MARK: - Italian

    func testItalianSubjectPronouns() {
        isSame("Sono Claudia", "Io sono Claudia.", .it)
        isSame("Io sono Claudia", "Sono Claudia.", .it)
        isSame("Lei è italiana", "È italiana.", .it)
        isSame("ciao io sono claudia", "Ciao, sono Claudia.", .it)
        isNotSame("Tu sono Claudia", "Sono Claudia.", .it)
        isNotSame("Vado a Roma con lui", "Vado a Roma con lei.", .it)
        isNotSame("E?", "E tu?", .it)
    }

    func testItalianSameThingOtherWords() {
        isSame("Ciao, mi chiamo Claudia", "Ciao, il mio nome è Claudia.", .it)
        isSame("Cos'è?", "Che cosa è?", .it)
        isSame("Abito a Roma", "Vivo a Roma.", .it)
        isSame("Per piacere", "Per favore.", .it)
        isSame("Scusi!", "Scusa!", .it)
        isSame("Domani vado a Roma", "Vado a Roma domani.", .it)
        isSame("Ho 20 anni", "Ho venti anni.", .it)
    }

    func testCiaoDependsOnWhatWasSaid() {
        isSame("Salve!", "Ciao!", .it, prompt: "Salom!")
        isSame("Ciao!", "Arrivederci!", .it, prompt: "Xayr!")
        isNotSame("Salve!", "Arrivederci!", .it, prompt: "Xayr!")
        isNotSame("Buonasera!", "Buongiorno!", .it, prompt: "Xayrli kun!")
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
        XCTAssertEqual(Equivalence.italianNumber(21), "ventuno")
        XCTAssertEqual(Equivalence.italianNumber(28), "ventotto")
        XCTAssertEqual(Equivalence.italianNumber(23), "ventitre")
        XCTAssertEqual(Equivalence.italianNumber(100), "cento")
        XCTAssertEqual(Equivalence.italianNumber(2000), "duemila")
        XCTAssertEqual(Equivalence.uzbekNumber(25), "yigirma besh")
        XCTAssertEqual(Equivalence.uzbekNumber(300), "uch yuz")
        XCTAssertEqual(Equivalence.uzbekNumber(1000), "ming")
    }

    // MARK: - In a lesson

    private func question(_ kind: Exercise.Kind, it: String, uz: String) -> Exercise {
        Exercise(kind: kind, pair: Pair(it: it, uz: uz),
                 prompt: it, promptLanguage: .it, answer: uz, answerLanguage: .uz,
                 tokens: kind == .wordBank ? ["itim", "mening", "uyim"] : [])
    }

    func testTheLessonMarksItRightStraightAway() {
        let ex = question(.type, it: "Il mio cane.", uz: "Mening itim.")
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
        let ex = question(.wordBank, it: "Il mio cane.", uz: "Mening itim.")
        let engine = LessonEngine(exercises: [ex])
        engine.built = [0]                        // just "itim"
        XCTAssertEqual(engine.grade(), .alternative(canonical: "Mening itim.", note: nil))
    }

    func testDictationStillWantsWhatWasSaid() {
        let ex = question(.listenType, it: "Il mio cane.", uz: "Mening itim.")
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "itim"
        guard case .wrong = engine.grade() else {
            return XCTFail("dictation is not a translation: you write what you hear")
        }
    }

    func testANameSpelledHerWayIsNotASpellingMistake() {
        let ex = question(.type, it: "Sono Claudia.", uz: "Men Klaudiyaman.")
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "Men Claudiaman"
        XCTAssertEqual(engine.grade(), .alternative(canonical: "Men Klaudiyaman.", note: nil))
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
