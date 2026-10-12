import XCTest
@testable import Uzbelia

/// Five passes over a lesson should not be the same four sentences five times.
final class DrillsTests: XCTestCase {

    private var curriculum: Curriculum!

    override func setUp() {
        super.setUp()
        curriculum = ContentStore.loadCurriculum(.uz)
        // the engines read the course's language from here; AppState sets it on load
        Language.current = .uz
    }

    // MARK: - The content

    func testEveryLessonHasItsPracticeSentences() {
        for lesson in curriculum.allLessons {
            XCTAssertGreaterThanOrEqual(lesson.drills.count, 10, "\(lesson.id) has too few practice sentences")
        }
        XCTAssertGreaterThan(curriculum.allDrills.count, 3000)
    }

    func testPracticeSentencesAreSentencesAndNotRepeats() {
        let taught = Set(curriculum.allPairs.map { Grader.normalise($0.tx) })
        var seen = Set<String>()
        for unit in curriculum.allUnits {
            var inUnit = Set<String>()
            for pair in unit.allDrills {
                let key = Grader.normalise(pair.tx)
                XCTAssertFalse(taught.contains(key), "'\(pair.tx)' is already a course item")
                XCTAssertTrue(inUnit.insert(key).inserted, "'\(pair.tx)' twice in \(unit.id)")
                XCTAssertGreaterThanOrEqual(pair.wordCount(.uz), 2, "'\(pair.tx)' is not a sentence")
                XCTAssertFalse(pair.tx.contains("\u{2019}") || pair.tx.contains("\u{02BB}"),
                               "curly apostrophe in '\(pair.tx)'")
                seen.insert(key)
            }
        }
        XCTAssertFalse(seen.isEmpty)
    }

    func testTheWordCountsAreStillTheWordsTaught() {
        // practice sentences are made of words already taught: they add no vocabulary
        XCTAssertGreaterThanOrEqual(curriculum.allPairs.count, 6000)
        XCTAssertFalse(curriculum.allPairs.contains { pair in
            curriculum.allLessons.first!.drills.contains(pair)
        })
    }

    // MARK: - The rotation

    private func lesson(drills: Int) -> Lesson {
        var l = Lesson(id: "t1", title: Bilingual(en: "Test", tx: "Sinov"))
        l.vocab = (0..<10).map { Pair(en: "word\($0)", tx: "so'z\($0)") }
        l.phrases = (0..<4).map { Pair(en: "Course sentence \($0).", tx: "Kurs jumlasi \($0).") }
        l.drills = (0..<drills).map { Pair(en: "New sentence number \($0).", tx: "Yangi jumla raqam \($0).") }
        return l
    }

    func testLaterPassesBringSentencesTheLastOneDidNot() {
        let l = lesson(drills: 24)
        var answered: [String: Int] = [:]
        let first = ExerciseFactory.rotation(words: l.vocab, sentences: l.phrases + l.drills, fresh: [],
                                             familiarity: { answered[$0.id] ?? 0 },
                                             wordCount: 6, sentenceCount: 12)
        for pair in first { answered[pair.id, default: 0] += 1 }
        let second = ExerciseFactory.rotation(words: l.vocab, sentences: l.phrases + l.drills, fresh: [],
                                              familiarity: { answered[$0.id] ?? 0 },
                                              wordCount: 6, sentenceCount: 12)
        let sentencesFirst = Set(first.filter { $0.wordCount(.uz) > 1 }.map(\.id))
        let sentencesSecond = Set(second.filter { $0.wordCount(.uz) > 1 }.map(\.id))
        XCTAssertEqual(sentencesFirst.count, 12)
        XCTAssertEqual(sentencesSecond.count, 12)
        XCTAssertTrue(sentencesFirst.isDisjoint(with: sentencesSecond),
                      "with 28 sentences to choose from, the second pass repeats none of the first")
    }

    func testTheFirstPassIsStillTheLessonItself() {
        let l = lesson(drills: 24)
        let unit = Unit(id: "tu", title: Bilingual(en: "U", tx: "U"), lessons: [l])
        let node = PathNode(kind: .lesson(l), unitID: unit.id, level: .a1, indexInUnit: 0)
        let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                              native: .en, settings: Settings(), focus: .discover)
        let drillIDs = Set(l.drills.map(\.id))
        XCTAssertFalse(session.contains { drillIDs.contains($0.pair.id) },
                       "new words are met in the course's own sentences first")
    }

    func testLaterPassesUseThePracticeSentences() {
        let l = lesson(drills: 24)
        let unit = Unit(id: "tu", title: Bilingual(en: "U", tx: "U"), lessons: [l])
        let node = PathNode(kind: .lesson(l), unitID: unit.id, level: .a1, indexInUnit: 0)
        let drillIDs = Set(l.drills.map(\.id))
        // sessions are short now, so measure the share over several of them
        var drillQuestions = 0, total = 0
        for _ in 0..<10 {
            let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                  native: .en, settings: Settings(), focus: .writing)
            drillQuestions += session.filter { drillIDs.contains($0.pair.id) }.count
            total += session.count
        }
        XCTAssertGreaterThan(Double(drillQuestions) / Double(total), 0.4,
                             "most of a later pass is made of practice sentences")
    }

    func testARealLessonOffersFarMoreThanFourSentences() {
        let pack = curriculum.levels[0]
        let unit = pack.units[0]
        let node = unit.nodes(level: pack.level, index: 0)[0]
        guard case .lesson(let l) = node.kind else { return XCTFail() }
        var sentences = Set<String>()
        var answered: [String: Int] = [:]
        for focus in [SessionFocus.listening, .writing, .speaking, .review] {
            let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                  native: .en, settings: Settings(), focus: focus,
                                                  familiarity: { answered[$0.id] ?? 0 })
            for ex in session {
                answered[ex.pair.id, default: 0] += 1
                if ex.pair.wordCount(.uz) > 1 { sentences.insert(ex.pair.id) }
            }
        }
        XCTAssertGreaterThan(sentences.count, l.phrases.count * 2,
                             "four passes should cover many more sentences than the lesson's own")
    }
}
