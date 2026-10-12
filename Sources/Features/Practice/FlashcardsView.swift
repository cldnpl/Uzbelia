import SwiftUI

extension AppState {
    /// Every word she has met so far, for the flashcards: single words and short
    /// expressions rather than whole sentences, one card per translation.
    var flashcardWords: [Pair] {
        var seen = Set<String>()
        var words: [Pair] = []
        for pack in curriculum.levels {
            for unit in pack.units {
                for lesson in unit.lessons where hasStarted(lesson.id) {
                    for pair in lesson.vocab where pair.wordCount(target) <= 4 {
                        if seen.insert(pair.id).inserted { words.append(pair) }
                    }
                }
            }
        }
        return words
    }

    /// A deck to go through now: what is due comes first, then what is still shaky,
    /// then the rest — each band shuffled, so no two decks run in the same order.
    func flashcardDeck(size: Int = 20) -> [Pair] {
        let words = flashcardWords
        let due = Set(duePairs(limit: 400).map(\.id))
        let overdue = words.filter { due.contains($0.id) }.shuffled()
        let shaky = words.filter { !due.contains($0.id) && strength(of: $0) < 0.5 }.shuffled()
        let solid = words.filter { !due.contains($0.id) && strength(of: $0) >= 0.5 }.shuffled()
        return Array((overdue + shaky + solid).prefix(size))
    }
}

/// Flip a card, say whether you knew it, swipe it away.
///
/// The cards grade the same memory the lessons use: "la sapevo" pushes a word's next
/// review further out, "da ripassare" brings it back soon — so a deck here changes
/// what the mixed review asks next.
struct FlashcardsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var deck: [Pair] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var drag: CGSize = .zero
    @State private var leaving = false
    @State private var known: [Pair] = []
    @State private var again: [Pair] = []
    /// Which side faces up: the language being learnt, or her own.
    @State private var targetFirst = true
    @State private var finished = false
    @State private var streak: StreakMoment?

    private var lang: Language { state.native }
    private var current: Pair? { index < deck.count ? deck[index] : nil }
    /// How far a swipe has to go before letting go sends the card off.
    private let threshold: CGFloat = 110

    var body: some View {
        ZStack {
            AuroraBackground(mood: .practice)
            if finished {
                summary
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                VStack(spacing: 0) {
                    topBar
                    sidePicker
                        .padding(.top, 14)
                    GeometryReader { geo in
                        stack(width: geo.size.width)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.vertical, 18)
                    controls
                        .padding(.bottom, 20)
                }
            }
        }
        .streakCelebration($streak) { dismiss() }
        .onAppear {
            guard deck.isEmpty else { return }
            deck = state.flashcardDeck()
            speakFrontIfTarget()
        }
    }

    // MARK: - Top

    private var topBar: some View {
        HStack(spacing: 14) {
            GlassCircleButton(icon: "xmark", size: 42, tint: Palette.inkSoft) {
                Feedback.tap(); close()
            }
            ProgressBar(value: deck.isEmpty ? 0 : Double(index) / Double(deck.count), tint: Palette.brand)
            Text("\(min(index + 1, max(1, deck.count)))/\(max(1, deck.count))")
                .font(.heading(13)).monospacedDigit()
                .foregroundStyle(Palette.inkSoft)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 8)
    }

    private var sidePicker: some View {
        GlassSegmented(selection: Binding(get: { targetFirst },
                                          set: { new in
                                              guard new != targetFirst else { return }
                                              targetFirst = new
                                              flipped = false
                                              speakFrontIfTarget()
                                          }),
                       options: [true, false]) { first in
            let from = first ? state.target : state.native
            let to = first ? state.native : state.target
            return "\(from.badge) → \(to.badge)"
        }
        .frame(width: 210)
    }

    // MARK: - The cards

    @ViewBuilder
    private func stack(width: CGFloat) -> some View {
        let height = min(width * 1.18, 440)
        if deck.isEmpty {
            VStack(spacing: 14) {
                MascotBubble(mood: .think, size: 90)
                Text(S.notEnoughYet[lang])
                    .font(.plain(15)).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
        } else {
            ZStack {
                // the next two wait underneath, a little smaller and a little lower; every
                // card is the same view whatever its place, so the one below rises into
                // the top spot instead of being swapped for a new one
                ForEach(Array((index..<min(index + 3, deck.count)).reversed()), id: \.self) { position in
                    let depth = position - index
                    let top = depth == 0
                    Flashcard(pair: deck[position], angle: top && flipped ? 180 : 0,
                              targetFirst: targetFirst, native: lang, target: state.target,
                              onSpeak: speak)
                        .overlay { if top { stamp } }
                        .rotationEffect(.degrees(top ? Double(drag.width / 18) : 0), anchor: .bottom)
                        .offset(x: top ? drag.width : 0, y: top ? drag.height * 0.4 : CGFloat(depth) * 16)
                        .scaleEffect(1 - CGFloat(depth) * 0.05)
                        .opacity(depth == 2 ? 0.55 : 1)
                        .gesture(swipe, including: top ? .all : .none)
                        .onTapGesture { if top { flip() } }
                        .allowsHitTesting(top)
                        .frame(width: width, height: height)
                        .zIndex(Double(10 - depth))
                        .transition(.identity)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: index)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: S.flashFlip[lang]) { flip() }
            .accessibilityAction(named: S.flashKnew[lang]) { send(knew: true) }
            .accessibilityAction(named: S.flashAgain[lang]) { send(knew: false) }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !leaving else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !leaving else { return }
                let thrown = value.predictedEndTranslation.width
                if drag.width > threshold || thrown > threshold * 2.4 {
                    send(knew: true)
                } else if drag.width < -threshold || thrown < -threshold * 2.4 {
                    send(knew: false)
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { drag = .zero }
                }
            }
    }

    /// The word written across the card as it is dragged: which way it is going.
    private var stamp: some View {
        let push = min(1, abs(drag.width) / threshold)
        let right = drag.width > 0
        return ZStack(alignment: right ? .topLeading : .topTrailing) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill((right ? Palette.brand : Palette.red).opacity(0.10 * push))
            Text(right ? S.flashKnew[lang].uppercased() : S.flashAgain[lang].uppercased())
                .font(.heading(15)).kerning(1)
                .foregroundStyle(right ? Palette.brandDeep : Palette.redDeep)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .overlay(Capsule().strokeBorder(right ? Palette.brand : Palette.red, lineWidth: 2))
                .rotationEffect(.degrees(right ? -10 : 10))
                .padding(22)
                .opacity(push)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: right ? .topLeading : .topTrailing)
        }
        .allowsHitTesting(false)
    }

    private var controls: some View {
        HStack(spacing: 26) {
            roundButton(icon: "arrow.uturn.backward", size: 64, color: Palette.redDeep,
                        wash: Palette.red, label: S.flashAgain[lang]) { send(knew: false) }
            roundButton(icon: "arrow.left.arrow.right", size: 52, color: Palette.inkSoft,
                        wash: nil, label: S.flashFlip[lang]) { flip() }
            roundButton(icon: "checkmark", size: 64, color: Palette.brandDeep,
                        wash: Palette.brand, label: S.flashKnew[lang]) { send(knew: true) }
        }
        .disabled(current == nil || leaving)
    }

    private func roundButton(icon: String, size: CGFloat, color: Color, wash: Color?, label: String,
                             action: @escaping () -> Void) -> some View {
        VStack(spacing: 7) {
            GlassCircleButton(icon: icon, size: size, tint: color, wash: wash, accessibility: label, action: action)
            Text(label).font(.heading(11.5)).foregroundStyle(Palette.inkSoft)
        }
    }

    // MARK: - Moves

    private func flip() {
        guard current != nil, !leaving else { return }
        Feedback.tap()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.78)) {
            flipped.toggle()
        }
        // the side in the language being learnt is read out when it comes up
        if flipped != targetFirst, let pair = current { speak(pair[state.target]) }
    }

    /// Sends the top card off the side it was pushed towards, grades the word, and
    /// lets the next one rise into its place.
    private func send(knew: Bool) {
        guard let pair = current, !leaving else { return }
        leaving = true
        knew ? Feedback.pop() : Feedback.tap()
        SpeechService.shared.stop()
        withAnimation(.easeIn(duration: 0.22)) {
            drag = CGSize(width: (knew ? 1 : -1) * 620, height: drag.height + 40)
        }
        state.gradePair(pair, correct: knew)
        if knew { known.append(pair) } else { again.append(pair) }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(230))
            var quiet = Transaction()
            quiet.disablesAnimations = true
            withTransaction(quiet) {
                drag = .zero
                flipped = false
            }
            index += 1
            leaving = false
            if index >= deck.count {
                finishDeck()
            } else {
                speakFrontIfTarget()
            }
        }
    }

    private func finishDeck() {
        // a little XP for the work, which also keeps the streak alive
        state.addXP(max(3, known.count), minutes: max(1, deck.count / 8))
        state.save()
        Feedback.celebrate()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { finished = true }
    }

    private func restart(with cards: [Pair]) {
        withAnimation(.easeInOut(duration: 0.3)) {
            deck = cards
            index = 0
            flipped = false
            known = []
            again = []
            finished = false
        }
        speakFrontIfTarget()
    }

    private func close() {
        SpeechService.shared.stop()
        if let moment = state.takeStreakMoment() { streak = moment } else { dismiss() }
    }

    private func speakFrontIfTarget() {
        guard targetFirst, let pair = current else { return }
        speak(pair[state.target])
    }

    private func speak(_ text: String) {
        guard state.effectiveSettings.listeningExercises else { return }
        SpeechService.shared.speak(text, language: state.target, rate: state.settings.speechRate)
    }

    // MARK: - End of the deck

    private var summary: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 10)
            ZStack {
                ArcRing(progress: deck.isEmpty ? 0 : Double(known.count) / Double(deck.count),
                        accent: .purple, lineWidth: 8)
                    .frame(width: 168, height: 168)
                MascotBubble(mood: again.isEmpty ? .cheer : .happy, size: 118)
            }
            VStack(spacing: 8) {
                Text(S.flashDone[lang])
                    .font(.display(28)).foregroundStyle(Gradients.title)
                Text("You knew \(known.count) of \(deck.count).")
                    .font(.heading(16)).foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 10) {
                GlassChip(text: "\(known.count) \(S.flashKnownCount[lang])", icon: "checkmark",
                          tint: Palette.brandDeep)
                GlassChip(text: "\(again.count) \(S.flashAgainCount[lang])", icon: "arrow.uturn.backward",
                          tint: Palette.redDeep)
            }
            Spacer(minLength: 10)
            VStack(spacing: 10) {
                if !again.isEmpty {
                    Button {
                        Feedback.pop(); restart(with: again.shuffled())
                    } label: {
                        Text("Review the \(again.count) you missed")
                    }
                    .buttonStyle(.primary(.violet))
                }
                Button {
                    Feedback.tap(); restart(with: state.flashcardDeck())
                } label: { Text(S.flashNewDeck[lang]) }
                .buttonStyle(PrimaryButtonStyle(tone: again.isEmpty ? .violet : .lilac))
                Button {
                    Feedback.tap(); close()
                } label: { Text(S.done[lang]) }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - One card

/// A card with a word on each face. It turns about its vertical axis, and which face
/// shows is decided by the angle itself, frame by frame, so the swap happens exactly
/// edge-on instead of half-way through a fade.
private struct Flashcard: View, Animatable {
    let pair: Pair
    var angle: Double
    let targetFirst: Bool
    let native: Language
    let target: Language
    let onSpeak: (String) -> Void

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private var showingBack: Bool { angle.truncatingRemainder(dividingBy: 360) > 90 }

    var body: some View {
        ZStack {
            if showingBack {
                face(front: false)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                face(front: true)
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }

    private func face(front: Bool) -> some View {
        // the front is in the language picked above; the back answers it
        let lang = front == targetFirst ? target : native
        let text = pair[lang]
        let other = pair[lang.other]
        return VStack(spacing: 0) {
            HStack {
                Text(lang.name.uppercased())
                    .font(.heading(11.5)).kerning(1.2)
                    .foregroundStyle(Palette.inkSoft)
                Spacer()
                if !front {
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            Spacer(minLength: 12)
            Text(text)
                .font(.display(front ? 36 : 32))
                .foregroundStyle(front ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Gradients.title))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.45)
                .lineLimit(3)
            if lang == target, let rom = pair.rom {
                Text(rom)
                    .font(.plain(16)).italic()
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            if lang == target {
                Button {
                    onSpeak(text)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.brand)
                        .frame(width: 46, height: 46)
                        .glassCircle(tint: Palette.brand, material: false, shadow: false)
                }
                .buttonStyle(PressableStyle(scale: 0.9))
                .padding(.top, 18)
            }
            if !front {
                Rectangle().fill(Palette.stroke).frame(width: 46, height: 2)
                    .clipShape(Capsule())
                    .padding(.vertical, 18)
                HStack(spacing: 10) {
                    Text(other)
                        .font(.body(17)).foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.6)
                    if lang.other == target {
                        Button { onSpeak(other) } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.brand)
                                .frame(width: 34, height: 34)
                                .glassCircle(tint: Palette.brand, material: false, shadow: false)
                        }
                        .buttonStyle(PressableStyle(scale: 0.9))
                    }
                }
                if let hint = pair.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.plain(13)).foregroundStyle(Palette.inkFaint)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
            }
            Spacer(minLength: 12)
            if front {
                Text("Tap to flip")
                    .font(.plain(12.5)).foregroundStyle(Palette.inkFaint)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if !front {
                // the back has a breath of pearl, so the two faces never look alike
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Gradients.holo).opacity(0.28)
            }
        }
        .glass(radius: 34, tint: front ? nil : Palette.brand)
        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}
