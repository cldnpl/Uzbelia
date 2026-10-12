import SwiftUI

/// Pick a level and call. No topic list: the questions are composed on the spot from
/// the chapter the learner has actually reached in that level.
struct CallHubView: View {
    @Environment(AppState.self) private var state
    @State private var active: CallLaunch?
    @State private var breathe = false

    private var aiOn: Bool {
        AIClient.isConfigured(provider: state.aiProvider, key: state.aiKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatsHeader()
                TabHeader(eyebrow: S.callEyebrow[state.native],
                          title: S.callHeadline[state.native],
                          subtitle: S.callHeadlineSub[state.native])

                hero

                SectionHeader(title: S.callPickLevel[state.native].uppercased())
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(CEFR.allCases) { level in
                        levelCard(level)
                    }
                }

                Text(S.callNotReal[state.native])
                    .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.top, 6)
            .padding(.bottom, Metrics.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .background(AuroraBackground(mood: .call))
        .fullScreenCover(item: $active) { launch in
            VideoCallView(level: launch.level)
        }
    }

    /// Anorcha in a breathing pearl, like the speaker of the reference conversation.
    private var hero: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().strokeBorder(Palette.pink.opacity(0.18), lineWidth: 1)
                    .frame(width: 118, height: 118)
                    .scaleEffect(breathe ? 1.06 : 0.96)
                Circle().strokeBorder(Palette.pink.opacity(0.28), lineWidth: 1)
                    .frame(width: 100, height: 100)
                MascotBubble(mood: .cheer, size: 86)
                Image(systemName: "video.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(LinearGradient(colors: Tone.pink.colors,
                                                             startPoint: .top, endPoint: .bottom)))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .offset(x: 32, y: 32)
            }
            .frame(width: 120, height: 120)
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)
            .onAppear { breathe = true }

            VStack(alignment: .leading, spacing: 8) {
                Label(aiOn ? S.callAIOn[state.native] : S.callAIOff[state.native],
                      systemImage: aiOn ? "sparkles" : "iphone.gen3")
                    .font(.heading(12)).foregroundStyle(aiOn ? Palette.purpleDeep : Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Label(S.callFreeAnswer[state.native], systemImage: "mic.fill")
                    .font(.plain(13)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glass(radius: 30, tint: Palette.pink)
    }

    private func levelCard(_ level: CEFR) -> some View {
        let unlocked = state.isLevelUnlocked(level)
        let unit = state.currentUnit(in: level)
        return Button {
            guard unlocked else { return }
            Feedback.pop()
            active = CallLaunch(level: level)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(level.label)
                        .font(.display(20)).foregroundStyle(unlocked ? .white : Palette.inkFaint)
                        .frame(width: 54, height: 44)
                        .background {
                            if unlocked {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(LinearGradient(colors: Tone.pink.colors,
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: Palette.pink.opacity(0.35), radius: 8, y: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.locked)
                            }
                        }
                    Spacer(minLength: 0)
                    Image(systemName: unlocked ? "video.fill" : "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(unlocked ? Palette.pink : Palette.inkFaint)
                        .frame(width: 36, height: 36)
                        .glassCircle(tint: unlocked ? Palette.pink : nil, material: false, shadow: false)
                }
                Text(level.blurb[state.native])
                    .font(.heading(15)).foregroundStyle(Palette.ink)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if unlocked, let unit {
                    Text("\(S.callYouAreAt[state.native]) \(unit.title[state.native])")
                        .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(S.callLevelLocked[state.native])
                        .font(.plain(12)).foregroundStyle(Palette.inkFaint)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .glass(radius: 26)
            .opacity(unlocked ? 1 : 0.6)
        }
        .buttonStyle(.pressable)
        .disabled(!unlocked)
    }
}

struct CallLaunch: Identifiable {
    let id = UUID()
    let level: CEFR
}
