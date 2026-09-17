import SwiftUI

// MARK: - Chunky 3D button (the signature control of the app)

struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Palette.green
    var edge: Color = Palette.greenDeep
    var text: Color = .white
    var height: CGFloat = 54
    var radius: CGFloat = Metrics.radius
    var depth: CGFloat = Metrics.chunkDepth
    var stretch: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.heading(17))
            .kerning(0.4)
            .foregroundStyle(text)
            .frame(maxWidth: stretch ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, stretch ? 0 : 22)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            )
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .offset(y: pressed ? depth : 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(edge)
                    .offset(y: depth)
            )
            .animation(.easeOut(duration: 0.07), value: pressed)
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle() }
    static func chunky(_ fill: Color, _ edge: Color, text: Color = .white, height: CGFloat = 54, stretch: Bool = true) -> ChunkyButtonStyle {
        ChunkyButtonStyle(fill: fill, edge: edge, text: text, height: height, stretch: stretch)
    }
    static var chunkyGhost: ChunkyButtonStyle {
        ChunkyButtonStyle(fill: Palette.card, edge: Palette.strokeDeep, text: Palette.ink)
    }
}

/// A tappable card with the same 3D lip, used for answer choices.
struct ChunkyCard<Content: View>: View {
    var fill: Color = Palette.card
    var edge: Color = Palette.stroke
    var border: Color? = Palette.stroke
    var radius: CGFloat = Metrics.radius
    var depth: CGFloat = Metrics.chunkDepth
    var pressed: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(border ?? .clear, lineWidth: border == nil ? 0 : 2)
                    )
            )
            .offset(y: pressed ? depth : 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(edge)
                    .offset(y: depth)
            )
            .animation(.easeOut(duration: 0.07), value: pressed)
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    var value: Double              // 0...1
    var tint: Color = Palette.green
    var track: Color = Palette.locked
    var height: CGFloat = 16
    var showsShine: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                let filled = min(max(value, 0), 1)
                Capsule()
                    .fill(tint)
                    .frame(width: filled <= 0 ? 0 : max(height, geo.size.width * filled))
                    .overlay(alignment: .top) {
                        if showsShine {
                            Capsule()
                                .fill(.white.opacity(0.32))
                                .frame(width: max(0, geo.size.width * filled - 14), height: height * 0.28)
                                .padding(.top, height * 0.16)
                                .padding(.leading, 7)
                        }
                    }
                    .animation(.spring(response: 0.42, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Small stat pills

struct StatPill: View {
    var icon: String
    var text: String
    var tint: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15, weight: .black))
            Text(text).font(.heading(16)).monospacedDigit()
        }
        .foregroundStyle(tint)
    }
}

struct Tag: View {
    var text: String
    var tint: Color
    var body: some View {
        Text(text.uppercased())
            .font(.heading(11)).kerning(0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}

// MARK: - Mascot: "Anorcha", a little pomegranate

struct Mascot: View {
    enum Mood { case happy, cheer, sad, think, sleep }
    var mood: Mood = .happy
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            // crown / calyx
            Crown()
                .fill(Color(hex: 0x2FA84F))
                .frame(width: size * 0.44, height: size * 0.3)
                .offset(y: -size * 0.45)
            // body
            Circle()
                .fill(
                    LinearGradient(colors: [Color(hex: 0xF2544B), Color(hex: 0xD2263B)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    Ellipse()
                        .fill(.white.opacity(0.22))
                        .frame(width: size * 0.3, height: size * 0.18)
                        .rotationEffect(.degrees(-24))
                        .offset(x: -size * 0.19, y: -size * 0.22)
                )
            // face
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
                Circle().fill(Color(hex: 0x2A1418)).frame(width: size * 0.075)
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

/// The little green calyx on top of the pomegranate.
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

// MARK: - Speech bubble used next to the mascot

struct SpeechBubble<Content: View>: View {
    var tailOnLeft: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(
                BubbleShape(tailOnLeft: tailOnLeft)
                    .fill(Palette.card)
                    .overlay(BubbleShape(tailOnLeft: tailOnLeft).stroke(Palette.stroke, lineWidth: 2))
            )
    }
}

private struct BubbleShape: Shape {
    var tailOnLeft: Bool
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: CGRect(x: tailOnLeft ? 10 : 0, y: 0,
                                         width: r.width - 10, height: r.height),
                     cornerRadius: 14)
        let midY = min(r.height * 0.5, 28)
        if tailOnLeft {
            p.move(to: CGPoint(x: 0, y: midY))
            p.addLine(to: CGPoint(x: 11, y: midY - 9))
            p.addLine(to: CGPoint(x: 11, y: midY + 9))
        } else {
            p.move(to: CGPoint(x: r.width, y: midY))
            p.addLine(to: CGPoint(x: r.width - 11, y: midY - 9))
            p.addLine(to: CGPoint(x: r.width - 11, y: midY + 9))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Flag chips

struct FlagBadge: View {
    var language: Language
    var size: CGFloat = 34
    var body: some View {
        Group {
            switch language {
            case .it:
                HStack(spacing: 0) {
                    Color(hex: 0x009246); Color(hex: 0xF1F2F1); Color(hex: 0xCE2B37)
                }
            case .uz:
                VStack(spacing: 0) {
                    Color(hex: 0x0099B5); Color(hex: 0xF2F2F2); Color(hex: 0x1EB53A)
                }
                .overlay(alignment: .topLeading) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: size * 0.16, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.leading, size * 0.14)
                        .padding(.top, size * 0.05)
                }
            }
        }
        .frame(width: size, height: size * 0.72)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1.5)
        )
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
            Text(title).font(.heading(13)).kerning(1.1).foregroundStyle(Palette.inkSoft)
            if let subtitle { Text(subtitle).font(.plain(13)).foregroundStyle(Palette.inkFaint) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
