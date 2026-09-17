import Foundation

/// Each pass over a lesson trains something different, so repeating a node five
/// times never feels like doing the same exercise set again.
enum SessionFocus: String, CaseIterable, Codable, Hashable {
    case discover     // 1st pass: meet the words — matching, reading, audio support
    case listening    // 2nd pass: ears only
    case writing      // 3rd pass: produce it with the keyboard
    case speaking     // 4th pass: say it out loud
    case review       // 5th pass: everything mixed, production heavy

    static func forSession(_ index: Int) -> SessionFocus {
        let order: [SessionFocus] = [.discover, .listening, .writing, .speaking, .review]
        return order[max(0, index) % order.count]
    }

    var label: Bilingual {
        switch self {
        case .discover:  return Bilingual(it: "Scoperta", uz: "Tanishuv")
        case .listening: return Bilingual(it: "Ascolto", uz: "Tinglash")
        case .writing:   return Bilingual(it: "Scrittura", uz: "Yozish")
        case .speaking:  return Bilingual(it: "Parlato", uz: "Gapirish")
        case .review:    return Bilingual(it: "Ripasso", uz: "Takror")
        }
    }

    var blurb: Bilingual {
        switch self {
        case .discover:  return Bilingual(it: "Nuove parole, con aiuto",
                                          uz: "Yangi so'zlar, yordam bilan")
        case .listening: return Bilingual(it: "Solo orecchio: audio e dettato",
                                          uz: "Faqat quloq: audio va diktant")
        case .writing:   return Bilingual(it: "Scrivi tu le frasi",
                                          uz: "Jumlalarni o'zingiz yozing")
        case .speaking:  return Bilingual(it: "Pronuncia al microfono",
                                          uz: "Mikrofonga gapiring")
        case .review:    return Bilingual(it: "Tutto insieme, senza aiuti",
                                          uz: "Hammasi birga, yordamsiz")
        }
    }

    var icon: String {
        switch self {
        case .discover:  return "sparkles"
        case .listening: return "ear.fill"
        case .writing:   return "pencil.line"
        case .speaking:  return "mic.fill"
        case .review:    return "arrow.triangle.2.circlepath"
        }
    }

    var tint: UnitAccent {
        switch self {
        case .discover:  return .sky
        case .listening: return .amber
        case .writing:   return .purple
        case .speaking:  return .pink
        case .review:    return .green
        }
    }

    /// The skill the session leans on. `nil` means "no emphasis, mix everything".
    var emphasis: Skill? {
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
        case .discover:  return 0.3
        case .listening: return 0.4
        case .writing:   return 0.7
        case .speaking:  return 0.6
        case .review:    return 0.65
        }
    }
}
