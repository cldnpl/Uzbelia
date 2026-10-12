import XCTest
@testable import Uzbelia

/// The short text: a brief built from the course's own sentences, and a checker that
/// points at mistakes without calling her own wording one.
final class CompositionTests: XCTestCase {

    private var curriculum: Curriculum!

    override func setUp() {
        super.setUp()
        curriculum = ContentStore.loadCurriculum(.uz)
        // the engines read the course's language from here; AppState sets it on load
        Language.current = .uz
    }

    private let outline = [
        Pair(en: "My name is Aziz.", tx: "Mening ismim Aziz."),
        Pair(en: "I'm from Samarkand.", tx: "Men Samarqanddanman."),
    ]

    private func task(_ outline: [Pair]? = nil, level: CEFR = .a2) -> CompositionTask {
        let points = outline ?? self.outline
        return CompositionTask(outline: points, starter: "Mening", wordBank: ["ismim"],
                               minimumWords: 3, invitesOwnSentence: true, level: level, native: .en)
    }

    // MARK: - The brief

    func testABriefIsBuiltFromTheLessonsOwnSentences() {
        let lesson = curriculum.allLessons[3]
        let sentences = lesson.phrases + lesson.drills
        guard let brief = CompositionPlanner.task(sentences: sentences, native: .en, level: .a1) else {
            return XCTFail("a real lesson has enough sentences for a text")
        }
        XCTAssertEqual(brief.outline.count, CompositionPlanner.pointCount(for: .a1))
        let known = Set(sentences.map(\.id))
        XCTAssertTrue(brief.outline.allSatisfy { known.contains($0.id) },
                      "every thing to say comes from the course: the words are already studied")
        XCTAssertEqual(brief.target, .uz)
        XCTAssertTrue(brief.outline[0].tx.hasPrefix(brief.starter))
        XCTAssertLessThan(Grader.tokenize(brief.starter).count, Grader.tokenize(brief.outline[0].tx).count,
                          "the start is a start, not the whole first sentence")
        XCTAssertFalse(brief.wordBank.isEmpty)
        XCTAssertFalse(brief.wordBank.contains { $0.hasSuffix(",") || $0.hasSuffix(".") })
    }

    func testNoBriefWithoutRealSentences() {
        let words = (0..<10).map { Pair(en: "word\($0)", tx: "so'z\($0)") }
        XCTAssertNil(CompositionPlanner.task(sentences: words, native: .en, level: .a1))
    }

    // MARK: - The checker

    func testTheModelTextIsClean() {
        let report = CompositionChecker.check("Mening ismim Aziz. Men Samarqanddanman.",
                                              task: task(), curriculum: curriculum)
        XCTAssertTrue(report.isClean, "\(report.issues.map(\.kind))")
    }

    func testPunctuationAndCaseDoNotMatter() {
        let report = CompositionChecker.check("mening ismim aziz men samarqanddanman",
                                              task: task(), curriculum: curriculum)
        XCTAssertTrue(report.isClean, "\(report.issues.map(\.kind))")
    }

    func testHerOwnWordingIsNotAMistake() {
        // the possessive and the pronoun are carried by the endings: leaving them out
        // says the same thing
        let report = CompositionChecker.check("Ismim Aziz. Samarqanddanman.",
                                              task: task(), curriculum: curriculum)
        XCTAssertTrue(report.isClean, "\(report.issues.map { ($0.kind, $0.fragment, $0.fix) })")
    }

    func testAMisspeltWordIsPointedAt() {
        let text = "Mening ismin Aziz. Men Samarqanddanman."
        let report = CompositionChecker.check(text, task: task(), curriculum: curriculum)
        XCTAssertEqual(report.issues.count, 1)
        let issue = report.issues[0]
        XCTAssertEqual(issue.kind, .spelling)
        XCTAssertEqual(issue.fragment, "ismin")
        XCTAssertEqual(issue.fix, "ismim")
        XCTAssertEqual(issue.range.map { String(text[$0]) }, "ismin", "the mark sits on the word itself")
    }

    func testAMissingSentenceIsAMissingPart() {
        let report = CompositionChecker.check("Mening ismim Aziz.", task: task(), curriculum: curriculum)
        XCTAssertEqual(report.issues.map(\.kind), [.missingPart])
        XCTAssertEqual(report.issues[0].point, "I'm from Samarkand.")
        XCTAssertEqual(report.issues[0].fix, "Men Samarqanddanman.")
    }

    func testAMissingWordSaysWhere() {
        let points = [Pair(en: "I have a big dog.", tx: "Mening katta itim bor."),
                      Pair(en: "His name is Bobik.", tx: "Uning ismi Bobik.")]
        let report = CompositionChecker.check("Mening itim bor. Uning ismi Bobik.",
                                              task: task(points), curriculum: curriculum)
        let missing = report.issues.first { $0.kind == .missingWord }
        XCTAssertEqual(missing?.fix, "katta")
        XCTAssertEqual(missing?.anchor, "Mening")
        XCTAssertNotNil(missing?.insertAt)
    }

    func testTheRightWordsInTheWrongOrder() {
        let points = [Pair(en: "Today I work at home.", tx: "Bugun uyda ishlayman."),
                      Pair(en: "Tomorrow I'm going to the market.", tx: "Ertaga bozorga boraman.")]
        let report = CompositionChecker.check("Uyda bugun ishlayman. Ertaga bozorga boraman.",
                                              task: task(points), curriculum: curriculum)
        // a time word moving is fine for Equivalence; a verb moving is not
        let shuffled = CompositionChecker.check("Bugun ishlayman uyda. Ertaga bozorga boraman.",
                                                task: task(points), curriculum: curriculum)
        XCTAssertTrue(report.isClean || report.issues.allSatisfy { $0.kind == .order })
        XCTAssertEqual(shuffled.issues.map(\.kind), [.order])
    }

    func testASentenceOfHerOwnIsWelcome() {
        let report = CompositionChecker.check("Mening ismim Aziz. Men Samarqanddanman. Men talabaman.",
                                              task: task(), curriculum: curriculum)
        XCTAssertFalse(report.issues.contains { $0.kind == .extraWord },
                       "an extra sentence of her own is not a list of extra words")
    }

    func testANameSpelledHerWayIsNotAMistake() {
        // the same rule a translation follows: Samarqand is a name, and a learner may
        // spell a name the way she hears it
        let report = CompositionChecker.check("Mening ismim Aziz. Men Samarqandanman.",
                                              task: task(), curriculum: curriculum)
        XCTAssertTrue(report.isClean, "\(report.issues.map { ($0.kind, $0.fragment) })")
    }

    func testTheCorrectedTextKeepsWhatWasRight() {
        let points = [Pair(en: "My name is Aziz.", tx: "Mening ismim Aziz."),
                      Pair(en: "I'm a student.", tx: "Men talabaman.")]
        let report = CompositionChecker.check("Ismim Aziz. Men talabamn.",
                                              task: task(points), curriculum: curriculum)
        XCTAssertFalse(report.isClean)
        XCTAssertEqual(report.issues.map(\.kind), [.spelling])
        XCTAssertTrue(report.corrected.contains("Ismim Aziz"), report.corrected)
        XCTAssertTrue(report.corrected.contains("Men talabaman"), report.corrected)
    }

    // MARK: - The clues

    func testTheCluesGetMorePreciseEachRound() {
        let issue = CompositionIssue(kind: .spelling, fragment: "ismin", fix: "ismim")
        let first = issue.hint(round: 1, native: .en)
        let second = issue.hint(round: 2, native: .en)
        let third = issue.hint(round: 3, native: .en)
        XCTAssertFalse(first.contains("ismim"), "the first clue never gives the answer")
        XCTAssertTrue(second.contains("i…"), "the second gives the opening letters")
        XCTAssertTrue(third.contains("ismim"), "the third shows the fix")
        XCTAssertTrue(issue.hint(round: 1, native: .en, revealed: true).contains("ismim"))
    }

    // MARK: - In a lesson

    func testARoundWithMistakesIsNotAVerdict() {
        let ex = ExerciseFactory.compose(task())
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "Mening ismin Aziz."
        XCTAssertTrue(engine.canCheck)
        let report = CompositionChecker.check(engine.typed, task: task(), curriculum: curriculum)
        XCTAssertFalse(engine.recordComposeRound(report))
        XCTAssertNil(engine.verdict)
        XCTAssertFalse(engine.canCheck, "the same text cannot be checked twice")
        engine.typed = "Mening ismim Aziz. Men Samarqanddanman."
        XCTAssertTrue(engine.canCheck)
        let clean = CompositionChecker.check(engine.typed, task: task(), curriculum: curriculum)
        XCTAssertTrue(engine.recordComposeRound(clean))
        guard case .almost = engine.grade() else {
            return XCTFail("clean after a clue is right, with help")
        }
    }

    func testCleanAtTheFirstCheckIsRight() {
        let engine = LessonEngine(exercises: [ExerciseFactory.compose(task())])
        engine.typed = "Mening ismim Aziz. Men Samarqanddanman."
        engine.recordComposeRound(CompositionChecker.check(engine.typed, task: task(), curriculum: curriculum))
        XCTAssertEqual(engine.grade(), .correct)
    }

    func testARevealedTextIsNeverAskedAgain() {
        let engine = LessonEngine(exercises: [ExerciseFactory.compose(task())])
        engine.typed = "Mening"
        engine.recordComposeRound(CompositionChecker.check(engine.typed, task: task(), curriculum: curriculum))
        engine.revealComposition()
        engine.commit(engine.grade())
        guard case .wrong = engine.verdict else { return XCTFail() }
        engine.advance()
        XCTAssertTrue(engine.finished, "a text she asked to see corrected does not come round again")
        XCTAssertEqual(engine.progress, 1)
    }
}
