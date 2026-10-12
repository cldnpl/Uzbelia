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
            HStack(spacing: 12) {
                GlassCircleButton(icon: "xmark", size: 42, tint: Palette.inkSoft,
                                  accessibility: S.quit[state.native]) {
                    Feedback.tap(); onQuit()
                }
                ProgressBar(value: Double(revealed) / Double(max(1, dialogue.lines.count)), tint: Palette.purple)
                OrbIcon("text.bubble.fill", accent: .purple, size: 38, symbolScale: 0.42)
            }
            .padding(.horizontal, Metrics.hPad).padding(.vertical, 10)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(S.story[state.native])
                                .font(.heading(14)).foregroundStyle(Palette.inkSoft)
                            Text(dialogue.title[state.native])
                                .font(.display(28)).foregroundStyle(Gradients.title)
                        }
                        .padding(.bottom, 6)

                        ForEach(Array(dialogue.lines.prefix(revealed).enumerated()), id: \.offset) { i, line in
                            lineRow(i, line)
                                .id(i)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
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
            .buttonStyle(.primary(.lilac))
            .padding(.horizontal, Metrics.hPad)
            .padding(.bottom, 14)
        }
        .onAppear { if let first = dialogue.lines.first { speak(first) } }
    }

    private func lineRow(_ i: Int, _ line: DialogueLine) -> some View {
        let mine = i % 2 == 0
        return HStack(alignment: .bottom, spacing: 8) {
            if !mine { Spacer(minLength: 34) }
            if mine {
                Text(String(line.who.prefix(1)).uppercased())
                    .font(.heading(13)).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Gradients.of(.sky)))
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(line.who.uppercased())
                    .font(.heading(10.5)).kerning(0.8)
                    .foregroundStyle(mine ? UnitAccent.sky.deep : UnitAccent.pink.deep)
                SpeakableText(text: line[state.target], language: state.target,
                              font: .body(17.5))
                if translated.contains(i) {
                    Text(line[state.native])
                        .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 14) {
                    Button {
                        Feedback.tap(); speak(line)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill").font(.system(size: 13, weight: .semibold))
                    }
                    Button {
                        Feedback.tap()
                        if translated.contains(i) { translated.remove(i) } else { translated.insert(i) }
                    } label: {
                        Image(systemName: "character.book.closed.fill").font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(Palette.inkSoft)
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                GlassPane(shape: UnevenRoundedRectangle(
                    topLeadingRadius: 22, bottomLeadingRadius: mine ? 6 : 22,
                    bottomTrailingRadius: mine ? 22 : 6, topTrailingRadius: 22,
                    style: .continuous),
                          tint: mine ? nil : Palette.pink, material: false)
            )
            if !mine {
                Text(String(line.who.prefix(1)).uppercased())
                    .font(.heading(13)).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Gradients.of(.pink)))
            }
            if mine { Spacer(minLength: 34) }
        }
    }

    private func speak(_ line: DialogueLine) {
        SpeechService.shared.speak(line[state.target], language: state.target, rate: state.settings.speechRate)
    }
}
