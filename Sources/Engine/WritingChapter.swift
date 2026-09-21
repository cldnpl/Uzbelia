import Foundation

/// A chapter made of nothing but writing.
///
/// Every other node in the path asks for one sentence at a time, graded against an
/// answer that already exists. This one asks the learner to *produce* text: she and
/// Anorcha message each other, several exchanges, about something she has the words
/// for — and only at the end is any of it corrected. It is the one place in the
/// course where there is no right answer to be recognised, which is the only way to
/// find out whether she can actually write the language.
struct WritingChapter: Hashable {
    var unitID: String
    var level: CEFR
    /// What she and Anorcha are messaging about.
    var theme: Theme
    /// The chapter's own vocabulary, so Anorcha writes inside what has been taught.
    var vocabulary: [Pair]
    var unitTitle: Bilingual
    var lessonTopics: [String]

    /// How many messages she has to write before the chapter is done.
    var turns: Int { WritingChapter.turnCount(for: level) }
    /// Below this, a reply is a shrug rather than an answer, and the send button
    /// stays off. It scales with the level, because "long enough" does too.
    var minimumWords: Int { WritingChapter.wordFloor(for: level) }

    var title: Bilingual {
        Bilingual(it: "Scrivi ad Anorcha", uz: "Anorchaga yozing")
    }

    static func turnCount(for level: CEFR) -> Int {
        switch level {
        case .a1: return 4
        case .a2: return 5
        case .b1, .b2: return 6
        }
    }

    static func wordFloor(for level: CEFR) -> Int {
        switch level {
        case .a1: return 3
        case .a2: return 5
        case .b1: return 8
        case .b2: return 12
        }
    }

    // MARK: - What the messages are about

    /// One subject per chapter, fixed for that chapter so it has an identity of its
    /// own in the path — while the messages inside it are written fresh every time.
    struct Theme: Hashable, Identifiable {
        var id: String
        var title: Bilingual
        /// Said to the assistant, in English, as the situation to play.
        var situation: String
        var icon: String

        /// How the exchange opens when there is no assistant to write it.
        var opener: Bilingual
    }

    static let themes: [Theme] = [
        Theme(id: "day",
              title: Bilingual(it: "Com'è andata oggi", uz: "Bugun qanday o'tdi"),
              situation: "You are texting her in the evening to ask how her day went, and telling her about yours.",
              icon: "sun.horizon.fill",
              opener: Bilingual(it: "Ehi! Com'è andata la giornata?", uz: "Salom! Bugun kuning qanday o'tdi?")),
        Theme(id: "plan",
              title: Bilingual(it: "Mettersi d'accordo", uz: "Kelishib olish"),
              situation: "You are trying to agree with her on when and where to meet this week.",
              icon: "calendar",
              opener: Bilingual(it: "Ci vediamo questa settimana? Quando puoi?",
                                uz: "Shu hafta ko'rishamizmi? Qachon bo'sh bo'lasan?")),
        Theme(id: "favour",
              title: Bilingual(it: "Chiedere un favore", uz: "Iltimos qilish"),
              situation: "You need a small favour from her and you are asking for it by message, a little awkwardly.",
              icon: "hands.sparkles.fill",
              opener: Bilingual(it: "Posso chiederti un favore?", uz: "Sendan bir narsa so'rasam maylimi?")),
        Theme(id: "place",
              title: Bilingual(it: "Dove sei?", uz: "Qayerdasan?"),
              situation: "She is somewhere you have never been and you want her to describe it to you.",
              icon: "mappin.and.ellipse",
              opener: Bilingual(it: "Dove sei? Raccontami com'è lì.",
                                uz: "Qayerdasan? U yer qanaqa, aytib ber.")),
        Theme(id: "food",
              title: Bilingual(it: "Cosa mangiamo", uz: "Nima yeymiz"),
              situation: "You are deciding together what to eat, and you disagree pleasantly about it.",
              icon: "fork.knife",
              opener: Bilingual(it: "Ho fame. Cosa mangiamo stasera?",
                                uz: "Qornim ochdi. Kechqurun nima yeymiz?")),
        Theme(id: "news",
              title: Bilingual(it: "Una novità", uz: "Bir yangilik"),
              situation: "You have a small piece of news to tell her and you want her reaction to it.",
              icon: "sparkles",
              opener: Bilingual(it: "Indovina cosa mi è successo oggi!",
                                uz: "Bugun menga nima bo'ldi, top-chi!")),
        Theme(id: "problem",
              title: Bilingual(it: "Un piccolo problema", uz: "Kichik muammo"),
              situation: "Something small has gone wrong for you and you are asking her what she would do.",
              icon: "exclamationmark.bubble.fill",
              opener: Bilingual(it: "Ho un problema… tu cosa faresti?",
                                uz: "Bir muammom bor… sen bo'lsang nima qilarding?")),
        Theme(id: "memory",
              title: Bilingual(it: "Ti ricordi?", uz: "Esingdami?"),
              situation: "You are reminiscing with her about something you both did, and asking her to fill in the parts you forgot.",
              icon: "photo.on.rectangle.angled",
              opener: Bilingual(it: "Ti ricordi quella volta? Non mi ricordo come era finita.",
                                uz: "O'sha safar esingdami? Qanday tugaganini eslay olmayapman.")),
    ]

    // MARK: - The briefing the assistant is given

    /// Everything Anorcha is told before writing a single message: the situation,
    /// the chapter's words, and the ceiling its level puts on her own sentences.
    func briefing(native: Language) -> String {
        let target = native.other
        var lines = [
            "CEFR level: \(level.label)",
            "Chapter: \(unitTitle[native])",
            "Situation: \(theme.situation)",
        ]
        if !lessonTopics.isEmpty {
            lines.append("What this chapter teaches: \(lessonTopics.prefix(10).joined(separator: ", "))")
        }
        if !vocabulary.isEmpty {
            lines.append("Words she has just studied, which your messages should keep to: "
                         + vocabulary.shuffled().prefix(50).map { $0[target] }.joined(separator: ", "))
        }
        lines.append("She has to write \(turns) messages in all, of at least \(minimumWords) words each.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Giving every unit one

enum WritingPlanner {

    /// The theme is chosen from the unit's id rather than at random: a chapter in the
    /// path should be the same chapter tomorrow, even though its messages are not.
    static func chapter(for unit: Unit, level: CEFR) -> WritingChapter {
        let themes = WritingChapter.themes
        let index = abs(stableHash(unit.id)) % themes.count
        return WritingChapter(unitID: unit.id,
                              level: level,
                              theme: themes[index],
                              vocabulary: unit.allPairs,
                              unitTitle: unit.title,
                              lessonTopics: unit.lessons.map { $0.title.it })
    }

    /// `String.hashValue` is salted per process, so the same unit would draw a
    /// different subject on every launch. This one never changes.
    private static func stableHash(_ text: String) -> Int {
        var hash = 5381
        for byte in text.utf8 { hash = (hash &* 33) &+ Int(byte) }
        return hash
    }
}
