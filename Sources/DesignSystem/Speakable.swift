import SwiftUI

/// Tap-to-hear, everywhere.
///
/// Nothing written in the language being learnt should sit on screen without a way
/// to hear it, and the tap target is the word itself: tapping one word in a sentence
/// reads that word, not the whole line.

// MARK: - A sentence whose words are each tappable

struct SpeakableText: View {
    @Environment(AppState.self) private var state
    let text: String
    var language: Language
    var font: Font = .body(20)
    var color: Color = Palette.ink
    var alignment: HorizontalAlignment = .leading
    /// Read the whole line when it is tapped somewhere between the words.
    var speakWholeOnLongPress: Bool = true

    private var words: [String] {
        text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    var body: some View {
        // only the language she is learning is worth pronouncing; her own needs no help
        if language == state.target, words.count > 1 {
            WordFlow(lineSpacing: 3, alignment: alignment) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    Button {
                        speak(word)
                    } label: {
                        Text(index == words.count - 1 ? word : word + " ")
                            .font(font)
                            .foregroundStyle(color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(word)
                    .accessibilityHint(S.tapToHear[state.native])
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.35) {
                guard speakWholeOnLongPress else { return }
                speak(text)
            }
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
                .speakOnTap(text, language: language)
        }
    }

    private func speak(_ piece: String) {
        Feedback.tap()
        SpeechService.shared.speak(piece, language: language, rate: state.settings.speechRate)
    }
}

// MARK: - Anything else showing target-language text

private struct SpeakOnTap: ViewModifier {
    @Environment(AppState.self) private var state
    let text: String
    let language: Language?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                guard let language, language == state.target,
                      !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Feedback.tap()
                SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate)
            }
    }
}

extension View {
    /// Reads `text` aloud when this view is tapped — and does nothing at all when the
    /// text is in the learner's own language, or when no language is known.
    func speakOnTap(_ text: String, language: Language?) -> some View {
        modifier(SpeakOnTap(text: text, language: language))
    }
}

/// Speaks a word, for the many places where the tappable control *is* the word:
/// an answer option, a chip, a tile. Silent for the learner's own language.
@MainActor
func speakIfTarget(_ text: String, language: Language, state: AppState) {
    guard language == state.target else { return }
    SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate)
}

// MARK: - Layout

/// A flow layout that hugs its content instead of claiming the full width, so a
/// speech bubble around a tappable sentence still wraps tightly around the words.
private struct WordFlow: Layout {
    var lineSpacing: CGFloat = 3
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                widest = max(widest, x)
                x = 0; y += rowHeight + lineSpacing; rowHeight = 0
            }
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
        widest = max(widest, x)
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, sv) in subviews.enumerated() {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.width, x > 0 {
                rows.append([]); x = 0
            }
            rows[rows.count - 1].append((i, size))
            x += size.width
        }

        var y = bounds.minY
        for row in rows {
            let rowWidth = row.reduce(0) { $0 + $1.size.width }
            let rowHeight = row.map(\.size.height).max() ?? 0
            var cursor: CGFloat
            switch alignment {
            case .center: cursor = bounds.minX + (bounds.width - rowWidth) / 2
            case .trailing: cursor = bounds.maxX - rowWidth
            default: cursor = bounds.minX
            }
            for item in row {
                subviews[item.index].place(at: CGPoint(x: cursor, y: y),
                                           proposal: ProposedViewSize(item.size))
                cursor += item.size.width
            }
            y += rowHeight + lineSpacing
        }
    }
}
