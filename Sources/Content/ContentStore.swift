import Foundation
import NaturalLanguage

struct Curriculum: Codable, Hashable {
    var levels: [LevelPack]

    static let empty = Curriculum(levels: [])

    var allUnits: [Unit] { levels.flatMap(\.units) }
    var allLessons: [Lesson] { allUnits.flatMap(\.lessons) }
    var allPairs: [Pair] { allUnits.flatMap(\.allPairs) }
    var allDrills: [Pair] { allUnits.flatMap(\.allDrills) }

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

/// Reads a course out of the bundle. Every course is a set of files named after its
/// code — `uz-a1.json`, `th-questions.json`, `fa-phrases.json` — compiled from
/// `content/courses/<code>/` by `content/build.py`.
enum ContentStore {
    static func loadCurriculum(_ course: Language) -> Curriculum {
        var packs: [LevelPack] = []
        for level in CEFR.allCases {
            guard let url = url(for: "\(course.rawValue)-\(level.rawValue)") else { continue }
            do {
                let data = try Data(contentsOf: url)
                let pack = try JSONDecoder().decode(LevelPack.self, from: data)
                packs.append(pack)
            } catch {
                assertionFailure("Curriculum \(course.rawValue)-\(level.rawValue) failed to decode: \(error)")
            }
        }
        packs.sort { $0.level < $1.level }
        return Curriculum(levels: packs)
    }

    static func loadQuestions(_ course: Language) -> QuestionBank {
        guard let url = url(for: "\(course.rawValue)-questions"),
              let data = try? Data(contentsOf: url),
              let bank = try? JSONDecoder().decode(QuestionBank.self, from: data) else {
            return .empty
        }
        return bank
    }

    static func loadPhrases(_ course: Language) -> [String: [Bilingual]] {
        guard let url = url(for: "\(course.rawValue)-phrases"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: [Bilingual]].self, from: data) else {
            return [:]
        }
        return table
    }

    /// True when the bundle carries a course's A1 at least.
    static func hasCourse(_ course: Language) -> Bool {
        url(for: "\(course.rawValue)-a1") != nil
    }

    private static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "json")
            ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Curriculum")
    }
}

/// The lines the app itself says in the course's language — Anorcha's reactions on a
/// call, the way she opens and keeps a chat going offline. They live in the course's
/// `phrases.json`, so a new course never needs a line of Swift to speak.
enum Phrases {
    /// Set by `AppState` whenever a course is loaded.
    static var table: [String: [Bilingual]] = [:]

    static func list(_ key: String) -> [Bilingual] { table[key] ?? [] }
    static func any(_ key: String) -> Bilingual? { table[key]?.randomElement() }
}

/// How each line of a course in another script sounds, in Latin letters — looked
/// up by the line itself, so any screen showing a Thai or Persian string can put its
/// romanisation under it without knowing which pair it came from.
enum Romanisation {
    static var table: [String: String] = [:]

    static func of(_ text: String) -> String? {
        guard !table.isEmpty else { return nil }
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return table[key] ?? table[Grader.withoutAnnotations(key)]
    }

    /// Rebuilt by `AppState` whenever it loads a course.
    static func index(_ curriculum: Curriculum) {
        var out: [String: String] = [:]
        func add(_ tx: String, _ rom: String?) {
            guard let rom, !rom.isEmpty else { return }
            out[tx.trimmingCharacters(in: .whitespacesAndNewlines)] = rom
        }
        for unit in curriculum.allUnits {
            for pair in unit.allPairs + unit.allDrills + unit.grammar.flatMap(\.examples) {
                add(pair.tx, pair.rom)
            }
            for line in unit.dialogue?.lines ?? [] { add(line.tx, line.rom) }
        }
        table = out
    }
}

/// Where the words are in a line of text.
///
/// Most courses put spaces between words; Thai, Lao, Khmer and Cantonese do not, so
/// their words come from Apple's tokenizer, which knows where those words end. Everything that cuts a line
/// into tiles, glosses a tapped word or counts words goes through here.
enum WordSplitter {
    static func words(in text: String, language: Language) -> [String] {
        guard language.isUnspaced else {
            return text.split(whereSeparator: { $0 == " " }).map(String.init)
        }
        var out: [String] = []
        // a space in these scripts is a phrase break: keep it as one, and cut each phrase up
        for chunk in text.split(separator: " ") {
            let piece = String(chunk)
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.setLanguage(language.tokenizerLanguage)
            tokenizer.string = piece
            var last = piece.startIndex
            tokenizer.enumerateTokens(in: piece.startIndex..<piece.endIndex) { range, _ in
                // punctuation between tokens stays glued to the word before it
                if range.lowerBound > last, !out.isEmpty {
                    out[out.count - 1] += piece[last..<range.lowerBound]
                }
                out.append(String(piece[range]))
                last = range.upperBound
                return true
            }
            if last < piece.endIndex {
                if out.isEmpty { out.append(String(piece[last...])) }
                else { out[out.count - 1] += piece[last...] }
            }
        }
        return out
    }

    /// Joins words back into a line: with spaces, or without for the unspaced scripts.
    static func join(_ words: [String], language: Language) -> String {
        words.joined(separator: language.isUnspaced ? "" : " ")
    }
}

private extension Language {
    var tokenizerLanguage: NLLanguage {
        switch self {
        case .lo: return .lao
        case .km: return .khmer
        case .yue: return .traditionalChinese
        default: return .thai
        }
    }
}
