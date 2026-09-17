import SwiftUI

struct HeartsSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    var onQuit: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(0..<AppState.heartCap, id: \.self) { i in
                    Image(systemName: i < state.hearts ? "heart.fill" : "heart")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(i < state.hearts ? Palette.red : Palette.locked)
                }
            }
            .padding(.top, 10)

            Text(state.hearts == 0 ? S.noHearts[state.native] : "\(state.hearts)/\(AppState.heartCap)")
                .font(.heading(20)).foregroundStyle(Palette.ink)

            if state.hearts < AppState.heartCap {
                Text("\(S.nextHeartIn[state.native]) \(state.minutesToNextHeart) \(S.minutesShort[state.native])")
                    .font(.plain(14)).foregroundStyle(Palette.inkSoft)
            }

            if state.hearts == 0 {
                Text(S.noHeartsMsg[state.native])
                    .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    Feedback.pop()
                    if state.refillHearts(costingGems: true) { dismiss() }
                } label: { Text(S.refill[state.native]) }
                .buttonStyle(.chunky(Palette.red, Palette.redDeep))
                .disabled(state.gems < 100 || state.hearts == AppState.heartCap)
                .opacity(state.gems < 100 || state.hearts == AppState.heartCap ? 0.5 : 1)

                if let onQuit {
                    Button { Feedback.tap(); onQuit() } label: { Text(S.quit[state.native]) }
                        .buttonStyle(.chunkyGhost)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.hPad)
        .background(Palette.bgElevated)
    }
}
