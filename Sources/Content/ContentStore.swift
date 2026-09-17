import Foundation

struct Curriculum: Codable, Hashable {
    var levels: [LevelPack]

    static let empty = Curriculum(levels: [])

    var allUnits: [Unit] { levels.flatMap(\.units) }
    var allLessons: [Lesson] { allUnits.flatMap(\.lessons) }
    var allPairs: [Pair] { allUnits.flatMap(\.allPairs) }

    func level(of unitID: String) -> CEFR? {
        levels.first { $0.units.contains { $0.id == unitID } }?.level
    }
    func unit(id: String) -> Unit? { allUnits.first { $0.id == id } }
    func lesson(id: String) -> Lesson? { allLessons.first { $0.id == id } }

    /// The pool distractors are drawn from: everything introduced at or before the
    /// given unit, capped to the most recent `limit` items.
    ///
    /// The cap keeps session building fast on a six-thousand-pair course and makes
    /// the wrong answers more plausible, since they come from nearby material.
    func pairsUpTo(unitID: String, limit: Int = 1200) -> [Pair] {
        var out: [Pair] = []
        for pack in levels {
            for u in pack.units {
                out.append(contentsOf: u.allPairs)
                if u.id == unitID {
                    return out.count > limit ? Array(out.suffix(limit)) : out
                }
            }
        }
        return out.count > limit ? Array(out.suffix(limit)) : out
    }
}

enum ContentStore {
    static func loadCurriculum() -> Curriculum {
        var packs: [LevelPack] = []
        for level in CEFR.allCases {
            guard let url = url(for: level.rawValue) else {
                assertionFailure("Missing curriculum file for \(level.rawValue)")
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                let pack = try JSONDecoder().decode(LevelPack.self, from: data)
                packs.append(pack)
            } catch {
                assertionFailure("Curriculum \(level.rawValue) failed to decode: \(error)")
            }
        }
        packs.sort { $0.level < $1.level }
        return Curriculum(levels: packs)
    }

    static func loadQuestions() -> QuestionBank {
        guard let url = url(for: "questions"),
              let data = try? Data(contentsOf: url),
              let bank = try? JSONDecoder().decode(QuestionBank.self, from: data) else {
            assertionFailure("Call questions failed to load")
            return .empty
        }
        return bank
    }

    private static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "json")
            ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Curriculum")
    }
}
