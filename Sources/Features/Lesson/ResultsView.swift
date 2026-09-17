import SwiftUI

struct ResultsView: View {
    @Environment(AppState.self) private var state
    let results: SessionResults
    let onDone: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Mascot(mood: failedTest ? .sad : .cheer, size: 130)
                .scaleEffect(appear ? 1 : 0.5)
                .rotationEffect(.degrees(appear ? 0 : -18))
                .animation(.spring(response: 0.55, dampingFraction: 0.55), value: appear)

            VStack(spacing: 6) {
                Text(headline)
                    .font(.display(28))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(headlineTint)
                Text(subhead)
                    .font(.heading(16)).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                statCard(title: S.totalXP[state.native], value: "+\(results.xp)",
                         icon: "bolt.fill", tint: Palette.amber)
                statCard(title: S.accuracy[state.native], value: "\(Int(results.accuracy * 100))%",
                         icon: "target", tint: Palette.green)
                statCard(title: S.time[state.native], value: "\(results.minutes)'",
                         icon: "clock.fill", tint: Palette.brand)
            }
            .padding(.horizontal, Metrics.hPad)

            if failedTest {
                EmptyView()
            } else if state.goalProgress >= 1 {
                Label(S.goalReached[state.native], systemImage: "checkmark.seal.fill")
                    .font(.heading(14)).foregroundStyle(Palette.green)
            } else {
                VStack(spacing: 6) {
                    HStack {
                        Text(S.todayProgress[state.native]).font(.heading(12)).foregroundStyle(Palette.inkSoft)
                        Spacer()
                        Text("\(state.xpToday) / \(state.settings.dailyGoal) XP")
                            .font(.heading(12)).foregroundStyle(Palette.inkSoft)
                    }
                    ProgressBar(value: state.goalProgress, tint: Palette.amber, height: 12)
                }
                .padding(.horizontal, Metrics.hPad + 6)
            }

            if !results.mistakes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: S.reviewMistakes[state.native].uppercased())
                    ForEach(results.mistakes.prefix(4)) { pair in
                        HStack {
                            SpeakableText(text: pair[state.target], language: state.target,
                                          font: .body(15))
                            Spacer()
                            Text(pair[state.native]).font(.plain(14)).foregroundStyle(Palette.inkSoft)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.redSoft))
                    }
                }
                .padding(.horizontal, Metrics.hPad)
            }

            Spacer()

            Button { Feedback.pop(); onDone() } label: { Text(S.continueBtn[state.native]) }
                .buttonStyle(.chunky(Palette.green, Palette.greenDeep))
                .padding(.horizontal, Metrics.hPad)
                .padding(.bottom, 20)
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

    private var headlineTint: LinearGradient {
        if failedTest {
            return LinearGradient(colors: [Palette.inkSoft, Palette.inkSoft],
                                  startPoint: .leading, endPoint: .trailing)
        }
        if results.testPassed == true {
            return LinearGradient(colors: [Palette.purple, Palette.brand],
                                  startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [Palette.amber, Palette.pink],
                              startPoint: .leading, endPoint: .trailing)
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.heading(10)).kerning(0.7).foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14, weight: .black))
                Text(value).font(.display(20))
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint))
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.7)).offset(y: 4))
    }
}
