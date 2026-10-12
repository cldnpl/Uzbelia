import Foundation

// MARK: - Languages

/// Every language the app knows. English is the interface and the language every
/// course is taught from; each of the others is a course.
///
/// Adding a course is adding a case here, its metadata below, and a content folder
/// in `content/courses/<rawValue>/` — the app picks the rest up from the bundle.
enum Language: String, Codable, CaseIterable, Hashable, Identifiable {
    case en
    case uz, th, fa, tl, ms
    case yue, pa, ta, te, ml, kn, kmr, ckb, mn, km, lo, kk, ky, az, ka, hy, ur, bn

    var id: String { rawValue }

    /// The courses, in the order the picker shows them.
    static let courses: [Language] = [
        .th, .fa, .tl, .ms, .yue, .pa, .ta, .te, .ml, .kn, .kmr, .ckb,
        .mn, .km, .lo, .kk, .ky, .az, .ka, .hy, .ur, .bn, .uz,
    ]

    private struct Info {
        let name: String
        let endonym: String
        /// Emoji flag; empty when there is none (Kurdish), and `FlagOrb` draws one.
        let flag: String
        let script: Script
        /// BCP-47 locale for voices and recognisers.
        let locale: String
        /// Edge/Azure neural voices, a woman's and a man's; nil when no service has one.
        let voices: (female: String, male: String)?
    }

    private var info: Info {
        switch self {
        case .en:  return Info(name: "English", endonym: "English", flag: "🇺🇸", script: .latin, locale: "en-US", voices: ("en-US-AvaNeural", "en-US-AndrewNeural"))
        case .uz:  return Info(name: "Uzbek", endonym: "O'zbekcha", flag: "🇺🇿", script: .latin, locale: "uz-UZ", voices: ("uz-UZ-MadinaNeural", "uz-UZ-SardorNeural"))
        case .th:  return Info(name: "Thai", endonym: "ภาษาไทย", flag: "🇹🇭", script: .thai, locale: "th-TH", voices: ("th-TH-PremwadeeNeural", "th-TH-NiwatNeural"))
        case .fa:  return Info(name: "Persian", endonym: "فارسی", flag: "🇮🇷", script: .arabic, locale: "fa-IR", voices: ("fa-IR-DilaraNeural", "fa-IR-FaridNeural"))
        case .tl:  return Info(name: "Tagalog", endonym: "Tagalog", flag: "🇵🇭", script: .latin, locale: "fil-PH", voices: ("fil-PH-BlessicaNeural", "fil-PH-AngeloNeural"))
        case .ms:  return Info(name: "Malay", endonym: "Bahasa Melayu", flag: "🇲🇾", script: .latin, locale: "ms-MY", voices: ("ms-MY-YasminNeural", "ms-MY-OsmanNeural"))
        case .yue: return Info(name: "Cantonese", endonym: "廣東話", flag: "🇭🇰", script: .han, locale: "zh-HK", voices: ("zh-HK-HiuMaanNeural", "zh-HK-WanLungNeural"))
        case .pa:  return Info(name: "Punjabi", endonym: "ਪੰਜਾਬੀ", flag: "🇮🇳", script: .indic, locale: "pa-IN", voices: nil)
        case .ta:  return Info(name: "Tamil", endonym: "தமிழ்", flag: "🇮🇳", script: .indic, locale: "ta-IN", voices: ("ta-IN-PallaviNeural", "ta-IN-ValluvarNeural"))
        case .te:  return Info(name: "Telugu", endonym: "తెలుగు", flag: "🇮🇳", script: .indic, locale: "te-IN", voices: ("te-IN-ShrutiNeural", "te-IN-MohanNeural"))
        case .ml:  return Info(name: "Malayalam", endonym: "മലയാളം", flag: "🇮🇳", script: .indic, locale: "ml-IN", voices: ("ml-IN-SobhanaNeural", "ml-IN-MidhunNeural"))
        case .kn:  return Info(name: "Kannada", endonym: "ಕನ್ನಡ", flag: "🇮🇳", script: .indic, locale: "kn-IN", voices: ("kn-IN-SapnaNeural", "kn-IN-GaganNeural"))
        case .kmr: return Info(name: "Kurdish (Kurmanji)", endonym: "Kurmancî", flag: "", script: .latin, locale: "kmr-TR", voices: nil)
        case .ckb: return Info(name: "Kurdish (Sorani)", endonym: "کوردی", flag: "", script: .arabic, locale: "ckb-IQ", voices: nil)
        case .mn:  return Info(name: "Mongolian", endonym: "Монгол хэл", flag: "🇲🇳", script: .cyrillic, locale: "mn-MN", voices: ("mn-MN-YesuiNeural", "mn-MN-BataaNeural"))
        case .km:  return Info(name: "Khmer", endonym: "ភាសាខ្មែរ", flag: "🇰🇭", script: .khmer, locale: "km-KH", voices: ("km-KH-SreymomNeural", "km-KH-PisethNeural"))
        case .lo:  return Info(name: "Lao", endonym: "ພາສາລາວ", flag: "🇱🇦", script: .lao, locale: "lo-LA", voices: ("lo-LA-KeomanyNeural", "lo-LA-ChanthavongNeural"))
        case .kk:  return Info(name: "Kazakh", endonym: "Қазақша", flag: "🇰🇿", script: .cyrillic, locale: "kk-KZ", voices: ("kk-KZ-AigulNeural", "kk-KZ-DauletNeural"))
        case .ky:  return Info(name: "Kyrgyz", endonym: "Кыргызча", flag: "🇰🇬", script: .cyrillic, locale: "ky-KG", voices: nil)
        case .az:  return Info(name: "Azerbaijani", endonym: "Azərbaycanca", flag: "🇦🇿", script: .latin, locale: "az-AZ", voices: ("az-AZ-BanuNeural", "az-AZ-BabekNeural"))
        case .ka:  return Info(name: "Georgian", endonym: "ქართული", flag: "🇬🇪", script: .georgian, locale: "ka-GE", voices: ("ka-GE-EkaNeural", "ka-GE-GiorgiNeural"))
        case .hy:  return Info(name: "Armenian", endonym: "Հայերեն", flag: "🇦🇲", script: .armenian, locale: "hy-AM", voices: nil)
        case .ur:  return Info(name: "Urdu", endonym: "اردو", flag: "🇵🇰", script: .arabic, locale: "ur-PK", voices: ("ur-PK-UzmaNeural", "ur-PK-AsadNeural"))
        case .bn:  return Info(name: "Bengali", endonym: "বাংলা", flag: "🇧🇩", script: .indic, locale: "bn-BD", voices: ("bn-BD-NabanitaNeural", "bn-BD-PradeepNeural"))
        }
    }

    /// What English speakers call it.
    var name: String { info.name }

    /// What its speakers call it, in its own script.
    var endonym: String { info.endonym }

    /// The flag shown next to the course; empty for Kurdish, which has no emoji flag
    /// (`FlagOrb` paints the Kurdish one itself).
    var flag: String { info.flag }

    var isKurdish: Bool { self == .kmr || self == .ckb }

    /// Two letters for the little badge that stands in for a flag.
    var badge: String {
        switch self {
        case .kmr: return "KU"
        case .ckb: return "CK"
        case .yue: return "YU"
        default: return rawValue.uppercased()
        }
    }

    /// The alphabet it is written in.
    var script: Script { info.script }

    /// A Latin-script language can be typed on any keyboard. The others show a
    /// romanisation under every line and build answers from tiles instead.
    var isLatin: Bool { script == .latin }

    /// Written right to left.
    var isRightToLeft: Bool { script == .arabic }

    /// Written without spaces between words, so word boundaries come from a tokenizer.
    var isUnspaced: Bool { script.isUnspaced }

    /// Best-effort BCP-47 locale for speech synthesis / recognition.
    var speechLocale: String { info.locale }
    /// What a remote recogniser should be told the recording is in.
    var recognitionLocale: String { speechLocale }
    /// Ordered fallbacks when the system has no voice of its own for the language.
    /// Uzbek has none in iOS: a Turkic neighbour reads it, approximately.
    var speechFallbacks: [String] {
        switch self {
        case .uz: return ["uz-UZ", "tr-TR", "az-AZ", "ru-RU"]
        case .yue: return ["zh-HK", "yue-CN"]
        default: return [speechLocale]
        }
    }

    /// The neural voices that read it — a woman's and a man's — from the free Edge
    /// service. Nil for the few languages no service reads yet.
    var neuralVoices: (female: String, male: String)? { info.voices }

    /// Whether anything can read it aloud. The courses that cannot are still whole
    /// courses; they just have no listening exercises and no voice on the call.
    var canBeSpoken: Bool { neuralVoices != nil }

    /// Whether the phone can hear it: Apple's recogniser for Thai, Malay and
    /// Cantonese, the Uzbek model bundled with the app for Uzbek. The others have
    /// none, so their speaking exercises stay off.
    var canBeHeard: Bool {
        switch self {
        case .en, .uz, .th, .ms, .yue: return true
        default: return false
        }
    }
}

extension Language {
    /// The course being taken right now. `AppState` sets it whenever it loads one, so
    /// the engines that only carry "the learner's language" can still find the other
    /// side of a pair.
    static var current: Language = .th

    /// The other side: the course's language for English, English for a course.
    var other: Language { self == .en ? Language.current : .en }
}

// MARK: - Bilingual strings

/// A line in English and in the course's language.
///
/// Interface copy only ever has English, and reads the same whichever language it is
/// asked for; content — titles, Anorcha's lines, the questions on a call — has both.
struct Bilingual: Codable, Hashable {
    let en: String
    /// The same line in the language of the course.
    let tx: String

    init(en: String, tx: String) { self.en = en; self.tx = tx }
    /// Interface copy: English, whatever language is asked for.
    init(_ en: String) { self.en = en; self.tx = en }

    func callAsFunction(_ lang: Language) -> String { self[lang] }
    subscript(_ lang: Language) -> String { lang == .en ? en : tx }

    private enum CodingKeys: String, CodingKey { case en, tx }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        en = try c.decode(String.self, forKey: .en)
        tx = try c.decodeIfPresent(String.self, forKey: .tx) ?? en
    }
}

/// One translation pair. Encoded compactly in JSON as ["english", "target"], or
/// ["english", "target", "romanisation"] for a course in another script.
struct Pair: Codable, Hashable, Identifiable {
    let en: String
    let tx: String
    /// How the target side sounds, in Latin letters — for scripts a beginner cannot read.
    let rom: String?

    var id: String { "\(en)|\(tx)" }

    init(en: String, tx: String, rom: String? = nil) {
        self.en = en; self.tx = tx; self.rom = rom
    }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        en = try c.decode(String.self)
        tx = try c.decode(String.self)
        let third = c.isAtEnd ? nil : try? c.decode(String.self)
        rom = (third?.isEmpty ?? true) ? nil : third
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(en); try c.encode(tx)
        if let rom { try c.encode(rom) }
    }

    subscript(_ lang: Language) -> String { lang == .en ? en : tx }

    /// Kept for the screens that show a note under a word; the course has none.
    var hint: String? { nil }

    /// Number of words on one side — used to pick exercise difficulty.
    func wordCount(_ lang: Language) -> Int {
        WordSplitter.words(in: self[lang], language: lang).count
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
        case .a1: return Bilingual("Beginner")
        case .a2: return Bilingual("Elementary")
        case .b1: return Bilingual("Intermediate")
        case .b2: return Bilingual("Upper intermediate")
        }
    }
}

struct GrammarNote: Codable, Hashable, Identifiable {
    let title: Bilingual
    let body: Bilingual
    var examples: [Pair] = []
    var id: String { title.en }
}

struct DialogueLine: Codable, Hashable, Identifiable {
    let who: String
    let en: String
    let tx: String
    var rom: String? = nil
    var id: String { "\(who)|\(en)" }
    subscript(_ lang: Language) -> String { lang == .en ? en : tx }
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
    /// Practice sentences built from this lesson's words, a dozen or so per lesson.
    ///
    /// They are not what the lesson *teaches* — that is `vocab` and `phrases`, and it
    /// is what the first pass, the manual and the word counts are made of. They are
    /// what the later passes are made of, so that the fifth time through a lesson is
    /// not the same four sentences as the first.
    var drills: [Pair] = []

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
    var allDrills: [Pair] { lessons.flatMap(\.drills) }

    /// Lessons + the story + the writing chapter + the unit review, in path order.
    ///
    /// The writing chapter is not in the curriculum files: every unit gets one, built
    /// from its own vocabulary, which is what puts a piece of real text production in
    /// front of the learner thirty-two times across the course instead of never.
    func nodes(level: CEFR, index: Int) -> [PathNode] {
        var out: [PathNode] = lessons.enumerated().map { i, l in
            PathNode(kind: .lesson(l), unitID: id, level: level, indexInUnit: i)
        }
        if let dialogue {
            out.append(PathNode(kind: .story(dialogue), unitID: id, level: level, indexInUnit: out.count))
        }
        if !allPairs.isEmpty {
            out.append(PathNode(kind: .writing(WritingPlanner.chapter(for: self, level: level)),
                                unitID: id, level: level, indexInUnit: out.count))
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
        /// Nothing but writing: a text conversation with Anorcha. See `WritingChapter`.
        case writing(WritingChapter)
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
        case .writing: return "\(unitID)-writing"
        case .review: return "\(unitID)-review"
        }
    }

    var title: Bilingual {
        switch kind {
        case .lesson(let l): return l.title
        case .story(let d): return d.title
        case .writing(let w): return w.title
        case .review: return Bilingual("Unit review")
        }
    }

    var icon: String {
        switch kind {
        case .lesson: return "star.fill"
        case .story: return "text.bubble.fill"
        case .writing: return "bubble.left.and.text.bubble.right.fill"
        case .review: return "crown.fill"
        }
    }

    var xpReward: Int {
        switch kind {
        case .lesson: return 15
        case .story: return 20
        case .writing: return 35
        case .review: return 40
        }
    }

    /// Lessons take five passes to complete, like a Duolingo skill; stories, writing
    /// chapters and unit reviews are one-shot.
    var requiredSessions: Int {
        switch kind {
        case .lesson: return 5
        case .story, .writing, .review: return 1
        }
    }

    /// True for the chapters that are not a set of exercises at all.
    var isWriting: Bool {
        if case .writing = kind { return true }
        return false
    }

    /// What the n-th pass over this node trains.
    func focus(forSession index: Int) -> SessionFocus {
        switch kind {
        case .lesson: return SessionFocus.forSession(index)
        case .story: return .listening
        case .writing: return .writing
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
        // a chapter is never the rose of a mistake, whatever the content file says
        let named = try c.decodeIfPresent(UnitAccent.self, forKey: .accent) ?? .sky
        accent = named == .red ? .purple : named
        grammar = try c.decodeIfPresent([GrammarNote].self, forKey: .grammar) ?? []
        lessons = try c.decodeIfPresent([Lesson].self, forKey: .lessons) ?? []
        dialogue = try c.decodeIfPresent(Dialogue.self, forKey: .dialogue)
    }
}

extension Lesson {
    enum CodingKeys: String, CodingKey { case id, title, vocab, phrases, drills }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(Bilingual.self, forKey: .title)
        vocab = try c.decodeIfPresent([Pair].self, forKey: .vocab) ?? []
        phrases = try c.decodeIfPresent([Pair].self, forKey: .phrases) ?? []
        drills = try c.decodeIfPresent([Pair].self, forKey: .drills) ?? []
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
