import SwiftUI

/// Tap a word, hear it and see what it means.
///
/// Nothing written in the language being learnt should sit on screen without a way to
/// hear it, and the tap target is the word itself rather than the line. A tap opens a
/// small card underneath with the meaning of **that word** — never of the whole
/// sentence. When the word is part of a set expression the course teaches as a unit,
/// the card says what the expression means, because `xayrli tong` is not
/// "auspicious morning": the expression is lit up in the line, and explained whole.

/// What a tapped word turned out to mean.
struct WordHint: Equatable {
    /// Which word of the line was tapped.
    var index: Int
    var word: String
    var meaning: String?
    /// The dictionary form, when an inflected word was read back to one:
    /// `bordim` → `bormoq`. The meaning is then that form's.
    var base: String?
    /// The set expression the word belongs to, its meaning, and where it sits.
    var phrase: String?
    var phraseMeaning: String?
    var span: ClosedRange<Int>?

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
    /// The line to read a word in, when what is on screen is not it — a
    /// fill-in-the-blank shows a gap where a word belongs.
    var glossaryText: String?

    @State private var hint: WordHint?
    @State private var looking: Int?

    private var words: [String] {
        WordSplitter.words(in: text, language: language)
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            if words.count > 1 {
                WordFlow(lineSpacing: 3, alignment: alignment) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        Button {
                            tapped(index)
                        } label: {
                            Text(index == words.count - 1 || language.isUnspaced ? word : word + " ")
                                .font(font)
                                .foregroundStyle(lit(index) ? Palette.brandDeep : color)
                                .underline(lit(index), pattern: .dot, color: Palette.brand)
                                .background {
                                    if lit(index) {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(Palette.brand.opacity(0.12))
                                            .padding(.horizontal, -3)
                                    }
                                }
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
                // Persian runs right to left: so do its words
                .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
            } else {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture { tapped(0) }
            }

            if language != .en, let rom = Romanisation.of(text) {
                Text(rom)
                    .font(.plain(13.5)).italic()
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if looking != nil {
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

    /// The tapped word, or every word of the expression it belongs to.
    private func lit(_ index: Int) -> Bool {
        guard let hint else { return looking == index }
        if let span = hint.span { return span.contains(index) }
        return hint.index == index
    }

    private func tapped(_ index: Int) {
        guard words.indices.contains(index) || words.isEmpty else { return }
        let word = words.isEmpty ? text : words[index]
        speak(CompositionPlanner.trimPunctuation(word))
        guard showsMeaning, state.settings.wordHints else { return }
        // tapping the same word again puts the card away
        if hint?.index == index {
            withAnimation(.easeOut(duration: 0.15)) { hint = nil }
            return
        }
        Glossary.prime(with: state.curriculum.allPairs + state.curriculum.allDrills,
                       vocabulary: state.curriculum.allLessons.flatMap(\.vocab))
        let found = lookUp(index, word)
        if found.meaning != nil {
            withAnimation(.easeOut(duration: 0.15)) { hint = found }
            return
        }
        // the course teaches barely a fifth of its words on their own, so many taps
        // land on something only the assistant can gloss
        guard AIClient.isConfigured(provider: state.aiProvider, key: state.aiKey) else {
            withAnimation(.easeOut(duration: 0.15)) { hint = found.isEmpty ? nil : found }
            return
        }
        hint = nil
        withAnimation(.easeOut(duration: 0.15)) { looking = index }
        let line = glossaryText ?? text
        Task {
            let answer = try? await AIClient.wordMeaning(of: CompositionPlanner.trimPunctuation(word),
                                                         inside: line,
                                                         language: language, native: state.native,
                                                         provider: state.aiProvider, key: state.aiKey)
            await MainActor.run {
                var result = found
                if let answer {
                    state.rememberGloss(answer.word, for: word, language: language)
                    result.meaning = answer.word
                    result.base = nil
                    if result.phrase == nil, let phrase = answer.phrase, let meaning = answer.phraseMeaning,
                       let span = span(of: phrase, around: index) {
                        state.rememberGloss(meaning, for: phrase, language: language)
                        result.phrase = words[span].joined(separator: " ")
                        result.phraseMeaning = meaning
                        result.span = span
                    }
                }
                withAnimation(.easeOut(duration: 0.15)) {
                    looking = nil
                    hint = result.isEmpty ? nil : result
                }
            }
        }
    }

    /// What the word means, and the expression it belongs to when it belongs to one —
    /// from the course first, then from anything already looked up. Both instant.
    private func lookUp(_ index: Int, _ word: String) -> WordHint {
        var out = WordHint(index: index, word: CompositionPlanner.trimPunctuation(word))
        if let known = Glossary.word(word, from: language) ?? state.cachedGloss(word, language: language) {
            out.meaning = known
        } else if let base = Glossary.base(of: word, from: language) {
            out.meaning = base.meaning
            out.base = base.base
        }
        guard words.count > 1 else { return out }
        if let expression = Glossary.expression(in: words, containing: index, from: language) {
            out.phrase = words[expression.span].joined(separator: " ")
            out.phraseMeaning = expression.meaning
            out.span = expression.span
        } else if let remembered = rememberedExpression(around: index) {
            out.phrase = words[remembered.span].joined(separator: " ")
            out.phraseMeaning = remembered.meaning
            out.span = remembered.span
        }
        return out
    }

    /// An expression the assistant explained once before, anywhere in the app.
    private func rememberedExpression(around index: Int) -> (span: ClosedRange<Int>, meaning: String)? {
        for length in stride(from: min(4, words.count), through: 2, by: -1) {
            for start in max(0, index - length + 1)...min(index, words.count - length) {
                let span = start...(start + length - 1)
                // the whole sentence is never an "expression" of one of its words
                if span.count == words.count && words.count > 3 { continue }
                if let meaning = state.cachedGloss(words[span].joined(separator: " "), language: language) {
                    return (span, meaning)
                }
            }
        }
        return nil
    }

    /// Where an expression the assistant named sits in the line, around the tapped word.
    private func span(of phrase: String, around index: Int) -> ClosedRange<Int>? {
        let key = Grader.normalise(phrase)
        let length = key.split(separator: " ").count
        guard length >= 2, length <= words.count else { return nil }
        for start in max(0, index - length + 1)...min(index, words.count - length) {
            let span = start...(start + length - 1)
            if Grader.normalise(words[span].joined(separator: " ")) == key { return span }
        }
        return nil
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
        VStack(alignment: .leading, spacing: 8) {
            if let meaning = hint.meaning {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(hint.word).font(.heading(15)).foregroundStyle(Palette.brandDeep)
                        Text(meaning).font(.body(15)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    if let base = hint.base {
                        Text("\(S.baseForm[state.native]): \(base)")
                            .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            // an expression the course teaches whole, not word by word
            if let phrase = hint.phrase, let phraseMeaning = hint.phraseMeaning {
                if hint.meaning != nil { Rectangle().fill(Palette.stroke).frame(height: 1) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(S.wholeExpression[state.native])
                        .font(.heading(9.5)).kerning(0.8).foregroundStyle(Palette.inkSoft)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(phrase).font(.heading(15)).foregroundStyle(Palette.brandDeep)
                        Text(phraseMeaning).font(.body(15)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .glass(radius: 16, tint: Palette.brand, material: false, shadow: false)
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
