import XCTest
@testable import Uzbelia

/// Checks the bundled course content itself.
final class CurriculumTests: XCTestCase {

    private var curriculum: Curriculum!

    override func setUp() {
        super.setUp()
        curriculum = ContentStore.loadCurriculum()
    }

    func testAllFourLevelsLoad() {
        XCTAssertEqual(curriculum.levels.map(\.level), [.a1, .a2, .b1, .b2])
        for pack in curriculum.levels {
            XCTAssertFalse(pack.units.isEmpty, "\(pack.level.label) has no units")
        }
    }

    func testCourseSize() {
        XCTAssertEqual(curriculum.allUnits.count, 32)
        XCTAssertGreaterThanOrEqual(curriculum.allLessons.count, 300)
        XCTAssertGreaterThanOrEqual(curriculum.allPairs.count, 6000)
    }

    /// The whole point of the course: hit the CEFR vocabulary bands.
    func testVocabularyMeetsTheCEFRBands() {
        let bands: [CEFR: ClosedRange<Int>] = [
            .a1: 500...1000, .a2: 1000...2000, .b1: 2000...5000, .b2: 4000...8000,
        ]
        var known = Set<String>()
        for pack in curriculum.levels {
            for unit in pack.units {
                for lesson in unit.lessons {
                    for word in lesson.vocab { known.insert(Grader.normalise(word.uz)) }
                }
            }
            let band = bands[pack.level]!
            XCTAssertTrue(band.contains(known.count),
                          "by the end of \(pack.level.label) the learner knows \(known.count) words, "
                          + "outside the CEFR band \(band.lowerBound)-\(band.upperBound)")
        }
    }

    func testEveryUnitCarriesEnoughVocabulary() {
        for pack in curriculum.levels {
            for unit in pack.units {
                let words = unit.lessons.reduce(0) { $0 + $1.vocab.count }
                XCTAssertGreaterThanOrEqual(words, 60, "\(unit.id) teaches only \(words) words")
            }
        }
    }

    func testIdentifiersAreUnique() {
        var seen = Set<String>()
        for unit in curriculum.allUnits {
            XCTAssertTrue(seen.insert(unit.id).inserted, "duplicate unit id \(unit.id)")
            for lesson in unit.lessons {
                XCTAssertTrue(seen.insert(lesson.id).inserted, "duplicate lesson id \(lesson.id)")
            }
        }
    }

    func testEveryUnitIsTeachable() {
        for unit in curriculum.allUnits {
            XCTAssertFalse(unit.lessons.isEmpty, "\(unit.id) has no lessons")
            XCTAssertFalse(unit.grammar.isEmpty, "\(unit.id) has no grammar notes")
            XCTAssertNotNil(unit.dialogue, "\(unit.id) has no story dialogue")
            XCTAssertFalse(unit.title.it.isEmpty)
            XCTAssertFalse(unit.title.uz.isEmpty)
            for lesson in unit.lessons {
                XCTAssertGreaterThanOrEqual(lesson.vocab.count, 6, "\(lesson.id) too few words")
                XCTAssertGreaterThanOrEqual(lesson.phrases.count, 2, "\(lesson.id) too few phrases")
            }
        }
    }

    func testNoEmptyOrCyrillicText() {
        let cyrillic = CharacterSet(charactersIn: Unicode.Scalar(0x0400)!...Unicode.Scalar(0x04FF)!)
        for pair in curriculum.allPairs {
            XCTAssertFalse(pair.it.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertFalse(pair.uz.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertNil(pair.uz.rangeOfCharacter(from: cyrillic),
                         "cyrillic leaked into '\(pair.uz)'")
            XCTAssertFalse(pair.uz.contains("\u{2018}") || pair.uz.contains("\u{2019}"),
                           "curly apostrophe in '\(pair.uz)' — use a straight one")
        }
    }

    func testDialoguesAlternateAndAreComplete() {
        for unit in curriculum.allUnits {
            guard let d = unit.dialogue else { continue }
            XCTAssertGreaterThanOrEqual(d.lines.count, 5, "\(unit.id) dialogue too short")
            for line in d.lines {
                XCTAssertFalse(line.who.isEmpty)
                XCTAssertFalse(line.it.isEmpty)
                XCTAssertFalse(line.uz.isEmpty)
            }
        }
    }

    func testPathNodeCountPerLevel() {
        for pack in curriculum.levels {
            let nodes = pack.units.enumerated().flatMap { i, u in u.nodes(level: pack.level, index: i) }
            // every lesson, plus one story and one review per unit
            let expected = pack.units.reduce(0) { $0 + $1.lessons.count + 2 }
            XCTAssertEqual(nodes.count, expected, "\(pack.level.label) node count")
            XCTAssertEqual(Set(nodes.map(\.id)).count, nodes.count, "duplicate node ids")
        }
    }

    func testTheCourseIsLongEnoughToReachB2() {
        let nodes = curriculum.levels.flatMap { pack in
            pack.units.flatMap { $0.nodes(level: pack.level, index: 0) }
        }
        let sessions = nodes.reduce(0) { $0 + $1.requiredSessions }
        XCTAssertGreaterThan(nodes.count, 350)
        XCTAssertGreaterThan(sessions, 1500, "A1→B2 should be well over a thousand sessions")
    }
}
