import Foundation

/// A single question inside a lesson session.
struct Exercise: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case choice        // read prompt, pick the translation
        case listenChoice  // hear audio, pick the matching text
        case wordBank      // build the translation from word chips
        case type          // type the translation
        case listenType    // hear audio, type what you heard
        case speak         // say the sentence out loud
        case match         // tap the matching pairs
        case fillBlank     // choose the missing word in a sentence
    }

    let id = UUID()
    var kind: Kind
    /// The vocabulary/phrase item this question trains (drives spaced repetition).
    var pair: Pair

    var prompt: String = ""
    var promptLanguage: Language = .it
    var answer: String = ""
    var answerLanguage: Language = .uz
    var options: [String] = []
    var tokens: [String] = []
    var matchPairs: [Pair] = []
    var audioText: String?
    var audioLanguage: Language?
    var blankIndex: Int?          // word index removed in .fillBlank
    var hint: String?
    /// True when this question is coming round again because it was missed earlier
    /// in the same session.
    var isRetry: Bool = false

    var instruction: Bilingual {
        switch kind {
        case .choice:
            return Bilingual(it: "Che cosa significa?", uz: "Bu nima degani?")
        case .listenChoice:
            return Bilingual(it: "Ascolta e scegli", uz: "Tinglang va tanlang")
        case .wordBank:
            return Bilingual(it: "Traduci la frase", uz: "Jumlani tarjima qiling")
        case .type:
            return Bilingual(it: "Scrivi la traduzione", uz: "Tarjimasini yozing")
        case .listenType:
            return Bilingual(it: "Scrivi quello che senti", uz: "Eshitganingizni yozing")
        case .speak:
            return Bilingual(it: "Pronuncia questa frase", uz: "Ushbu jumlani ayting")
        case .match:
            return Bilingual(it: "Abbina le coppie", uz: "Juftlarni moslang")
        case .fillBlank:
            return Bilingual(it: "Completa la frase", uz: "Jumlani to'ldiring")
        }
    }

    var trainsSkill: Skill {
        switch kind {
        case .choice, .fillBlank: return .reading
        case .wordBank: return .reading
        case .type: return .writing
        case .listenType: return .listening
        case .listenChoice: return .listening
        case .speak: return .speaking
        case .match: return .reading
        }
    }

    static func == (l: Exercise, r: Exercise) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum Skill: String, CaseIterable, Codable {
    case reading, writing, listening, speaking

    var label: Bilingual {
        switch self {
        case .reading: return Bilingual(it: "Lettura", uz: "O'qish")
        case .writing: return Bilingual(it: "Scrittura", uz: "Yozish")
        case .listening: return Bilingual(it: "Ascolto", uz: "Tinglash")
        case .speaking: return Bilingual(it: "Parlato", uz: "Gapirish")
        }
    }
    var icon: String {
        switch self {
        case .reading: return "text.book.closed.fill"
        case .writing: return "pencil.line"
        case .listening: return "ear.fill"
        case .speaking: return "mic.fill"
        }
    }
    var tint: UnitAccent {
        switch self {
        case .reading: return .sky
        case .writing: return .purple
        case .listening: return .amber
        case .speaking: return .pink
        }
    }
}
