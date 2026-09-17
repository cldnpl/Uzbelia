import SwiftUI

/// Pick a level and call. No topic list: the questions are composed on the spot from
/// the chapter the learner has actually reached in that level.
struct CallHubView: View {
    @Environment(AppState.self) private var state
    @State private var active: CallLaunch?

    private var aiOn: Bool {
        AIClient.isConfigured(provider: state.aiProvider, key: state.aiKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            StatsHeader()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 10) {
                        Mascot(mood: .cheer, size: 58)
                        SpeechBubble {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(S.callTitle[state.native])
                                    .font(.heading(18)).foregroundStyle(Palette.ink)
                                Text(S.callSub[state.native])
                                    .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 6)

                    Label(aiOn ? S.callAIOn[state.native] : S.callAIOff[state.native],
                          systemImage: aiOn ? "sparkles" : "iphone.gen3")
                        .font(.heading(11.5))
                        .foregroundStyle(aiOn ? Palette.purple : Palette.inkFaint)

                    Text(S.callPickLevel[state.native].uppercased())
                        .font(.heading(13)).kerning(1.1).foregroundStyle(Palette.inkSoft)

                    ForEach(CEFR.allCases) { level in
                        levelButton(level)
                    }

                    Label(S.callFreeAnswer[state.native], systemImage: "mic.fill")
                        .font(.plain(12.5)).foregroundStyle(Palette.pink)
                        .padding(.top, 4)

                    Text(S.callNotReal[state.native])
                        .font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Metrics.hPad)
                .padding(.bottom, 26)
            }
        }
        .background(Palette.bg)
        .fullScreenCover(item: $active) { launch in
            VideoCallView(level: launch.level)
        }
    }

    private func levelButton(_ level: CEFR) -> some View {
        let unlocked = state.isLevelUnlocked(level)
        let unit = state.currentUnit(in: level)
        return Button {
            guard unlocked else { return }
            Feedback.pop()
            active = CallLaunch(level: level)
        } label: {
            HStack(spacing: 14) {
                Text(level.label)
                    .font(.display(20)).foregroundStyle(.white)
                    .frame(width: 58, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(unlocked ? Palette.pink : Palette.inkFaint))
                VStack(alignment: .leading, spacing: 3) {
                    Text(level.blurb[state.native])
                        .font(.heading(16)).foregroundStyle(Palette.ink)
                    if unlocked, let unit {
                        Text("\(S.callYouAreAt[state.native]) \(unit.title[state.native])")
                            .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(S.callLevelLocked[state.native])
                            .font(.plain(12.5)).foregroundStyle(Palette.inkFaint)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: unlocked ? "video.fill" : "lock.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(unlocked ? Palette.pink : Palette.inkFaint)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .stroke(unlocked ? Palette.pink.opacity(0.35) : Palette.stroke, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(Palette.stroke).offset(y: 4))
            .opacity(unlocked ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

struct CallLaunch: Identifiable {
    let id = UUID()
    let level: CEFR
}
