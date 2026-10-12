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
        case listenMeaning // hear audio, pick what it means in her own language
        case listenBuild   // hear audio, rebuild the sentence from word chips
        case speakRepeat   // hear it first, then say it back — the text stays hidden
        case compose       // write a short text of her own, corrected round by round
    }

    let id = UUID()
    var kind: Kind
    /// The vocabulary/phrase item this question trains (drives spaced repetition).
    var pair: Pair

    var prompt: String = ""
    var promptLanguage: Language = .en
    var answer: String = ""
    var answerLanguage: Language = Language.current
    var options: [String] = []
    var tokens: [String] = []
    var matchPairs: [Pair] = []
    var audioText: String?
    var audioLanguage: Language?
    var blankIndex: Int?          // word index removed in .fillBlank
    var hint: String?
    /// The brief of a `.compose` exercise: what to write about, how it starts, and
    /// the model text the checker measures it against.
    var composition: CompositionTask?
    /// True when this question is coming round again because it was missed earlier
    /// in the same session.
    var isRetry: Bool = false

    var instruction: Bilingual {
        switch kind {
        case .choice:
            return Bilingual("What does it mean?")
        case .listenChoice:
            return Bilingual("Listen and choose")
        case .wordBank:
            return Bilingual("Translate the sentence")
        case .type:
            return Bilingual("Write the translation")
        case .listenType:
            return Bilingual("Write what you hear")
        case .speak:
            return Bilingual("Say this sentence")
        case .match:
            return Bilingual("Match the pairs")
        case .fillBlank:
            return Bilingual("Complete the sentence")
        case .listenMeaning:
            return Bilingual("Listen: what does it mean?")
        case .listenBuild:
            return Bilingual("Build what you hear")
        case .speakRepeat:
            return Bilingual("Listen and repeat")
        case .compose:
            return Bilingual("Write a short text")
        }
    }

    var trainsSkill: Skill { kind.skill }

    static func == (l: Exercise, r: Exercise) -> Bool { l.id == r.id }

    func hash(into h: inout Hasher) { h.combine(id) }
}

extension Exercise.Kind {
    /// The one skill a format trains. A session that says "Ascolto" on the label is
    /// made only of formats whose skill is `.listening`, and so on — which is why this
    /// has to be a property of the format and not a guess made per question.
    var skill: Skill {
        switch self {
        case .choice, .fillBlank, .wordBank, .match: return .reading
        case .type, .compose: return .writing
        case .listenType, .listenChoice, .listenMeaning, .listenBuild: return .listening
        case .speak, .speakRepeat: return .speaking
        }
    }
}

enum Skill: String, CaseIterable, Codable {
    case reading, writing, listening, speaking

    var label: Bilingual {
        switch self {
        case .reading: return Bilingual("Reading")
        case .writing: return Bilingual("Writing")
        case .listening: return Bilingual("Listening")
        case .speaking: return Bilingual("Speaking")
        }
    }
    var icon: String {
        switch self {
        case .reading: return "text.book.closed.fill"
        case .writing: return "pencil.line"
        case .listening: return "headphones"
        case .speaking: return "mic.fill"
        }
    }
    var tint: UnitAccent {
        switch self {
        case .reading: return .reading
        case .writing: return .writing
        case .listening: return .listening
        case .speaking: return .speaking
        }
    }
}
