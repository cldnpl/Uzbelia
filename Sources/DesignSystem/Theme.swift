import SwiftUI

// MARK: - Dynamic color helpers

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }

    /// Two whole colours — opacity included — one per appearance.
    static func dynamic(_ light: Color, _ dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Palette
//
// Violet and white, and glass between them — nothing else. One scale of violet, from
// almost-white lavender to deep indigo-violet, carries every accent in the app; the
// only other colours are a soft rose, kept for mistakes, because a wrong answer has
// to look different from a right one, and the four soft skill colours of
// `UnitAccent`, which tell reading, listening, writing and speaking apart. The old
// colour names (sky, mint, peach, rose…) still exist so every screen keeps
// compiling, but they all point into the violet.

enum Violet {
    static let v50  = Color(hex: 0xF7F5FF)
    static let v100 = Color(hex: 0xEFEBFF)
    static let v200 = Color(hex: 0xE0D8FF)
    static let v300 = Color(hex: 0xC9BAFF)
    static let v400 = Color(hex: 0xAA94FB)
    static let v500 = Color(hex: 0x8B6EF3)
    static let v600 = Color(hex: 0x7155E3)
    static let v700 = Color(hex: 0x5B43C7)
    static let v800 = Color(hex: 0x45339C)
}

enum Palette {
    static let bg         = Color(light: 0xF2F0FA, dark: 0x0E0C1E)
    static let bgElevated = Color(light: 0xF9F8FD, dark: 0x17152C)
    /// A card that lets the bloom behind it show through.
    static let card       = Color.dynamic(Color.white.opacity(0.74), Color(hex: 0x221F3F).opacity(0.72))
    static let cardSolid  = Color(light: 0xFFFFFF, dark: 0x1C1A36)
    static let stroke     = Color(light: 0xE3DFF2, dark: 0x2F2B4F)
    static let strokeDeep = Color(light: 0xCFC8E8, dark: 0x3E3963)

    static let ink        = Color(light: 0x1F1A3D, dark: 0xF3F1FF)
    static let inkSoft    = Color(light: 0x625C85, dark: 0xADA7CF)
    static let inkFaint   = Color(light: 0xA8A2C4, dark: 0x6E6893)

    /// The violet: what to press, what is lit, what is right.
    static let brand      = Color(light: 0x8B6EF3, dark: 0xA28CFF)
    static let brandDeep  = Color(light: 0x7155E3, dark: 0xBBA9FF)
    /// A lighter violet, for the second voice.
    static let purple     = Color(light: 0xAA94FB, dark: 0xB3A0FF)
    /// Violet dark enough to read as text on a pale pane.
    static let purpleDeep = Color(light: 0x5B43C7, dark: 0xC6B8FF)

    // every old accent name, pointing into the violet
    static let teal       = purple
    static let sky        = purple
    static let pink       = purple
    static let amber      = purple
    static let amberDeep  = purpleDeep

    // "right" is violet too: the tick says it, not a new colour
    static let green      = brand
    static let greenDeep  = purpleDeep
    static let greenSoft  = Color(light: 0xEFEBFF, dark: 0x26214A)

    /// The one exception: a soft rose, for mistakes and nothing else.
    static let red        = Color(light: 0xD9708C, dark: 0xF08DA6)
    static let redDeep    = Color(light: 0xB5506E, dark: 0xF6AFC0)
    static let redSoft    = Color(light: 0xFBEAF0, dark: 0x3A2030)

    /// Il pulsante "Accedi con Apple", che Apple vuole nero su chiaro e bianco su
    /// scuro — e il testo sempre dell'altro colore. `ink` da solo faceva la prima
    /// metà e non la seconda: al buio diventava un pulsante bianco con la scritta
    /// bianca sopra, cioè un rettangolo vuoto.
    static let appleFill  = Color(light: 0x000000, dark: 0xFFFFFF)
    static let appleEdge  = Color(light: 0x2A2A2A, dark: 0xCFD4DA)
    static let appleInk   = Color(light: 0xFFFFFF, dark: 0x000000)

    static let locked     = Color(light: 0xE7E4F2, dark: 0x262343)
    static let lockedDeep = Color(light: 0xD3CEE6, dark: 0x36325A)

    // the blooms behind everything: lavender on white, violet on night
    static let bloomPink  = Color(light: 0xE4DAFF, dark: 0x3A2B8A)
    static let bloomLilac = Color(light: 0xD3C6FF, dark: 0x4B36A8)
    static let bloomBlue  = Color(light: 0xBFB0FA, dark: 0x33307F)
    static let bloomSky   = Color(light: 0xEEE9FF, dark: 0x29245F)
    static let bloomMint  = Color(light: 0xF4F1FF, dark: 0x221E4F)
    static let bloomPeach = Color(light: 0xE9E3FF, dark: 0x2E2670)

    // glass
    static let glassTop    = Color.dynamic(.white.opacity(0.86), Color(hex: 0x332F63).opacity(0.62))
    static let glassBottom = Color.dynamic(.white.opacity(0.58), Color(hex: 0x1C1A3C).opacity(0.5))
    static let glassRim    = Color.dynamic(.white, .white.opacity(0.30))
    static let glassRimLow = Color.dynamic(.white.opacity(0.35), .white.opacity(0.05))
    /// The violet-tinted shadow that makes a pane float rather than sit.
    static let glassShadow = Color.dynamic(Color(hex: 0x5B43C7).opacity(0.12), .black.opacity(0.45))
}

// MARK: - Gradients

enum Gradients {
    /// The call-to-action: a violet that deepens.
    static let primary = LinearGradient(colors: [Color(light: 0x9C80F7, dark: 0xAD98FF),
                                                 Color(light: 0x7058EC, dark: 0x7E68F5)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Pearl: the colour of anything finished or earned — white and lavender, softly
    /// turning, never a rainbow.
    static let holo = AngularGradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0xECE6FF),
                                               Color(hex: 0xD8CCFF), Color(hex: 0xF6F3FF),
                                               Color(hex: 0xE2D9FF), Color(hex: 0xFFFFFF)],
                                      center: .center)
    static let holoLinear = LinearGradient(colors: [Color(hex: 0xB49CFF), Color(hex: 0x7B5CF2),
                                                    Color(hex: 0x5B43C7)],
                                           startPoint: .leading, endPoint: .trailing)

    /// Big titles: ink that turns violet at the end of the line.
    static let title = LinearGradient(colors: [Palette.ink, Color(light: 0x5B43C7, dark: 0xC9BCFF)],
                                      startPoint: .leading, endPoint: .trailing)

    static func of(_ accent: UnitAccent) -> LinearGradient {
        LinearGradient(colors: [accent.light, accent.main, accent.shade],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Accents used by curriculum units and skills
//
// Units are violet, whatever colour the curriculum names for them: the path is one
// piece. What changes colour is the *kind* of work — every reading pass is the same
// blue, every listening pass the same aqua, and so on — so a node says at a glance
// what it is about to ask of her.
//
// The four skill colours share one lightness and one softness, and only the hue
// moves. Their shadows lean towards the violet, the way a painter warms or cools a
// shadow towards the key light: that is what keeps a peach orb and a mint one
// looking like they belong to the same violet app instead of a box of crayons.
// `red` keeps its soft rose, for mistakes and for hanging up.

enum UnitAccent: String, Codable {
    case sky, teal, green, amber, purple, pink, red
    /// The four kinds of session. Never named by the curriculum, only by the code.
    case reading, listening, writing, speaking

    private struct Shades {
        var main: Color, deep: Color, shade: Color, light: Color
    }

    private var shades: Shades {
        switch self {
        case .reading:
            return Shades(main: Color(light: 0x56A4EB, dark: 0x6AB5FC),
                          deep: Color(light: 0x1E65AA, dark: 0xA7D3FE),
                          shade: Color(hex: 0x4764C2), light: Color(hex: 0xE3F0FE))
        case .listening:
            return Shades(main: Color(light: 0x45BDCB, dark: 0x5ACFDC),
                          deep: Color(light: 0x0B6E7E, dark: 0x8CDCE6),
                          shade: Color(hex: 0x1680AC), light: Color(hex: 0xD4F5F8))
        case .writing:
            return Shades(main: Color(light: 0xF2A86E, dark: 0xFCB277),
                          deep: Color(light: 0x9B4802, dark: 0xF6C19A),
                          shade: Color(hex: 0xCB6160), light: Color(hex: 0xFDEBDD))
        case .speaking:
            return Shades(main: Color(light: 0x66C89A, dark: 0x7ADBAC),
                          deep: Color(light: 0x00714F, dark: 0x9EDFBE),
                          shade: Color(hex: 0x0A8E8C), light: Color(hex: 0xDAF6E6))
        case .red:
            return Shades(main: Palette.red, deep: Palette.redDeep,
                          shade: Color(hex: 0xB5506E), light: Color(hex: 0xFAD9E2))
        case .sky, .teal, .green, .amber, .purple, .pink:
            return Shades(main: Palette.brand, deep: Palette.purpleDeep,
                          shade: Color(hex: 0x5E46D6), light: Color(hex: 0xE6DEFF))
        }
    }

    var main: Color { shades.main }
    /// Dark enough to read as text; turns light at night.
    var deep: Color { shades.deep }
    /// The shadow side of an orb or a gradient — darker in either appearance.
    var shade: Color { shades.shade }
    /// The highlight side of an orb: almost white, with a breath of the colour.
    var light: Color { shades.light }
    /// A pane washed with the colour.
    var soft: Color { main.opacity(0.16) }
}

// MARK: - Typography
//
// Rounded, but never chunky: bold for titles, semibold for headings, medium for the
// words being learnt, regular for everything that explains.

extension Font {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func plain(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .rounded) }
}

// MARK: - Layout tokens

enum Metrics {
    static let radius: CGFloat = 26
    static let radiusSmall: CGFloat = 18
    static let hPad: CGFloat = 20
    /// Room left at the bottom of a tab's scroll view for the floating tab bar.
    static let tabBarClearance: CGFloat = 96
}
