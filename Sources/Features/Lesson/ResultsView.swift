import SwiftUI

struct ResultsView: View {
    @Environment(AppState.self) private var state
    let results: SessionResults
    let onDone: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 10)

            ZStack {
                if !failedTest {
                    Circle()
                        .fill(Gradients.holo)
                        .frame(width: 190, height: 190)
                        .blur(radius: 24)
                        .opacity(0.75)
                        .rotationEffect(.degrees(appear ? 180 : 0))
                        .animation(.linear(duration: 14).repeatForever(autoreverses: false), value: appear)
                }
                MascotBubble(mood: failedTest ? .sad : .cheer, size: 150)
                    .scaleEffect(appear ? 1 : 0.5)
                    .rotationEffect(.degrees(appear ? 0 : -18))
                    .animation(.spring(response: 0.55, dampingFraction: 0.55), value: appear)
            }

            VStack(spacing: 8) {
                Text(headline)
                    .font(.display(32))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(headlineTint)
                Text(subhead)
                    .font(.heading(16)).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Metrics.hPad)

            HStack(spacing: 10) {
                statCard(title: S.totalXP[state.native], value: "+\(results.xp)",
                         icon: "bolt.fill", accent: .amber)
                statCard(title: S.accuracy[state.native], value: "\(Int(results.accuracy * 100))%",
                         icon: "target", accent: .green)
                statCard(title: S.time[state.native], value: "\(results.minutes)'",
                         icon: "clock.fill", accent: .sky)
            }
            .padding(.horizontal, Metrics.hPad)

            if failedTest {
                EmptyView()
            } else if state.goalProgress >= 1 {
                GlassChip(text: S.goalReached[state.native], icon: "checkmark.seal.fill", tint: Palette.greenDeep)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Text(S.todayProgress[state.native]).font(.heading(12.5)).foregroundStyle(Palette.inkSoft)
                        Spacer()
                        Text("\(state.xpToday) / \(state.settings.dailyGoal) XP")
                            .font(.heading(12.5)).foregroundStyle(Palette.inkSoft)
                    }
                    ProgressBar(value: state.goalProgress, tint: Palette.amber, height: 9)
                }
                .padding(14)
                .glass(radius: 22, material: false)
                .padding(.horizontal, Metrics.hPad)
            }

            if !results.mistakes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: S.reviewMistakes[state.native].uppercased())
                    VStack(spacing: 0) {
                        ForEach(results.mistakes.prefix(4)) { pair in
                            HStack {
                                SpeakableText(text: pair[state.target], language: state.target,
                                              font: .body(15))
                                Spacer()
                                Text(pair[state.native]).font(.plain(14)).foregroundStyle(Palette.inkSoft)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            if pair.id != results.mistakes.prefix(4).last?.id {
                                Divider().overlay(Palette.stroke).padding(.horizontal, 14)
                            }
                        }
                    }
                    .glass(radius: 20, material: false)
                }
                .padding(.horizontal, Metrics.hPad)
            }

            Spacer(minLength: 10)

            Button { Feedback.pop(); onDone() } label: { Text(S.continueBtn[state.native]) }
                .buttonStyle(.primary(failedTest ? .violet : .mint))
                .padding(.horizontal, Metrics.hPad)
                .padding(.bottom, 16)
        }
        .onAppear { appear = true }
    }

    private var failedTest: Bool { results.testPassed == false }

    private var headline: String {
        switch results.testPassed {
        case .some(true): return S.testPassed[state.native]
        case .some(false): return S.testFailed[state.native]
        case nil: return S.lessonDone[state.native]
        }
    }

    private var subhead: String {
        switch results.testPassed {
        case .some(true): return S.testPassedSub[state.native]
        case .some(false): return S.testFailedSub[state.native]
        case nil: return results.accuracy >= 0.9 ? S.goodJob[state.native] : S.keepGoing[state.native]
        }
    }

    private var headlineTint: AnyShapeStyle {
        if failedTest { return AnyShapeStyle(Palette.inkSoft) }
        return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xB49CFF), Color(hex: 0x7B5CF2), Color(hex: 0x5B43C7)],
                                            startPoint: .leading, endPoint: .trailing))
    }

    private func statCard(title: String, value: String, icon: String, accent: UnitAccent) -> some View {
        VStack(spacing: 8) {
            OrbIcon(icon, accent: accent, size: 40, symbolScale: 0.42)
            Text(value).font(.display(22)).foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.heading(10)).kerning(0.6).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glass(radius: 22, tint: accent.main, material: false)
    }
}
