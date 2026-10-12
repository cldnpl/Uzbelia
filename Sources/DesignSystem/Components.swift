import SwiftUI

// MARK: - Progress bar

/// A slim track with a gradient fill and a glowing knob at the tip — the "Progress
/// 60/100" bar of the reference.
struct ProgressBar: View {
    var value: Double              // 0...1
    var tint: Color = Palette.brand
    var track: Color = Palette.locked
    var height: CGFloat = 8
    /// The knob at the tip of the fill.
    var showsShine: Bool = true

    var body: some View {
        let knob = height + 8
        GeometryReader { geo in
            let filled = min(max(value, 0), 1)
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(track).frame(height: height)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.55), tint],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: filled <= 0 ? 0 : max(height, width * filled), height: height)
                    .shadow(color: tint.opacity(0.4), radius: 6, y: 2)
                if showsShine && filled > 0 {
                    Circle()
                        .fill(tint)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .frame(width: knob, height: knob)
                        .shadow(color: tint.opacity(0.55), radius: 6, y: 2)
                        .offset(x: max(0, min(width - knob, width * filled - knob / 2)))
                }
            }
            .frame(height: geo.size.height)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: value)
        }
        .frame(height: showsShine ? knob : height)
    }
}

// MARK: - Small stat pills

/// A count with its icon, on a little capsule of glass.
struct StatPill: View {
    var icon: String
    var text: String
    var tint: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(text).font(.heading(14)).monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 11).frame(height: 34)
        .glassCapsule(material: false, shadow: false)
    }
}

/// "∞" next to an icon, for the unlimited hearts/gems this build ships with.
struct InfinityPill: View {
    var icon: String
    var tint: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
            Image(systemName: "infinity").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 11).frame(height: 34)
        .glassCapsule(material: false, shadow: false)
    }
}

struct Tag: View {
    var text: String
    var tint: Color
    var body: some View {
        Text(text.uppercased())
            .font(.heading(10.5)).kerning(0.7)
            .foregroundStyle(tint)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1))
    }
}

// MARK: - Mascot: "Anorcha", a little pomegranate

/// A glossy violet pomegranate with a pale lavender crown.
struct Mascot: View {
    enum Mood { case happy, cheer, sad, think, sleep }
    var mood: Mood = .happy
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            // crown / calyx
            Crown()
                .fill(LinearGradient(colors: [Color(hex: 0xEDE7FF), Color(hex: 0xB49EFF)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.44, height: size * 0.3)
                .offset(y: -size * 0.45)
            // body
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xD9CDFF), Color(hex: 0x9478F6), Color(hex: 0x6045D6)],
                                     center: UnitPoint(x: 0.34, y: 0.28),
                                     startRadius: size * 0.02, endRadius: size * 0.7))
                .overlay(
                    Ellipse()
                        .fill(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: size * 0.42, height: size * 0.24)
                        .rotationEffect(.degrees(-18))
                        .offset(x: -size * 0.15, y: -size * 0.24)
                )
                .overlay(
                    Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .clear,
                                                                  Color(hex: 0xE6DEFF).opacity(0.7)],
                                                         startPoint: .top, endPoint: .bottom),
                                          lineWidth: max(1, size * 0.02))
                )
                .shadow(color: Color(hex: 0x7B5CF2).opacity(0.32), radius: size * 0.16, y: size * 0.08)
            // cheeks
            HStack(spacing: size * 0.36) {
                Ellipse().fill(Color.white.opacity(0.28))
                Ellipse().fill(Color.white.opacity(0.28))
            }
            .frame(width: size * 0.7, height: size * 0.1)
            .offset(y: size * 0.14)
            face
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var face: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.18) {
                eye
                eye
            }
            mouth
        }
        .offset(y: size * 0.04)
    }

    @ViewBuilder private var eye: some View {
        switch mood {
        case .sleep:
            Capsule().fill(.white).frame(width: size * 0.15, height: size * 0.035)
        case .cheer:
            ArcShape().stroke(.white, style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
                .frame(width: size * 0.16, height: size * 0.09)
        default:
            ZStack(alignment: .topTrailing) {
                Circle().fill(.white).frame(width: size * 0.14, height: size * 0.17)
                Circle().fill(Color(hex: 0x2A1F5C)).frame(width: size * 0.08)
                    .overlay(alignment: .topLeading) {
                        Circle().fill(.white).frame(width: size * 0.025).offset(x: size * 0.012, y: size * 0.01)
                    }
                    .offset(x: -size * 0.02, y: size * 0.045)
            }
            .frame(width: size * 0.14, height: size * 0.17)
        }
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .sad:
            ArcShape(flipped: true)
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                .frame(width: size * 0.26, height: size * 0.1)
        case .think:
            Capsule().fill(.white).frame(width: size * 0.16, height: size * 0.05)
        case .cheer:
            Ellipse().fill(.white).frame(width: size * 0.24, height: size * 0.19)
        case .sleep:
            Circle().fill(.white.opacity(0.9)).frame(width: size * 0.09)
        case .happy:
            ArcShape()
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                .frame(width: size * 0.28, height: size * 0.12)
        }
    }
}

/// The little crown on top of the pomegranate.
private struct Crown: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.66))
        p.addLine(to: CGPoint(x: w * 0.50, y: 0))
        p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.66))
        p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.30))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

private struct ArcShape: Shape {
    var flipped: Bool = false
    func path(in r: CGRect) -> Path {
        var p = Path()
        if flipped {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height))
        }
        return p
    }
}

/// Anorcha inside a glass bubble, for the places where she is a presence rather
/// than a character: a header, a sheet, a chat.
struct MascotBubble: View {
    var mood: Mascot.Mood = .happy
    var size: CGFloat = 56

    var body: some View {
        Mascot(mood: mood, size: size * 0.72)
            .offset(y: size * 0.05)
            .frame(width: size, height: size)
            .glassCircle()
    }
}

// MARK: - Speech bubble used next to the mascot

struct SpeechBubble<Content: View>: View {
    var tailOnLeft: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(
                GlassPane(shape: UnevenRoundedRectangle(
                    topLeadingRadius: tailOnLeft ? 6 : 22, bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22, topTrailingRadius: tailOnLeft ? 22 : 6,
                    style: .continuous), tint: nil)
            )
    }
}

// MARK: - Flags

/// The language, as a small pearl tag with its code — "UZ", "IT" — in violet. Flags
/// would add red, green and blue to a screen that is meant to be violet and white.
struct FlagBadge: View {
    var language: Language
    var size: CGFloat = 34
    var body: some View {
        Text(language.badge)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .kerning(0.4)
            .foregroundStyle(Palette.purpleDeep)
            .frame(width: size, height: size * 0.72)
            .background(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(LinearGradient(colors: [Violet.v50, Violet.v200],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: max(1, size * 0.04))
            )
            .shadow(color: Palette.glassShadow, radius: 4, y: 2)
            .accessibilityLabel(language.endonym)
    }
}

/// The language tag on a round glass button, in the corner of every tab.
struct FlagOrb: View {
    var language: Language
    var size: CGFloat = 48
    var body: some View {
        FlagMark(language: language, size: size * 0.5)
            .frame(width: size, height: size)
            .glassCircle()
    }
}

/// A course's flag at text size: the emoji, or — for Kurdish, which has none — the
/// red, white and green tricolour with its golden sun, painted.
struct FlagMark: View {
    var language: Language
    var size: CGFloat = 24

    var body: some View {
        if language.flag.isEmpty {
            KurdishFlag()
                .frame(width: size * 1.1, height: size * 0.74)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.1, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
        } else {
            Text(language.flag).font(.system(size: size))
        }
    }
}

private struct KurdishFlag: View {
    var body: some View {
        Canvas { ctx, size in
            let band = size.height / 3
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: band)),
                     with: .color(Color(hex: 0xED2024)))
            ctx.fill(Path(CGRect(x: 0, y: band, width: size.width, height: band)),
                     with: .color(.white))
            ctx.fill(Path(CGRect(x: 0, y: band * 2, width: size.width, height: band)),
                     with: .color(Color(hex: 0x278E43)))
            // the sun: 21 rays round a disc
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.height * 0.4, inner = size.height * 0.24
            var rays = Path()
            for i in 0..<42 {
                let r = i.isMultiple(of: 2) ? outer : inner
                let a = Double(i) / 42 * 2 * .pi - .pi / 2
                let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                if i == 0 { rays.move(to: p) } else { rays.addLine(to: p) }
            }
            rays.closeSubpath()
            ctx.fill(rays, with: .color(Color(hex: 0xFEBD11)))
            let disc = size.height * 0.2
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - disc, y: c.y - disc, width: disc * 2, height: disc * 2)),
                     with: .color(Color(hex: 0xFEBD11)))
        }
    }
}

// MARK: - Misc helpers

struct Shake: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes), y: 0))
    }
}

extension View {
    func shake(_ amount: CGFloat) -> some View { modifier(ShakeModifier(amount: amount)) }
}

private struct ShakeModifier: ViewModifier {
    var amount: CGFloat
    func body(content: Content) -> some View {
        content.modifier(Shake(animatableData: amount))
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.heading(12.5)).kerning(1.2).foregroundStyle(Palette.inkSoft)
            if let subtitle { Text(subtitle).font(.plain(13)).foregroundStyle(Palette.inkFaint) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The big header at the top of every tab: a small line above, a large title that
/// turns violet at its end, and the live stats in the corner.
struct TabHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.heading(16)).foregroundStyle(Palette.inkSoft)
            Text(title)
                .font(.display(34))
                .foregroundStyle(Gradients.title)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(-2)
            if let subtitle {
                Text(subtitle)
                    .font(.plain(14.5)).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
