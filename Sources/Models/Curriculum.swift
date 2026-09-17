import Foundation

// MARK: - Languages

enum Language: String, Codable, CaseIterable, Hashable {
    case it, uz

    var endonym: String { self == .it ? "Italiano" : "O'zbekcha" }
    var nameIT: String { self == .it ? "Italiano" : "Uzbeko" }
    var nameUZ: String { self == .it ? "Italyancha" : "O'zbekcha" }
    var other: Language { self == .it ? .uz : .it }

    /// Best-effort BCP-47 locale for speech synthesis / recognition.
    var speechLocale: String { self == .it ? "it-IT" : "uz-UZ" }
    /// Ordered fallbacks when the system has no voice/recogniser for the language.
    var speechFallbacks: [String] {
        self == .it ? ["it-IT", "it-CH"] : ["uz-UZ", "tr-TR", "az-AZ", "ru-RU"]
    }
}

// MARK: - Bilingual strings

struct Bilingual: Codable, Hashable {
    let it: String
    let uz: String
    func callAsFunction(_ lang: Language) -> String { lang == .it ? it : uz }
    subscript(_ lang: Language) -> String { lang == .it ? it : uz }
}

/// One translation pair. Encoded compactly in JSON as ["italiano", "o'zbekcha"]
/// or ["italiano", "o'zbekcha", "nota facoltativa"].
struct Pair: Codable, Hashable, Identifiable {
    let it: String
    let uz: String
    let hint: String?

    var id: String { "\(it)|\(uz)" }

    init(it: String, uz: String, hint: String? = nil) {
        self.it = it; self.uz = uz; self.hint = hint
    }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        it = try c.decode(String.self)
        uz = try c.decode(String.self)
        hint = c.isAtEnd ? nil : try? c.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(it); try c.encode(uz)
        if let hint { try c.encode(hint) }
    }

    subscript(_ lang: Language) -> String { lang == .it ? it : uz }
    /// Number of words on the target side — used to pick exercise difficulty.
    func wordCount(_ lang: Language) -> Int {
        self[lang].split(whereSeparator: { $0 == " " }).count
    }
}

// MARK: - Curriculum tree

enum CEFR: String, Codable, CaseIterable, Identifiable, Comparable {
    case a1, a2, b1, b2
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var order: Int { CEFR.allCases.firstIndex(of: self)! }
    static func < (l: CEFR, r: CEFR) -> Bool { l.order < r.order }

    var blurb: Bilingual {
        switch self {
        case .a1: return Bilingual(it: "Principiante", uz: "Boshlang'ich")
        case .a2: return Bilingual(it: "Elementare", uz: "Elementar")
        case .b1: return Bilingual(it: "Intermedio", uz: "O'rta")
        case .b2: return Bilingual(it: "Intermedio superiore", uz: "Yuqori o'rta")
        }
    }
}

struct GrammarNote: Codable, Hashable, Identifiable {
    let title: Bilingual
    let body: Bilingual
    var examples: [Pair] = []
    var id: String { title.it }
}

struct DialogueLine: Codable, Hashable, Identifiable {
    let who: String
    let it: String
    let uz: String
    var id: String { "\(who)|\(it)" }
    subscript(_ lang: Language) -> String { lang == .it ? it : uz }
}

struct Dialogue: Codable, Hashable {
    let title: Bilingual
    let lines: [DialogueLine]
}

struct Lesson: Codable, Hashable, Identifiable {
    let id: String
    let title: Bilingual
    var vocab: [Pair] = []
    var phrases: [Pair] = []

    var allPairs: [Pair] { vocab + phrases }
}

struct Unit: Codable, Hashable, Identifiable {
    let id: String
    let title: Bilingual
    var subtitle: Bilingual?
    var icon: String = "book.fill"
    var accent: UnitAccent = .sky
    var grammar: [GrammarNote] = []
    var lessons: [Lesson] = []
    var dialogue: Dialogue?

    var allPairs: [Pair] { lessons.flatMap(\.allPairs) }

    /// Lessons + the story node + the unit review, in path order.
    func nodes(level: CEFR, index: Int) -> [PathNode] {
        var out: [PathNode] = lessons.enumerated().map { i, l in
            PathNode(kind: .lesson(l), unitID: id, level: level, indexInUnit: i)
        }
        if let dialogue {
            out.append(PathNode(kind: .story(dialogue), unitID: id, level: level, indexInUnit: out.count))
        }
        out.append(PathNode(kind: .review, unitID: id, level: level, indexInUnit: out.count))
        return out
    }
}

struct LevelPack: Codable, Hashable, Identifiable {
    let level: CEFR
    var units: [Unit]
    var id: String { level.rawValue }
}

// MARK: - Path nodes

struct PathNode: Hashable, Identifiable {
    enum Kind: Hashable {
        case lesson(Lesson)
        case story(Dialogue)
        case review
    }
    let kind: Kind
    let unitID: String
    let level: CEFR
    let indexInUnit: Int

    var id: String {
        switch kind {
        case .lesson(let l): return l.id
        case .story: return "\(unitID)-story"
        case .review: return "\(unitID)-review"
        }
    }

    var title: Bilingual {
        switch kind {
        case .lesson(let l): return l.title
        case .story(let d): return d.title
        case .review: return Bilingual(it: "Ripasso dell'unità", uz: "Bo'lim takrori")
        }
    }

    var icon: String {
        switch kind {
        case .lesson: return "star.fill"
        case .story: return "text.bubble.fill"
        case .review: return "crown.fill"
        }
    }

    var xpReward: Int {
        switch kind {
        case .lesson: return 15
        case .story: return 20
        case .review: return 40
        }
    }

    /// Lessons take five passes to complete, like a Duolingo skill; stories and
    /// unit reviews are one-shot.
    var requiredSessions: Int {
        switch kind {
        case .lesson: return 5
        case .story, .review: return 1
        }
    }

    /// What the n-th pass over this node trains.
    func focus(forSession index: Int) -> SessionFocus {
        switch kind {
        case .lesson: return SessionFocus.forSession(index)
        case .story: return .listening
        case .review: return .review
        }
    }

    /// The five focuses this node cycles through, for the node sheet.
    var sessionPlan: [SessionFocus] {
        (0..<requiredSessions).map { focus(forSession: $0) }
    }
}

// MARK: - Lenient decoding
// Swift does not fall back to property defaults for missing keys, and the
// curriculum JSON deliberately omits everything that has a sensible default.

extension Unit {
    enum CodingKeys: String, CodingKey { case id, title, subtitle, icon, accent, grammar, lessons, dialogue }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(Bilingual.self, forKey: .title)
        subtitle = try c.decodeIfPresent(Bilingual.self, forKey: .subtitle)
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "book.fill"
        accent = try c.decodeIfPresent(UnitAccent.self, forKey: .accent) ?? .sky
        grammar = try c.decodeIfPresent([GrammarNote].self, forKey: .grammar) ?? []
        lessons = try c.decodeIfPresent([Lesson].self, forKey: .lessons) ?? []
        dialogue = try c.decodeIfPresent(Dialogue.self, forKey: .dialogue)
    }
}

extension Lesson {
    enum CodingKeys: String, CodingKey { case id, title, vocab, phrases }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(Bilingual.self, forKey: .title)
        vocab = try c.decodeIfPresent([Pair].self, forKey: .vocab) ?? []
        phrases = try c.decodeIfPresent([Pair].self, forKey: .phrases) ?? []
    }
}

extension GrammarNote {
    enum CodingKeys: String, CodingKey { case title, body, examples }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(Bilingual.self, forKey: .title)
        body = try c.decode(Bilingual.self, forKey: .body)
        examples = try c.decodeIfPresent([Pair].self, forKey: .examples) ?? []
    }
}
