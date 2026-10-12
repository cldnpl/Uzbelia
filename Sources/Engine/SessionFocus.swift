import Foundation

/// Each pass over a lesson trains something different, so repeating a node five
/// times never feels like doing the same exercise set again.
///
/// The label is a promise: a pass called "Ascolto" is made of listening exercises
/// and nothing else, "Scrittura" of writing exercises and nothing else, and so on.
/// Only the fifth pass, "Ripasso", mixes them.
enum SessionFocus: String, CaseIterable, Codable, Hashable {
    case discover     // 1st pass: meet the words — read and recognise them
    case listening    // 2nd pass: ears only
    case writing      // 3rd pass: produce it with the keyboard, and write a short text
    case speaking     // 4th pass: say it out loud
    case review       // 5th pass: everything mixed, production heavy

    static func forSession(_ index: Int) -> SessionFocus {
        let order: [SessionFocus] = [.discover, .listening, .writing, .speaking, .review]
        return order[max(0, index) % order.count]
    }

    var label: Bilingual {
        switch self {
        case .discover:  return Bilingual("Reading")
        case .listening: return Bilingual("Listening")
        case .writing:   return Bilingual("Writing")
        case .speaking:  return Bilingual("Speaking")
        case .review:    return Bilingual("Review")
        }
    }

    var blurb: Bilingual {
        switch self {
        case .discover:  return Bilingual("New words: read, match, recognize")
        case .listening: return Bilingual("Listening only: audio, dictation, rebuild")
        case .writing:   return Bilingual("Write the sentences and a short text yourself")
        case .speaking:  return Bilingual("Voice only: read aloud and repeat")
        case .review:    return Bilingual("Everything together, no hints")
        }
    }

    var icon: String {
        switch self {
        case .discover:  return "text.book.closed.fill"
        case .listening: return "headphones"
        case .writing:   return "pencil.line"
        case .speaking:  return "mic.fill"
        case .review:    return "arrow.triangle.2.circlepath"
        }
    }

    /// Every pass of the same kind wears the same colour, wherever it appears; the
    /// mixed review is the app's own violet.
    var tint: UnitAccent {
        skill?.tint ?? .purple
    }

    /// The one skill the pass is made of. `nil` means "mix everything".
    var skill: Skill? {
        switch self {
        case .discover:  return .reading
        case .listening: return .listening
        case .writing:   return .writing
        case .speaking:  return .speaking
        case .review:    return nil
        }
    }

    /// How much of the session is production (native → target) rather than recognition.
    var productionBias: Double {
        switch self {
        case .discover:  return 0.5
        case .listening: return 0.4
        case .writing:   return 0.85
        case .speaking:  return 0.6
        case .review:    return 0.65
        }
    }

    /// How many questions a pass over a lesson asks, before any missed ones come back.
    /// Ten or so: long enough to drill the words, short enough to do on a bus stop.
    var length: Int {
        switch self {
        case .discover:  return 11      // the matching game counts as one
        case .listening: return 10
        case .writing:   return 9       // eight sentences and a short text
        case .speaking:  return 9
        case .review:    return 11
        }
    }

    /// The pass as it can actually be run with these settings.
    ///
    /// A listening pass with listening switched off cannot keep its promise, and
    /// filling it with something else under the same label is exactly the mismatch
    /// this type exists to prevent — so it becomes a mixed review, and says so.
    func available(with settings: Settings) -> SessionFocus {
        switch self {
        case .listening where !settings.listeningExercises: return .review
        case .speaking where !settings.speakingExercises: return .review
        default: return self
        }
    }
}
