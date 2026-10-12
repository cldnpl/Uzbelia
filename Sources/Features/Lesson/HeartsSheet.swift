import SwiftUI

struct HeartsSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    var onQuit: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<AppState.heartCap, id: \.self) { i in
                    if i < state.hearts {
                        OrbIcon("heart.fill", accent: .purple, size: 44, symbolScale: 0.42)
                    } else {
                        OrbIcon("heart", look: .muted, size: 44, symbolScale: 0.42)
                    }
                }
            }
            .padding(.top, 18)

            Text(state.hearts == 0 ? S.noHearts[state.native] : "\(state.hearts)/\(AppState.heartCap)")
                .font(.display(24)).foregroundStyle(Palette.ink)

            if state.hearts < AppState.heartCap {
                GlassChip(text: "\(S.nextHeartIn[state.native]) \(state.minutesToNextHeart) \(S.minutesShort[state.native])",
                          icon: "clock", tint: Palette.inkSoft)
            }

            if state.hearts == 0 {
                Text(S.noHeartsMsg[state.native])
                    .font(.plain(14.5)).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    Feedback.pop()
                    if state.refillHearts(costingGems: true) { dismiss() }
                } label: { Text(S.refill[state.native]) }
                .buttonStyle(.primary(.violet))
                .disabled(state.gems < 100 || state.hearts == AppState.heartCap)

                if let onQuit {
                    Button { Feedback.tap(); onQuit() } label: { Text(S.quit[state.native]) }
                        .buttonStyle(.glass)
                }
            }
        }
        .padding(Metrics.hPad)
    }
}
