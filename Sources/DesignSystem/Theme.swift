import SwiftUI

// MARK: - Dynamic color helper

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
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

enum Palette {
    static let bg         = Color(light: 0xFFFCF6, dark: 0x111318)
    static let bgElevated = Color(light: 0xFFFFFF, dark: 0x1B1E26)
    static let card       = Color(light: 0xFFFFFF, dark: 0x1E222B)
    static let stroke     = Color(light: 0xE6E1D6, dark: 0x2E333F)
    static let strokeDeep = Color(light: 0xD5CEC0, dark: 0x3A4050)

    static let ink        = Color(light: 0x22303C, dark: 0xF2F5F8)
    static let inkSoft    = Color(light: 0x6C7A88, dark: 0x9AA6B4)
    static let inkFaint   = Color(light: 0xAAB4BE, dark: 0x6B7684)

    static let brand      = Color(light: 0x0E9FD0, dark: 0x27B6E4)   // uzbek tile blue
    static let brandDeep  = Color(light: 0x0A7CA4, dark: 0x1A88AC)
    static let teal       = Color(light: 0x12BFA6, dark: 0x1FD4B9)

    static let green      = Color(light: 0x49C96D, dark: 0x4FD675)
    static let greenDeep  = Color(light: 0x36A455, dark: 0x2E9A4C)
    static let greenSoft  = Color(light: 0xE6F8EC, dark: 0x16301F)

    static let red        = Color(light: 0xEE5A47, dark: 0xF56B58)
    static let redDeep    = Color(light: 0xC53E2D, dark: 0xB94636)
    static let redSoft    = Color(light: 0xFDECE9, dark: 0x331915)

    static let amber      = Color(light: 0xF7A81B, dark: 0xFFB733)
    static let amberDeep  = Color(light: 0xCE8508, dark: 0xD1900F)

    static let purple     = Color(light: 0x9B6BEF, dark: 0xAE86F5)
    static let purpleDeep = Color(light: 0x7A4FCB, dark: 0x8A5FD8)

    /// Il pulsante "Accedi con Apple", che Apple vuole nero su chiaro e bianco su
    /// scuro — e il testo sempre dell'altro colore. `ink` da solo faceva la prima
    /// metà e non la seconda: al buio diventava un pulsante bianco con la scritta
    /// bianca sopra, cioè un rettangolo vuoto.
    static let appleFill  = Color(light: 0x000000, dark: 0xFFFFFF)
    static let appleEdge  = Color(light: 0x2A2A2A, dark: 0xCFD4DA)
    static let appleInk   = Color(light: 0xFFFFFF, dark: 0x000000)

    static let pink       = Color(light: 0xF2568F, dark: 0xF96FA2)
    static let locked     = Color(light: 0xE3DED2, dark: 0x2A2F3A)
    static let lockedDeep = Color(light: 0xCBC4B4, dark: 0x373D4A)
}

// MARK: - Named accent colours used by curriculum units

enum UnitAccent: String, Codable {
    case sky, teal, green, amber, purple, pink, red

    var main: Color {
        switch self {
        case .sky: return Palette.brand
        case .teal: return Palette.teal
        case .green: return Palette.green
        case .amber: return Palette.amber
        case .purple: return Palette.purple
        case .pink: return Palette.pink
        case .red: return Palette.red
        }
    }
    var deep: Color {
        switch self {
        case .sky: return Palette.brandDeep
        case .teal: return Color(light: 0x0D9682, dark: 0x16A893)
        case .green: return Palette.greenDeep
        case .amber: return Palette.amberDeep
        case .purple: return Palette.purpleDeep
        case .pink: return Color(light: 0xC93C70, dark: 0xD44E82)
        case .red: return Palette.redDeep
        }
    }
}

// MARK: - Typography

extension Font {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func plain(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

// MARK: - Layout tokens

enum Metrics {
    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 13
    static let chunkDepth: CGFloat = 5
    static let hPad: CGFloat = 20
}
