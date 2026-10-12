import SwiftUI

// MARK: - The bloom behind every screen

/// Soft blooms of colour on a pale canvas — pink, lilac, periwinkle, sky — drifting
/// very slowly. Every screen sits on one; the mood picks the colours.
///
/// The blooms are radial gradients, not blurred shapes: they cost nothing to draw and
/// nothing to move, which matters on a screen that also scrolls a long path.
struct AuroraBackground: View {
    enum Mood { case home, practice, call, grammar, profile, lesson, sheet, celebrate, night }
    var mood: Mood = .home
    @State private var drift = false

    private struct Bloom: Identifiable {
        let id = UUID()
        var color: Color
        var x: CGFloat, y: CGFloat          // centre, as a fraction of the screen
        var radius: CGFloat                 // as a fraction of the width
        var opacity: Double = 0.9
        var dx: CGFloat = 0.06, dy: CGFloat = 0.04
    }

    private var blooms: [Bloom] {
        switch mood {
        case .home:
            return [Bloom(color: Palette.bloomPink, x: 0.05, y: 0.06, radius: 0.85),
                    Bloom(color: Palette.bloomLilac, x: 0.95, y: 0.22, radius: 0.75, dx: -0.05),
                    Bloom(color: Palette.bloomSky, x: 0.0, y: 0.62, radius: 0.7, opacity: 0.7),
                    Bloom(color: Palette.bloomBlue, x: 1.05, y: 0.98, radius: 0.8, opacity: 0.75, dx: -0.04, dy: -0.05)]
        case .practice:
            return [Bloom(color: Palette.bloomPeach, x: 0.0, y: 0.04, radius: 0.8),
                    Bloom(color: Palette.bloomLilac, x: 1.0, y: 0.26, radius: 0.75, dx: -0.05),
                    Bloom(color: Palette.bloomMint, x: 0.0, y: 0.8, radius: 0.75, opacity: 0.75),
                    Bloom(color: Palette.bloomBlue, x: 1.05, y: 1.0, radius: 0.7, opacity: 0.6)]
        case .call:
            return [Bloom(color: Palette.bloomPink, x: 0.95, y: 0.05, radius: 0.85),
                    Bloom(color: Palette.bloomBlue, x: 0.0, y: 0.5, radius: 0.75, opacity: 0.6),
                    Bloom(color: Palette.bloomLilac, x: 0.9, y: 0.95, radius: 0.8)]
        case .grammar:
            return [Bloom(color: Palette.bloomSky, x: 0.0, y: 0.04, radius: 0.85),
                    Bloom(color: Palette.bloomLilac, x: 1.0, y: 0.35, radius: 0.75, dx: -0.05),
                    Bloom(color: Palette.bloomPink, x: 0.1, y: 1.0, radius: 0.7, opacity: 0.7)]
        case .profile:
            return [Bloom(color: Palette.bloomMint, x: 1.0, y: 0.03, radius: 0.8, opacity: 0.85),
                    Bloom(color: Palette.bloomPink, x: 0.0, y: 0.25, radius: 0.75),
                    Bloom(color: Palette.bloomLilac, x: 1.0, y: 0.75, radius: 0.8),
                    Bloom(color: Palette.bloomSky, x: 0.0, y: 1.0, radius: 0.6, opacity: 0.6)]
        case .lesson:
            return [Bloom(color: Palette.bloomLilac, x: 0.95, y: -0.02, radius: 0.85, opacity: 0.75),
                    Bloom(color: Palette.bloomPink, x: -0.05, y: 0.32, radius: 0.6, opacity: 0.5),
                    Bloom(color: Palette.bloomSky, x: 1.0, y: 1.0, radius: 0.75, opacity: 0.55)]
        case .sheet:
            return [Bloom(color: Palette.bloomLilac, x: 0.9, y: 0.0, radius: 0.8, opacity: 0.8),
                    Bloom(color: Palette.bloomPink, x: 0.0, y: 0.4, radius: 0.7, opacity: 0.55)]
        case .celebrate:
            return [Bloom(color: Palette.bloomPink, x: 0.0, y: 0.05, radius: 0.85),
                    Bloom(color: Palette.bloomSky, x: 1.0, y: 0.15, radius: 0.8),
                    Bloom(color: Palette.bloomMint, x: 0.0, y: 0.7, radius: 0.75, opacity: 0.8),
                    Bloom(color: Palette.bloomPeach, x: 1.0, y: 0.85, radius: 0.7, opacity: 0.8),
                    Bloom(color: Palette.bloomLilac, x: 0.5, y: 0.45, radius: 0.6, opacity: 0.6)]
        case .night:
            return [Bloom(color: Color(hex: 0x5B3FC0), x: 1.0, y: 0.0, radius: 0.9, opacity: 0.6),
                    Bloom(color: Color(hex: 0x2E2A86), x: 0.0, y: 0.45, radius: 0.85, opacity: 0.6),
                    Bloom(color: Color(hex: 0x4A35A6), x: 0.9, y: 1.0, radius: 0.85, opacity: 0.6)]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                (mood == .night ? Color(hex: 0x0B0A1A) : Palette.bg)
                ForEach(blooms) { b in
                    let r = b.radius * w
                    Circle()
                        .fill(RadialGradient(colors: [b.color.opacity(b.opacity), b.color.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: r))
                        .frame(width: r * 2, height: r * 2)
                        .position(x: b.x * w, y: b.y * h)
                        .offset(x: drift ? b.dx * w : 0, y: drift ? b.dy * h : 0)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Frosted glass

/// A pane of frosted glass: the bloom shows through, a bright rim catches the light
/// along the top, and a soft violet shadow makes it float.
struct GlassPane<S: InsettableShape>: View {
    var shape: S
    var tint: Color?
    var material: Bool = true
    var shadow: Bool = true

    var body: some View {
        ZStack {
            if material { shape.fill(.ultraThinMaterial) }
            shape.fill(LinearGradient(colors: [Palette.glassTop, Palette.glassBottom],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            if let tint {
                shape.fill(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.08)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            shape.strokeBorder(LinearGradient(colors: [Palette.glassRim, Palette.glassRimLow,
                                                       (tint ?? Palette.glassRim).opacity(0.35)],
                                              startPoint: .top, endPoint: .bottom),
                               lineWidth: 1.2)
        }
        .compositingGroup()
        .shadow(color: shadow ? (tint?.opacity(0.22) ?? Palette.glassShadow) : .clear,
                radius: 20, x: 0, y: 10)
    }
}

extension View {
    /// Sits the view on a rounded pane of glass.
    func glass(radius: CGFloat = Metrics.radius, tint: Color? = nil,
               material: Bool = true, shadow: Bool = true) -> some View {
        background(GlassPane(shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
                             tint: tint, material: material, shadow: shadow))
    }

    /// Sits the view on a capsule of glass.
    func glassCapsule(tint: Color? = nil, material: Bool = true, shadow: Bool = true) -> some View {
        background(GlassPane(shape: Capsule(), tint: tint, material: material, shadow: shadow))
    }

    /// Sits the view on a circle of glass.
    func glassCircle(tint: Color? = nil, material: Bool = true, shadow: Bool = true) -> some View {
        background(GlassPane(shape: Circle(), tint: tint, material: material, shadow: shadow))
    }
}

// MARK: - Buttons

/// The palettes a filled button can wear: violet, a lighter lilac, a soft rose for
/// the rare destructive action, and one per kind of session, so "Continua · Ascolto"
/// is the same aqua as the node it starts. The other names are kept for the screens
/// that use them, and are violet too.
enum Tone {
    case violet, mint, rose, peach, sky, lilac, pink
    case reading, listening, writing, speaking

    var colors: [Color] {
        switch self {
        case .rose:
            return [Color(hex: 0xE88EA6), Color(hex: 0xC95F7E)]
        case .lilac:
            return [Color(light: 0xBBA8FF, dark: 0xC2B2FF), Color(light: 0x8E72F6, dark: 0x957CFF)]
        case .reading:
            return [Color(hex: 0x63B1F9), Color(hex: 0x4580DC)]
        case .listening:
            return [Color(hex: 0x52CAD6), Color(hex: 0x1798B4)]
        case .writing:
            return [Color(hex: 0xFDB47C), Color(hex: 0xE07A5C)]
        case .speaking:
            return [Color(hex: 0x74D4A6), Color(hex: 0x14A28F)]
        case .violet, .mint, .peach, .sky, .pink:
            return [Color(light: 0x9C80F7, dark: 0xAD98FF), Color(light: 0x7058EC, dark: 0x7E68F5)]
        }
    }

    init(_ accent: UnitAccent) {
        switch accent {
        case .red: self = .rose
        case .reading: self = .reading
        case .listening: self = .listening
        case .writing: self = .writing
        case .speaking: self = .speaking
        default: self = .violet
        }
    }
}

/// The call to action: a glossy capsule of colour with a glow underneath.
struct PrimaryButtonStyle: ButtonStyle {
    var tone: Tone = .violet
    var height: CGFloat = 56
    var stretch: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        PrimaryBody(configuration: configuration, tone: tone, height: height, stretch: stretch)
    }

    private struct PrimaryBody: View {
        @Environment(\.isEnabled) private var enabled
        let configuration: Configuration
        let tone: Tone
        let height: CGFloat
        let stretch: Bool

        var body: some View {
            let pressed = configuration.isPressed
            configuration.label
                .font(.heading(17))
                .foregroundStyle(enabled ? .white : Palette.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: stretch ? .infinity : nil)
                .frame(height: height)
                .padding(.horizontal, stretch ? 18 : 26)
                .background {
                    ZStack {
                        if enabled {
                            Capsule().fill(LinearGradient(colors: tone.colors,
                                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                            // the gloss along the top
                            Capsule()
                                .fill(LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0)],
                                                     startPoint: .top, endPoint: .center))
                                .padding(.horizontal, 6).padding(.top, 2)
                            Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        } else {
                            GlassPane(shape: Capsule(), tint: nil, shadow: false)
                        }
                    }
                    .shadow(color: enabled ? (tone.colors.last ?? .clear).opacity(0.38) : .clear,
                            radius: 16, x: 0, y: 8)
                }
                .contentShape(Capsule())
                .scaleEffect(pressed ? 0.97 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
        }
    }
}

/// The secondary button: a capsule of tinted glass — mint, lilac, peach — with a
/// bright rim and a coloured glow, and dark text on it.
struct GlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var height: CGFloat = 54
    var stretch: Bool = true
    var textColor: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.heading(16))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: stretch ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, stretch ? 16 : 22)
            .background {
                ZStack {
                    GlassPane(shape: Capsule(), tint: tint)
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)],
                                             startPoint: .top, endPoint: .center))
                        .padding(.horizontal, 8).padding(.top, 2)
                        .opacity(0.6)
                }
            }
            .contentShape(Capsule())
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(_ tone: Tone, height: CGFloat = 56, stretch: Bool = true) -> PrimaryButtonStyle {
        PrimaryButtonStyle(tone: tone, height: height, stretch: stretch)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
    static func glass(_ tint: Color?, height: CGFloat = 54, stretch: Bool = true,
                      text: Color = Palette.ink) -> GlassButtonStyle {
        GlassButtonStyle(tint: tint, height: height, stretch: stretch, textColor: text)
    }
}

/// Shrinks a little under the finger. For tiles and cards that are buttons.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// A round glass button with a single icon: the microphone, the pencil, the close
/// cross of the component sheet.
struct GlassCircleButton: View {
    var icon: String
    var size: CGFloat = 46
    var tint: Color = Palette.ink
    var wash: Color? = nil
    var accessibility: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .glassCircle(tint: wash)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityLabel(accessibility ?? icon)
    }
}

// MARK: - Orbs and rings

/// A glossy sphere with an icon in it — the 3D icons of the reference cards, drawn.
struct OrbIcon: View {
    enum Look: Equatable {
        case accent(UnitAccent)
        case holo
        case muted
    }
    var symbol: String
    var look: Look
    var size: CGFloat = 56
    var symbolScale: CGFloat = 0.4

    init(_ symbol: String, accent: UnitAccent, size: CGFloat = 56, symbolScale: CGFloat = 0.4) {
        self.symbol = symbol; self.look = .accent(accent); self.size = size; self.symbolScale = symbolScale
    }
    init(_ symbol: String, look: Look, size: CGFloat = 56, symbolScale: CGFloat = 0.4) {
        self.symbol = symbol; self.look = look; self.size = size; self.symbolScale = symbolScale
    }

    private var body3D: AnyShapeStyle {
        switch look {
        case .accent(let a):
            return AnyShapeStyle(RadialGradient(colors: [a.light, a.main, a.shade],
                                                center: UnitPoint(x: 0.32, y: 0.26),
                                                startRadius: size * 0.02, endRadius: size * 0.78))
        case .holo:
            return AnyShapeStyle(Gradients.holo)
        case .muted:
            return AnyShapeStyle(RadialGradient(colors: [Color(light: 0xFFFFFF, dark: 0x3A3858),
                                                         Color(light: 0xE9E9F3, dark: 0x2B2946),
                                                         Color(light: 0xCFCFE0, dark: 0x1F1D36)],
                                                center: UnitPoint(x: 0.32, y: 0.26),
                                                startRadius: size * 0.02, endRadius: size * 0.78))
        }
    }

    private var glow: Color {
        switch look {
        case .accent(let a): return a.main.opacity(0.38)
        case .holo: return Color(hex: 0xB8A5FF).opacity(0.45)
        case .muted: return Palette.glassShadow
        }
    }

    private var symbolColor: Color {
        switch look {
        case .accent: return .white
        case .holo: return Color(hex: 0x5B47D6)
        case .muted: return Palette.inkFaint
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(body3D)
            if look == .holo {
                // the pearl under the foil
                Circle().fill(RadialGradient(colors: [.white.opacity(0.65), .white.opacity(0)],
                                             center: UnitPoint(x: 0.35, y: 0.3),
                                             startRadius: 0, endRadius: size * 0.6))
            }
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.56, height: size * 0.32)
                .offset(x: -size * 0.08, y: -size * 0.25)
            Circle()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.05),
                                                      .white.opacity(0.4)],
                                             startPoint: .top, endPoint: .bottom),
                              lineWidth: max(1, size * 0.022))
            Image(systemName: symbol)
                .font(.system(size: size * symbolScale, weight: .bold))
                .foregroundStyle(symbolColor)
                .shadow(color: .black.opacity(look == .muted ? 0 : 0.18), radius: size * 0.03, y: size * 0.02)
        }
        .frame(width: size, height: size)
        .shadow(color: glow, radius: size * 0.2, x: 0, y: size * 0.12)
    }
}

/// A progress arc around an orb, like the ones circling the reference cards.
struct ArcRing: View {
    var progress: Double
    var accent: UnitAccent
    var lineWidth: CGFloat = 4
    var showsTrack: Bool = true

    var body: some View {
        ZStack {
            if showsTrack {
                Circle().stroke(Palette.locked.opacity(0.85), lineWidth: lineWidth)
            }
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(AngularGradient(colors: [accent.light, accent.main, accent.shade, accent.main],
                                        center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
        }
    }
}

/// The ring around a lesson node, cut into its passes: each arc is the colour of the
/// kind of session it stands for, lit once that session is done and only faintly
/// there before it is.
struct SessionRing: View {
    var passes: [UnitAccent]
    var done: Int
    var lineWidth: CGFloat = 5

    var body: some View {
        let count = max(1, passes.count)
        // a gap the width of the stroke, so the round caps never touch
        let gap = 0.035
        let span = 1.0 / Double(count)
        ZStack {
            ForEach(Array(passes.enumerated()), id: \.offset) { i, accent in
                let lit = i < done
                Circle()
                    .trim(from: Double(i) * span + gap / 2, to: Double(i + 1) * span - gap / 2)
                    .stroke(lit ? AnyShapeStyle(LinearGradient(colors: [accent.main, accent.shade],
                                                               startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(i == done ? accent.main.opacity(0.32)
                                                          : Palette.locked.opacity(0.85)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: done)
            }
        }
        .rotationEffect(.degrees(-90))
    }
}

// MARK: - Toggle and checkbox

/// The glass switch of the component sheet: a lilac track, a pearl knob.
struct GlassToggleStyle: ToggleStyle {
    var tint: Color = Palette.purple

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn
                          ? AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.55), tint],
                                                         startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Palette.locked))
                    .overlay(Capsule().strokeBorder(Palette.glassRim.opacity(0.8), lineWidth: 1))
                    .frame(width: 54, height: 32)
                    .shadow(color: configuration.isOn ? tint.opacity(0.35) : .clear, radius: 8, y: 4)
                Circle()
                    .fill(LinearGradient(colors: [.white, Color(hex: 0xEDEBFA)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                    .padding(3)
            }
            .contentShape(Capsule())
            .onTapGesture {
                Feedback.tap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { configuration.isOn.toggle() }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(configuration.isOn ? "on" : "off")
        }
    }
}

extension ToggleStyle where Self == GlassToggleStyle {
    static var glass: GlassToggleStyle { GlassToggleStyle() }
}

/// A pill with a round tick in it: the checkbox of the component sheet.
struct GlassCheckbox: View {
    var label: String
    var checked: Bool
    var tint: Color = Palette.purple
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().strokeBorder(checked ? tint : Palette.strokeDeep, lineWidth: 1.6)
                    if checked {
                        Circle().fill(tint).padding(3)
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                Text(label).font(.heading(15)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 16).frame(height: 46)
            .glassCapsule(tint: checked ? tint : nil)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Fields

/// The glass search pill.
struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.inkSoft)
            TextField(placeholder, text: $text)
                .font(.plain(16)).foregroundStyle(Palette.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .glassCapsule()
    }
}

/// A glass pill that opens a menu: the "select dropdown" of the component sheet.
struct GlassDropdown<Content: View>: View {
    var icon: String?
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.brand)
                }
                Text(title).font(.heading(15)).foregroundStyle(Palette.ink).lineLimit(1)
                Spacer(minLength: 6)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .glassCapsule()
        }
    }
}

/// Glass tabs: one capsule, the chosen option lit up in violet.
struct GlassSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Text(label(option))
                    .font(.heading(14))
                    .foregroundStyle(on ? .white : Palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background {
                        if on {
                            Capsule().fill(Gradients.primary)
                                .shadow(color: Palette.brand.opacity(0.35), radius: 8, y: 4)
                                .matchedGeometryEffect(id: "segment", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        Feedback.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = option }
                    }
            }
        }
        .padding(4)
        .glassCapsule()
    }
}

// MARK: - Chips, toast, dialog

/// A small glass capsule: a word, a tag, a stat.
struct GlassChip: View {
    var text: String
    var icon: String? = nil
    var tint: Color = Palette.brand
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
            Text(text).font(.heading(13)).lineLimit(1)
        }
        .foregroundStyle(filled ? .white : tint)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background {
            if filled {
                Capsule().fill(LinearGradient(colors: [tint.opacity(0.85), tint],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                GlassPane(shape: Capsule(), tint: tint, material: false, shadow: false)
            }
        }
    }
}

/// The toast of the component sheet: a pill that slides in, says one thing, goes.
struct GlassToast: View {
    var icon: String
    var text: String
    var tint: Color = Palette.teal

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint))
            Text(text)
                .font(.heading(14)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8).padding(.trailing, 16).padding(.vertical, 8)
        .glassCapsule(tint: tint)
    }
}

/// What a glass dialog says, and what its two buttons do.
struct GlassDialog: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var confirm: String
    var cancel: String
    var destructive: Bool = false
    var icon: String = "questionmark"
    var onConfirm: () -> Void
}

/// The modal of the component sheet: a pane of glass over a dimmed screen.
struct GlassDialogCard: View {
    let dialog: GlassDialog
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            OrbIcon(dialog.icon, accent: dialog.destructive ? .red : .purple, size: 54)
                .padding(.top, 4)
            VStack(spacing: 8) {
                Text(dialog.title)
                    .font(.display(21)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(dialog.message)
                    .font(.plain(15)).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 10) {
                Button {
                    Feedback.pop()
                    dismiss()
                    dialog.onConfirm()
                } label: { Text(dialog.confirm) }
                .buttonStyle(.primary(dialog.destructive ? .rose : .violet, height: 52))
                Button {
                    Feedback.tap(); dismiss()
                } label: { Text(dialog.cancel) }
                .buttonStyle(.glass(nil, height: 50))
            }
            .padding(.top, 4)
        }
        .padding(22)
        .glass(radius: 32)
        .padding(.horizontal, 30)
    }
}

private struct GlassDialogHost: ViewModifier {
    @Binding var item: GlassDialog?

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                if let dialog = item {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { item = nil } }
                        .transition(.opacity)
                    GlassDialogCard(dialog: dialog) {
                        withAnimation(.easeOut(duration: 0.2)) { item = nil }
                    }
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: item?.id)
        }
    }
}

extension View {
    /// Shows a glass dialog over this view while `item` is set.
    func glassDialog(_ item: Binding<GlassDialog?>) -> some View {
        modifier(GlassDialogHost(item: item))
    }
}

/// Who shows a dialog over the whole app, tab bar included.
@Observable
final class DialogPresenter {
    var current: GlassDialog?
    func present(_ dialog: GlassDialog) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { current = dialog }
    }
}

// MARK: - Sheets

extension View {
    /// A sheet that matches the rest of the app: rounded, and with a bloom behind it.
    func auroraSheet(_ mood: AuroraBackground.Mood = .sheet) -> some View {
        self
            .presentationCornerRadius(34)
            .presentationBackground { AuroraBackground(mood: mood) }
    }
}
