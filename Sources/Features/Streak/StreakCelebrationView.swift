import SwiftUI

/// What changed when the streak grew. Shown once, by the screen the work was done on,
/// before that screen closes.
struct StreakMoment: Equatable {
    var from: Int
    var to: Int
    /// A salva-serie covered yesterday.
    var freezeUsed: Bool
    /// Monday to Sunday of this week: the days she worked, today included.
    var week: [Bool]
}

/// The warm colours of the streak. The one place the app steps out of the violet on
/// purpose: a streak is a fire, and a violet fire just looks like a mistake.
enum Ember {
    static let tip  = Color(hex: 0xFFD27A)
    static let body = Color(hex: 0xFF9F5A)
    static let root = Color(hex: 0xEE6A78)
    static let core = Color(hex: 0xFFF6E0)
    static let coreMid = Color(hex: 0xFFE2A8)
    static let coreRoot = Color(hex: 0xFFC07A)

    static let fill = LinearGradient(colors: [tip, body, root], startPoint: .top, endPoint: .bottom)
    static let coreFill = LinearGradient(colors: [core, coreMid, coreRoot], startPoint: .top, endPoint: .bottom)
}

// MARK: - The screen

/// The day's streak, celebrated: the flame catches, the count rolls over to the new
/// number, and today's day of the week fills in and gets its tick.
///
/// Everything is timed by hand rather than left to one big spring, so each beat lands
/// on its own — and with Reduce Motion on, it all simply appears.
struct StreakCelebrationView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let moment: StreakMoment
    let onContinue: () -> Void

    @State private var lit = false
    @State private var breath = false
    @State private var shown: Int
    @State private var weekIn = false
    @State private var todayFilled = false
    @State private var todayTicked = false
    @State private var textIn = false
    @State private var lightTime = Date.distantFuture

    init(moment: StreakMoment, onContinue: @escaping () -> Void) {
        self.moment = moment
        self.onContinue = onContinue
        // a streak that starts over rolls up from nothing, never down from the old one
        _shown = State(initialValue: moment.to > moment.from ? moment.from : max(0, moment.to - 1))
    }

    private var lang: Language { state.native }

    var body: some View {
        ZStack {
            AuroraBackground(mood: .celebrate)

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                flame
                    .frame(width: 300, height: 250)

                Text("\(shown)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(shown)))
                    .opacity(lit ? 1 : 0)
                    .padding(.top, 2)

                Text(moment.to == 1 ? S.streakDay[lang] : S.streakDays[lang])
                    .font(.heading(19))
                    .foregroundStyle(Palette.inkSoft)
                    .opacity(lit ? 1 : 0)
                    .offset(y: lit ? 0 : 6)

                week
                    .padding(.top, 30)
                    .padding(.horizontal, Metrics.hPad)

                Text(message)
                    .font(.plain(15.5))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                    .padding(.top, 20)
                    .opacity(textIn ? 1 : 0)
                    .offset(y: textIn ? 0 : 8)

                Spacer(minLength: 20)

                Button {
                    Feedback.tap(); onContinue()
                } label: { Text(S.continueBtn[lang]) }
                .buttonStyle(.primary(.violet))
                .padding(.horizontal, Metrics.hPad)
                .padding(.bottom, 16)
                .opacity(textIn ? 1 : 0)
                .allowsHitTesting(textIn)
            }
        }
        .task { await play() }
    }

    // MARK: - The flame

    private var flame: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || !lit)) { context in
            // seconds since the flame caught, for the flicker and the sparks
            let t = max(0, context.date.timeIntervalSince(lightTime))
            let calm = reduceMotion ? 0.0 : 1.0
            // two slow waves and a quick one: never quite periodic, never jittery
            let sway = CGFloat((sin(t * 2.3) * 0.5 + sin(t * 5.3 + 0.7) * 0.16) * calm)
            let lift = CGFloat((sin(t * 3.1 + 1.3) * 0.6 + sin(t * 7.7) * 0.15) * calm)

            ZStack(alignment: .bottom) {
                // the warmth around it
                Circle()
                    .fill(RadialGradient(colors: [Ember.body.opacity(0.42), Ember.root.opacity(0.14), .clear],
                                         center: .center, startRadius: 8, endRadius: 150))
                    .frame(width: 300, height: 300)
                    .scaleEffect(1 + 0.035 * CGFloat(sin(t * 1.9)) * calm)
                    .offset(y: 70)

                // the puff of air when it catches
                Circle()
                    .strokeBorder(Ember.body.opacity(0.55), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(breath ? 1.9 : 0.5)
                    .opacity(breath ? 0 : 0.9)
                    .offset(y: -10)

                if !reduceMotion {
                    Sparks(time: t)
                        .frame(width: 200, height: 240)
                        .opacity(lit ? 1 : 0)
                }

                FlameShape(sway: sway, lift: lift)
                    .fill(Ember.fill)
                    .frame(width: 150, height: 200)
                    .shadow(color: Ember.root.opacity(0.35), radius: 18, y: 10)

                FlameShape(sway: sway * 1.35, lift: lift * 0.8)
                    .fill(Ember.coreFill)
                    .frame(width: 76, height: 104)
                    .offset(x: 3, y: -2)
            }
            .frame(width: 300, height: 250, alignment: .bottom)
        }
        .scaleEffect(lit ? 1 : 0.06, anchor: .bottom)
        .opacity(lit ? 1 : 0)
    }

    // MARK: - The week

    private var todayIndex: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        // weekday: 1 = Sunday … 7 = Saturday; Monday first
        return (calendar.component(.weekday, from: .now) + 5) % 7
    }

    private var letters: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var week: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 9) {
                    Text(letters[i])
                        .font(.heading(12.5))
                        .foregroundStyle(i == todayIndex ? Palette.ink : Palette.inkFaint)
                    dayDot(i)
                        .frame(width: 32, height: 32)
                }
                .frame(maxWidth: .infinity)
                .opacity(weekIn ? 1 : 0)
                .offset(y: weekIn ? 0 : 10)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)
                                                 .delay(Double(i) * 0.045),
                           value: weekIn)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .glass(radius: 26, material: false)
    }

    @ViewBuilder
    private func dayDot(_ i: Int) -> some View {
        let worked = i < moment.week.count && moment.week[i]
        if i == todayIndex {
            ZStack {
                Circle().strokeBorder(Ember.body.opacity(0.45), lineWidth: 2)
                Circle()
                    .fill(Ember.fill)
                    .scaleEffect(todayFilled ? 1 : 0.01)
                    .shadow(color: Ember.root.opacity(todayFilled ? 0.35 : 0), radius: 8, y: 3)
                Tick()
                    .trim(from: 0, to: todayTicked ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                    .padding(8)
            }
        } else if worked {
            ZStack {
                Circle().fill(Ember.fill).opacity(0.9)
                Tick()
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .padding(8)
            }
        } else {
            Circle()
                .strokeBorder(i < todayIndex ? Palette.strokeDeep : Palette.locked, lineWidth: 2)
        }
    }

    // MARK: - Words

    private var message: String {
        let n = moment.to
        if moment.freezeUsed { return "A streak freeze covered the day you missed. The flame is still burning." }
        if n == 1 { return "The flame is lit. Come back tomorrow to keep it burning." }
        if n % 7 == 0 && n <= 28 { return "\(n / 7 == 1 ? "A whole week" : "\(n / 7) weeks"), without missing a day." }
        if n >= 30 && n % 10 == 0 { return "\(n) days: it's a habit now." }
        return "One more day. See you tomorrow."
    }

    // MARK: - Timing

    private func play() async {
        if reduceMotion {
            lit = true; shown = moment.to; weekIn = true
            todayFilled = true; todayTicked = true; textIn = true
            Feedback.success()
            return
        }
        try? await Task.sleep(for: .milliseconds(220))
        lightTime = .now
        withAnimation(.spring(response: 0.62, dampingFraction: 0.62)) { lit = true }
        withAnimation(.easeOut(duration: 1.1)) { breath = true }
        Feedback.pop()

        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { shown = moment.to }
        Feedback.success()

        try? await Task.sleep(for: .milliseconds(380))
        weekIn = true

        try? await Task.sleep(for: .milliseconds(520))
        withAnimation(.spring(response: 0.42, dampingFraction: 0.66)) { todayFilled = true }
        try? await Task.sleep(for: .milliseconds(170))
        withAnimation(.easeOut(duration: 0.32)) { todayTicked = true }
        Feedback.tap()

        try? await Task.sleep(for: .milliseconds(260))
        withAnimation(.easeOut(duration: 0.5)) { textIn = true }
    }
}

// MARK: - Shapes

/// A flame drawn rather than borrowed: a teardrop that leans to the right, with a
/// second, smaller tongue licking up on its left. `sway` bends the tip sideways and
/// `lift` stretches it, both roughly within -1...1.
struct FlameShape: Shape {
    var sway: CGFloat = 0
    var lift: CGFloat = 0

    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
        }
        let tip = p(0.54 + sway * 0.10, -lift * 0.03)
        var path = Path()
        path.move(to: p(0.5, 1.0))
        // the right flank, full and round at the bottom
        path.addCurve(to: p(0.94, 0.62), control1: p(0.80, 1.0), control2: p(0.97, 0.83))
        // up to the tip
        path.addCurve(to: tip, control1: p(0.91, 0.42), control2: p(0.68 + sway * 0.05, 0.24))
        // down the left side, into the notch of the second tongue
        path.addCurve(to: p(0.36, 0.43), control1: p(0.50 + sway * 0.04, 0.18), control2: p(0.41, 0.30))
        // the second tongue
        path.addCurve(to: p(0.19 + sway * 0.03, 0.25 - lift * 0.02),
                      control1: p(0.31, 0.38), control2: p(0.24, 0.33))
        path.addCurve(to: p(0.07, 0.68), control1: p(0.08, 0.40), control2: p(0.04, 0.55))
        // and round again to the base
        path.addCurve(to: p(0.5, 1.0), control1: p(0.10, 0.88), control2: p(0.25, 1.0))
        path.closeSubpath()
        return path
    }
}

/// A check mark as a single stroke, so it can be drawn on with `trim`.
private struct Tick: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.54))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.78))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.86, y: r.minY + r.height * 0.26))
        return path
    }
}

/// A handful of embers drifting up off the flame. Each one has its own rate and its
/// own path, worked out from its index, so the pattern never visibly repeats.
private struct Sparks: View {
    var time: Double

    var body: some View {
        Canvas { context, size in
            for i in 0..<10 {
                let seed = Double(i) * 1.618_034
                let period = 1.5 + seed.truncatingRemainder(dividingBy: 1) * 1.3
                let phase = ((time + seed * 0.83) / period).truncatingRemainder(dividingBy: 1)
                let startX = size.width / 2 + CGFloat(sin(seed * 3.1)) * 38
                let x = startX + CGFloat(sin(time * 2.1 + seed)) * 12 * CGFloat(phase)
                let y = size.height * 0.66 - CGFloat(phase) * size.height * 0.62
                let radius = CGFloat(1.4 + (sin(seed * 7) + 1) * 0.9) * CGFloat(1 - phase * 0.6)
                let fadeIn = min(1, phase / 0.15)
                context.opacity = fadeIn * (1 - phase) * 0.95
                let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                 width: radius * 2, height: radius * 2))
                context.fill(dot, with: .color(i % 3 == 0 ? Ember.tip : Ember.body))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Showing it

extension View {
    /// Lays the streak celebration over this screen while `moment` is set; `onDone`
    /// runs when she taps Continue, after the moment has been cleared.
    func streakCelebration(_ moment: Binding<StreakMoment?>, onDone: @escaping () -> Void) -> some View {
        overlay {
            if let m = moment.wrappedValue {
                StreakCelebrationView(moment: m) {
                    moment.wrappedValue = nil
                    onDone()
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: moment.wrappedValue)
    }
}
