import SwiftUI

/// Tap a word, hear it and see what it means.
///
/// Nothing written in the language being learnt should sit on screen without a way to
/// hear it, and the tap target is the word itself rather than the line. A tap also
/// opens a small card underneath with the meaning of that word — and, when the line is
/// an expression the course teaches as a whole, what the whole thing means, because
/// `ertaga ko'rishguncha` is not "tomorrow until-we-see".

/// What a tapped word turned out to mean.
struct WordHint: Equatable {
    var word: String
    var meaning: String?
    /// Set only when the line means something its words do not add up to.
    var phrase: String?
    var phraseMeaning: String?

    /// Nothing worth opening a card for.
    var isEmpty: Bool { meaning == nil && phraseMeaning == nil }
}

// MARK: - A sentence whose words are each tappable

struct SpeakableText: View {
    @Environment(AppState.self) private var state
    let text: String
    var language: Language
    var font: Font = .body(20)
    var color: Color = Palette.ink
    var alignment: HorizontalAlignment = .leading
    /// Read the whole line when it is held down.
    var speakWholeOnLongPress: Bool = true
    /// Whether a tap may open the meaning card. Off where there is no room for it.
    var showsMeaning: Bool = true
    /// The line to look the expression up under, when what is on screen is not it —
    /// a fill-in-the-blank shows a gap where a word belongs.
    var glossaryText: String?

    @State private var hint: WordHint?
    @State private var looking = false

    private var words: [String] {
        text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            if words.count > 1 {
                WordFlow(lineSpacing: 3, alignment: alignment) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        Button {
                            tapped(word)
                        } label: {
                            Text(index == words.count - 1 ? word : word + " ")
                                .font(font)
                                .foregroundStyle(color)
                                .underline(hint?.word == word, pattern: .dot)
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
                    .contentShape(Rectangle())
                    .onTapGesture { tapped(text) }
            }

            if looking {
                HStack(spacing: 7) {
                    ProgressView().scaleEffect(0.7).tint(Palette.brand)
                    Text(S.lookingUp[state.native])
                        .font(.plain(12)).foregroundStyle(Palette.inkFaint)
                }
                .transition(.opacity)
            } else if let hint, !hint.isEmpty {
                HintCard(hint: hint) { withAnimation(.easeOut(duration: 0.15)) { self.hint = nil } }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func tapped(_ word: String) {
        speak(word)
        guard showsMeaning, state.settings.wordHints else { return }
        // tapping the same word again puts the card away
        if hint?.word == word {
            withAnimation(.easeOut(duration: 0.15)) { hint = nil }
            return
        }
        let found = meaning(of: word)
        if !found.isEmpty {
            withAnimation(.easeOut(duration: 0.15)) { hint = found }
            return
        }
        // the course teaches barely a fifth of its words on their own, so most taps
        // land on something only the assistant can gloss
        guard AIClient.isConfigured(provider: state.aiProvider, key: state.aiKey) else { return }
        hint = nil
        withAnimation(.easeOut(duration: 0.15)) { looking = true }
        Task {
            let found = try? await AIClient.wordMeaning(of: word, inside: glossaryText ?? text,
                                                        language: language, native: state.native,
                                                        provider: state.aiProvider, key: state.aiKey)
            await MainActor.run {
                if let found {
                    state.rememberGloss(found.word, for: word, language: language)
                    if let expression = found.expression, words.count > 1 {
                        state.rememberGloss(expression, for: glossaryText ?? text, language: language)
                    }
                }
                withAnimation(.easeOut(duration: 0.15)) {
                    looking = false
                    hint = found.map {
                        WordHint(word: word, meaning: $0.word,
                                 phrase: $0.expression == nil ? nil : (glossaryText ?? text),
                                 phraseMeaning: $0.expression)
                    }
                }
            }
        }
    }

    /// What the word means, and what the line means when it is more than its words.
    /// The course first, then anything already looked up before — both instant.
    private func meaning(of word: String) -> WordHint {
        var out = WordHint(word: word)
        out.meaning = Glossary.look(up: word, from: language).map(\.text)
                   ?? state.cachedGloss(word, language: language)
        let line = glossaryText ?? text
        if words.count > 1 {
            if let whole = Glossary.look(up: line, from: language), !whole.literal {
                out.phrase = line
                out.phraseMeaning = whole.text
            } else if let remembered = state.cachedGloss(line, language: language) {
                out.phrase = line
                out.phraseMeaning = remembered
            }
        }
        return out
    }

    private func speak(_ piece: String) {
        Feedback.tap()
        guard language == state.target else { return }      // her own language needs no reading
        SpeechService.shared.speak(piece, language: language, rate: state.settings.speechRate)
    }
}

/// The little card under a tapped word.
private struct HintCard: View {
    @Environment(AppState.self) private var state
    let hint: WordHint
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let meaning = hint.meaning {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(hint.word).font(.heading(14)).foregroundStyle(Palette.brand)
                    Text(meaning).font(.body(14)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            // an expression the course teaches whole, not word by word
            if let phrase = hint.phrase, let phraseMeaning = hint.phraseMeaning {
                if hint.meaning != nil { Rectangle().fill(Palette.stroke).frame(height: 1) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(S.wholeExpression[state.native])
                        .font(.heading(9.5)).kerning(0.6).foregroundStyle(Palette.inkFaint)
                    Text("\u{201C}\(phrase)\u{201D}")
                        .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(phraseMeaning)
                        .font(.body(14)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.brand.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.brand.opacity(0.35), lineWidth: 1.5))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityAddTraits(.isButton)
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
