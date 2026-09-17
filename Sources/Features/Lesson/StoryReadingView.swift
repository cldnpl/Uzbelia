import SwiftUI

/// The reading half of a story node: a short dialogue revealed line by line,
/// each one spoken aloud, with translations on demand.
struct StoryReadingView: View {
    @Environment(AppState.self) private var state
    let dialogue: Dialogue
    let onFinish: () -> Void
    let onQuit: () -> Void

    @State private var revealed = 1
    @State private var translated: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { Feedback.tap(); onQuit() } label: {
                    Image(systemName: "xmark").font(.system(size: 19, weight: .black))
                        .foregroundStyle(Palette.inkFaint)
                }
                ProgressBar(value: Double(revealed) / Double(max(1, dialogue.lines.count)), tint: Palette.purple)
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 17, weight: .black)).foregroundStyle(Palette.purple)
            }
            .padding(.horizontal, Metrics.hPad).padding(.vertical, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(dialogue.title[state.native])
                            .font(.display(24)).foregroundStyle(Palette.ink)
                            .padding(.bottom, 4)

                        ForEach(Array(dialogue.lines.prefix(revealed).enumerated()), id: \.offset) { i, line in
                            lineRow(i, line)
                                .id(i)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.bottom, 24)
                }
                .onChange(of: revealed) { _, v in
                    withAnimation { proxy.scrollTo(v - 1, anchor: .bottom) }
                }
            }

            Button {
                Feedback.pop()
                if revealed < dialogue.lines.count {
                    withAnimation(.spring(response: 0.35)) { revealed += 1 }
                    speak(dialogue.lines[revealed - 1])
                } else {
                    onFinish()
                }
            } label: {
                Text(revealed < dialogue.lines.count ? S.continueBtn[state.native] : S.done[state.native])
            }
            .buttonStyle(.chunky(Palette.purple, Palette.purpleDeep))
            .padding(.horizontal, Metrics.hPad)
            .padding(.bottom, 18)
        }
        .background(Palette.bg)
        .onAppear { if let first = dialogue.lines.first { speak(first) } }
    }

    private func lineRow(_ i: Int, _ line: DialogueLine) -> some View {
        let mine = i % 2 == 0
        return HStack(alignment: .top, spacing: 10) {
            if !mine { Spacer(minLength: 30) }
            VStack(alignment: .leading, spacing: 6) {
                Text(line.who.uppercased())
                    .font(.heading(10)).kerning(0.8)
                    .foregroundStyle(mine ? Palette.brand : Palette.pink)
                SpeakableText(text: line[state.target], language: state.target,
                              font: .body(17))
                if translated.contains(i) {
                    Text(line[state.native])
                        .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Button {
                        Feedback.tap(); speak(line)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill").font(.system(size: 13, weight: .bold))
                    }
                    Button {
                        Feedback.tap()
                        if translated.contains(i) { translated.remove(i) } else { translated.insert(i) }
                    } label: {
                        Image(systemName: "character.book.closed.fill").font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(Palette.inkFaint)
                .buttonStyle(.plain)
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(mine ? Palette.card : Palette.purple.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(mine ? Palette.stroke : Palette.purple.opacity(0.3), lineWidth: 2))
            )
            if mine { Spacer(minLength: 30) }
        }
    }

    private func speak(_ line: DialogueLine) {
        SpeechService.shared.speak(line[state.target], language: state.target, rate: state.settings.speechRate)
    }
}
