import SwiftUI

// MARK: - Router

struct ExerciseHost: View {
    let exercise: Exercise
    @Bindable var engine: LessonEngine

    var body: some View {
        switch exercise.kind {
        case .choice:        ChoiceExercise(ex: exercise, engine: engine)
        case .listenChoice,
             .listenMeaning: ListenChoiceExercise(ex: exercise, engine: engine)
        case .wordBank:      WordBankExercise(ex: exercise, engine: engine, listening: false)
        case .listenBuild:   WordBankExercise(ex: exercise, engine: engine, listening: true)
        case .type:          TypeExercise(ex: exercise, engine: engine, listening: false)
        case .listenType:    TypeExercise(ex: exercise, engine: engine, listening: true)
        case .speak:         SpeakExercise(ex: exercise, engine: engine, repeating: false)
        case .speakRepeat:   SpeakExercise(ex: exercise, engine: engine, repeating: true)
        case .match:         MatchExercise(ex: exercise, engine: engine)
        case .fillBlank:     FillBlankExercise(ex: exercise, engine: engine)
        case .compose:       ComposeExercise(ex: exercise, engine: engine)
        }
    }
}

// MARK: - Shared pieces

/// The sentence being asked about, on a pane of glass, with Anorcha in the corner
/// and the audio within reach.
struct PromptCard: View {
    @Environment(AppState.self) private var state
    var text: String
    var language: Language
    var speakable: Bool = true
    var mood: Mascot.Mood = .happy

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                MascotBubble(mood: mood, size: 42)
                FlagBadge(language: language, size: 22)
                Spacer(minLength: 0)
                if speakable && language == state.target {
                    AudioButtons(text: text, language: language, compact: true)
                }
            }
            SpeakableText(text: text, language: language, font: .body(23))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 28)
    }
}

struct AudioButtons: View {
    @Environment(AppState.self) private var state
    var text: String
    var language: Language
    var compact: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            GlassCircleButton(icon: "speaker.wave.2.fill", size: compact ? 38 : 46, tint: Palette.brand,
                              accessibility: S.listenAgain[state.native]) {
                Feedback.tap()
                SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate)
            }
            GlassCircleButton(icon: "tortoise.fill", size: compact ? 38 : 46, tint: Palette.inkSoft,
                              accessibility: S.slowly[state.native]) {
                Feedback.tap()
                SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate, slow: true)
            }
        }
    }
}

/// One tappable answer option: a pane of glass with a violet ring when chosen, filled
/// violet with a white tick when right, washed in soft rose when wrong.
struct OptionRow: View {
    var text: String
    var selected: Bool
    var state: OptionState = .idle
    var index: Int?
    var action: () -> Void

    enum OptionState { case idle, right, wrong }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                if let index {
                    Text("\(index + 1)")
                        .font(.heading(13))
                        .foregroundStyle(state == .right ? Palette.brandDeep : (accent ?? Palette.inkSoft))
                        .frame(width: 28, height: 28)
                        .background {
                            if state == .right {
                                Circle().fill(.white)
                            } else {
                                GlassPane(shape: Circle(), tint: accent, material: false, shadow: false)
                            }
                        }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                        .font(.body(17))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let rom = Romanisation.of(text) {
                        Text(rom)
                            .font(.plain(12.5)).italic()
                            .foregroundStyle(textColor.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if state == .right {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.red)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { OptionSurface(state: state, selected: selected, radius: 22) }
        }
        .buttonStyle(.pressable)
    }

    private var accent: Color? {
        switch state {
        case .right: return Palette.brand
        case .wrong: return Palette.red
        case .idle: return selected ? Palette.brand : nil
        }
    }
    private var textColor: Color {
        switch state {
        case .right: return .white
        case .wrong: return Palette.redDeep
        case .idle: return Palette.ink
        }
    }
}

/// The surface under an answer: clear glass, glass with a violet ring, solid violet,
/// or soft rose.
struct OptionSurface<S: InsettableShape>: View {
    var state: OptionRow.OptionState
    var selected: Bool
    var shape: S

    var body: some View {
        switch state {
        case .right:
            shape.fill(Gradients.primary)
                .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.3), .clear],
                                                   startPoint: .top, endPoint: .center)))
                .overlay(shape.strokeBorder(.white.opacity(0.45), lineWidth: 1))
                .shadow(color: Palette.brand.opacity(0.35), radius: 12, y: 6)
        case .wrong:
            GlassPane(shape: shape, tint: Palette.red, material: false)
                .overlay(shape.strokeBorder(Palette.red.opacity(0.6), lineWidth: 1.6))
        case .idle:
            GlassPane(shape: shape, tint: selected ? Palette.brand : nil, material: false)
                .overlay {
                    if selected { shape.strokeBorder(Palette.brand.opacity(0.75), lineWidth: 1.8) }
                }
        }
    }
}

extension OptionSurface where S == RoundedRectangle {
    init(state: OptionRow.OptionState, selected: Bool, radius: CGFloat) {
        self.init(state: state, selected: selected,
                  shape: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Multiple choice

struct ChoiceExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PromptCard(text: ex.prompt, language: ex.promptLanguage)
            VStack(spacing: 10) {
                ForEach(Array(ex.options.enumerated()), id: \.element) { i, opt in
                    OptionRow(text: opt,
                              selected: engine.chosen == opt,
                              state: optionState(opt),
                              index: i) {
                        Feedback.tap()
                        // an option in the language she is learning is always worth
                        // hearing, whether or not the question is already answered
                        speakIfTarget(opt, language: ex.answerLanguage, state: state)
                        guard engine.verdict == nil else { return }
                        engine.chosen = opt
                    }
                }
            }
        }
    }

    private func optionState(_ opt: String) -> OptionRow.OptionState {
        guard let v = engine.verdict else { return .idle }
        if Grader.normalise(opt) == Grader.normalise(ex.answer) { return .right }
        if engine.chosen == opt, case .wrong = v { return .wrong }
        return .idle
    }
}

// MARK: - Listening → choice (what was said, or what it means)

struct ListenChoiceExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine
    @State private var played = false

    var body: some View {
        VStack(spacing: 22) {
            BigSpeakerButton(text: ex.audioText ?? ex.answer, language: ex.audioLanguage ?? state.target)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            VStack(spacing: 10) {
                ForEach(Array(ex.options.enumerated()), id: \.element) { i, opt in
                    OptionRow(text: opt,
                              selected: engine.chosen == opt,
                              state: optionState(opt),
                              index: i) {
                        Feedback.tap()
                        speakIfTarget(opt, language: ex.answerLanguage, state: state)
                        guard engine.verdict == nil else { return }
                        engine.chosen = opt
                    }
                }
            }
        }
        .onAppear {
            guard !played else { return }
            played = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                SpeechService.shared.speak(ex.audioText ?? ex.answer,
                                           language: ex.audioLanguage ?? state.target,
                                           rate: state.settings.speechRate)
            }
        }
    }

    private func optionState(_ opt: String) -> OptionRow.OptionState {
        guard let v = engine.verdict else { return .idle }
        if Grader.normalise(opt) == Grader.normalise(ex.answer) { return .right }
        if engine.chosen == opt, case .wrong = v { return .wrong }
        return .idle
    }
}

/// The big soft speaker of the reference: a pearl of glass with rings around it, and
/// a little violet badge to hear it again slowly.
struct BigSpeakerButton: View {
    @Environment(AppState.self) private var state
    var text: String
    var language: Language
    var size: CGFloat = 148
    @State private var ring = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                Feedback.pop()
                SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate)
                ring.toggle()
            } label: {
                ZStack {
                    Circle().strokeBorder(Palette.brand.opacity(0.10), lineWidth: 1)
                        .frame(width: size * 1.32, height: size * 1.32)
                    Circle().strokeBorder(Palette.brand.opacity(0.16), lineWidth: 1)
                        .frame(width: size * 1.14, height: size * 1.14)
                    Circle()
                        .fill(RadialGradient(colors: [Color.dynamic(.white, Color(hex: 0x2B2950)),
                                                      Color.dynamic(Color(hex: 0xF1EEFF), Color(hex: 0x1E1C3A))],
                                             center: UnitPoint(x: 0.35, y: 0.3),
                                             startRadius: 4, endRadius: size * 0.7))
                        .overlay(Circle().strokeBorder(Palette.glassRim, lineWidth: 1.5))
                        .shadow(color: Palette.brand.opacity(0.22), radius: 26, y: 14)
                        .frame(width: size, height: size)
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: size * 0.27, weight: .bold))
                        .foregroundStyle(Gradients.primary)
                        .symbolEffect(.bounce, value: ring)
                }
            }
            .buttonStyle(PressableStyle(scale: 0.95))
            .accessibilityLabel(S.listenAgain[state.native])

            Button {
                Feedback.tap()
                SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate, slow: true)
            } label: {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Gradients.primary))
                    .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
                    .shadow(color: Palette.brand.opacity(0.4), radius: 8, y: 4)
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel(S.slowly[state.native])
            .offset(x: -size * 0.02, y: -size * 0.04)
        }
        .frame(width: size * 1.32, height: size * 1.18)
    }
}

// MARK: - Word bank (from the written prompt, or from what she hears)

struct WordBankExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine
    var listening: Bool
    @State private var played = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if listening {
                BigSpeakerButton(text: ex.audioText ?? ex.answer,
                                 language: ex.audioLanguage ?? state.target, size: 124)
                    .frame(maxWidth: .infinity)
            } else {
                PromptCard(text: ex.prompt, language: ex.promptLanguage)
            }

            // answer tray
            ZStack(alignment: .topLeading) {
                VStack(spacing: 50) {
                    DashedLine()
                    DashedLine()
                }
                .padding(.top, 50)
                .padding(.horizontal, 6)

                ChipFlow(items: engine.built.map { (id: $0, text: ex.tokens[$0]) }) { item in
                    Feedback.tap()
                    speakIfTarget(item.text, language: ex.answerLanguage, state: state)
                    guard engine.verdict == nil else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        engine.built.removeAll { $0 == item.id }
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(12)
            .glass(radius: 24, material: false, shadow: false)
            // a Persian answer is built from the right
            .environment(\.layoutDirection, ex.answerLanguage.isRightToLeft ? .rightToLeft : .leftToRight)

            // bank: a ghost stays where a chip was taken, so nothing jumps around
            FlowLayout(spacing: 9, lineSpacing: 10) {
                ForEach(Array(ex.tokens.enumerated()), id: \.offset) { i, token in
                    let used = engine.built.contains(i)
                    Button {
                        guard !used else { return }
                        Feedback.tap()
                        speakIfTarget(token, language: ex.answerLanguage, state: state)
                        guard engine.verdict == nil else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { engine.built.append(i) }
                    } label: {
                        WordChip(text: token, ghost: used)
                    }
                    .buttonStyle(PressableStyle(scale: 0.94))
                    .disabled(used)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            guard listening, !played else { return }
            played = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                SpeechService.shared.speak(ex.audioText ?? ex.answer,
                                           language: ex.audioLanguage ?? state.target,
                                           rate: state.settings.speechRate)
            }
        }
    }
}

/// A word on a glass capsule. As a ghost, it keeps its place and shows nothing.
struct WordChip: View {
    var text: String
    var ghost: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            Text(text)
                .font(.body(17))
                .foregroundStyle(Palette.ink)
            // a tile in a script she is still learning to read says how it sounds
            if let rom = Romanisation.of(CompositionPlanner.trimPunctuation(text)) {
                Text(rom)
                    .font(.plain(10.5)).italic()
                    .foregroundStyle(Palette.inkSoft)
            }
        }
            .opacity(ghost ? 0 : 1)
            .padding(.horizontal, 15).padding(.vertical, 10)
            .background {
                if ghost {
                    Capsule().fill(Palette.locked.opacity(0.7))
                } else {
                    GlassPane(shape: Capsule(), tint: nil, material: false)
                }
            }
    }
}

private struct DashedLine: View {
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 1)
            .overlay(
                Line().stroke(Palette.strokeDeep, style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
            )
    }
    private struct Line: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p
        }
    }
}

struct ChipFlow: View {
    var items: [(id: Int, text: String)]
    var onTap: ((id: Int, text: String)) -> Void

    var body: some View {
        FlexibleStack(data: items, spacing: 9, lineSpacing: 10) { item in
            Button { onTap(item) } label: {
                WordChip(text: item.text)
            }
            .buttonStyle(PressableStyle(scale: 0.94))
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}

/// Minimal flow layout that wraps its children.
struct FlexibleStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    var data: Data
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    @ViewBuilder var content: (Data.Element) -> Content

    var body: some View {
        FlowLayout(spacing: spacing, lineSpacing: lineSpacing) {
            ForEach(data) { content($0) }
        }
    }
}

extension FlexibleStack where Data == [IdentifiedToken] {
    init(data: [(id: Int, text: String)], spacing: CGFloat, lineSpacing: CGFloat,
         @ViewBuilder content: @escaping ((id: Int, text: String)) -> Content) {
        self.data = data.map { IdentifiedToken(id: $0.id, text: $0.text) }
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = { token in content((id: token.id, text: token.text)) }
    }
}

struct IdentifiedToken: Identifiable, Hashable {
    let id: Int
    let text: String
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + lineSpacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + lineSpacing; rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Typing (also used for dictation)

struct TypeExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine
    var listening: Bool
    @FocusState private var focused: Bool
    @State private var played = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if listening {
                BigSpeakerButton(text: ex.audioText ?? ex.answer,
                                 language: ex.audioLanguage ?? state.target, size: 124)
                    .frame(maxWidth: .infinity)
            } else {
                PromptCard(text: ex.prompt, language: ex.promptLanguage, mood: .think)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    FlagBadge(language: ex.answerLanguage, size: 20)
                    Text(ex.answerLanguage.name)
                        .font(.heading(12.5)).foregroundStyle(Palette.inkSoft)
                }
                TextField(S.typeHere[state.native], text: $engine.typed, axis: .vertical)
                    .font(.body(19))
                    .foregroundStyle(Palette.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(2...5)
                    .focused($focused)
                    .disabled(engine.verdict != nil)
            }
            .padding(16)
            .glass(radius: 24, tint: focused ? Palette.brand : nil)
        }
        .onAppear {
            focused = true
            guard listening, !played else { return }
            played = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                SpeechService.shared.speak(ex.audioText ?? ex.answer,
                                           language: ex.audioLanguage ?? state.target,
                                           rate: state.settings.speechRate)
            }
        }
    }
}

/// Quick access to the Uzbek letters that are awkward on an Italian keyboard.
struct UzbekKeyRow: View {
    var onKey: (String) -> Void
    private let keys = ["o'", "g'", "sh", "ch", "ng", "'"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(keys, id: \.self) { k in
                Button {
                    Feedback.tap(); onKey(k)
                } label: {
                    Text(k)
                        .font(.body(16)).foregroundStyle(Palette.brand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .glassCapsule(tint: Palette.brand, material: false, shadow: false)
                }
                .buttonStyle(PressableStyle(scale: 0.92))
            }
        }
    }
}

// MARK: - Speaking (read it aloud, or hear it and say it back)

struct SpeakExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine
    var repeating: Bool
    @State private var recognizer = RecognizerService.shared
    @State private var recording = false
    @State private var showText = false
    @State private var played = false

    private var approximate: Bool { !recognizer.isExact(for: state.target) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if repeating {
                repeatCard
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        MascotBubble(mood: .cheer, size: 42)
                        Spacer(minLength: 0)
                        AudioButtons(text: ex.prompt, language: state.target)
                    }
                    SpeakableText(text: ex.prompt, language: ex.promptLanguage, font: .body(24))
                    if let hint = ex.hint {
                        Text(hint).font(.plain(14)).foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glass(radius: 28)
            }

            VStack(spacing: 14) {
                micButton
                status
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            guard repeating, !played else { return }
            played = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                SpeechService.shared.speak(ex.prompt, language: state.target, rate: state.settings.speechRate)
            }
        }
        .onChange(of: engine.verdict) { _, v in if v != nil { showText = true } }
        .onDisappear { recognizer.reset() }
    }

    /// "Listen and repeat": the sentence is heard, not read — it stays hidden until
    /// she asks for it or has answered.
    private var repeatCard: some View {
        VStack(spacing: 14) {
            BigSpeakerButton(text: ex.prompt, language: state.target, size: 118)
            Group {
                if showText {
                    VStack(spacing: 4) {
                        SpeakableText(text: ex.prompt, language: state.target, font: .body(20),
                                      alignment: .center)
                        if let hint = ex.hint {
                            Text(hint).font(.plain(13.5)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Button {
                        Feedback.tap()
                        withAnimation(.spring(response: 0.3)) { showText = true }
                    } label: {
                        Label("Show the text",
                              systemImage: "eye")
                            .font(.heading(13))
                            .foregroundStyle(Palette.inkSoft)
                            .padding(.horizontal, 14).frame(height: 36)
                            .glassCapsule(material: false, shadow: false)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var status: some View {
        if recognizer.status == .listening {
            VStack(spacing: 6) {
                Text(S.listening[state.native])
                    .font(.heading(14)).foregroundStyle(UnitAccent.speaking.deep)
                // the words appear as she says them, not all at once at the end
                if !recognizer.transcript.isEmpty {
                    Text(recognizer.transcript)
                        .font(.body(17)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .opacity(recognizer.isPartial ? 0.65 : 1)
                        .animation(.easeOut(duration: 0.15), value: recognizer.transcript)
                        .padding(.horizontal, 20)
                }
            }
        } else if recognizer.isTranscribing {
            HStack(spacing: 7) {
                ProgressView().tint(UnitAccent.speaking.main).scaleEffect(0.8)
                Text(S.transcribing[state.native])
                    .font(.heading(14)).foregroundStyle(UnitAccent.speaking.deep)
            }
        } else if !recognizer.transcript.isEmpty {
            VStack(spacing: 4) {
                Text(S.heardYou[state.native]).font(.plain(12)).foregroundStyle(Palette.inkFaint)
                Text(recognizer.transcript).font(.body(16)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .glass(radius: 18, material: false, shadow: false)
        } else {
            Text(S.tapToSpeak[state.native])
                .font(.plain(14)).foregroundStyle(Palette.inkSoft)
        }

        if recognizer.status == .denied {
            Text("Microphone not allowed. Turn it on in Settings.")
                .font(.plain(12)).foregroundStyle(Palette.red).multilineTextAlignment(.center)
        } else if approximate {
            Text(S.approximateRecog[state.native])
                .font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
                .multilineTextAlignment(.center)
        }
    }

    private var micButton: some View {
        Button {
            Feedback.pop()
            if recording { stopRecording() } else { startRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [UnitAccent.speaking.main.opacity(0.35), .clear],
                                         center: .center, startRadius: 40, endRadius: 90))
                    .frame(width: 170 + CGFloat(recognizer.level * 50),
                           height: 170 + CGFloat(recognizer.level * 50))
                    .opacity(recording ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: recognizer.level)
                OrbIcon(recording ? "stop.fill" : "mic.fill",
                        accent: recording ? .red : .speaking, size: 104, symbolScale: 0.34)
            }
            .frame(width: 180, height: 150)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .disabled(engine.verdict != nil || recognizer.isTranscribing)
    }

    private func startRecording() {
        recognizer.reset()
        recording = true
        Task { await recognizer.start(language: state.target) }
    }

    private func stopRecording() {
        recording = false
        // waits for the on-device recogniser's last words, or for the Uzbek transcript
        // to come back — either way the score is only computed once the words are in
        Task {
            await recognizer.stopAndTranscribe()
            let score = Grader.pronunciationScore(transcript: recognizer.transcript,
                                                  expected: ex.answer)
            // a stand-in recogniser mangles sounds it does not have; be a little kinder
            engine.speechScore = approximate ? min(1, score * 1.25) : score
            engine.spoken = recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

// MARK: - Matching game

struct MatchExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine
    @State private var leftItems: [String] = []
    @State private var rightItems: [String] = []
    @State private var wrongPair: (String, String)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(items: leftItems, isLeft: true)
            column(items: rightItems, isLeft: false)
        }
        .onAppear {
            leftItems = ex.matchPairs.map { $0[state.target] }.shuffled()
            rightItems = ex.matchPairs.map { $0[state.native] }.shuffled()
        }
    }

    private func column(items: [String], isLeft: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(items, id: \.self) { item in
                let done = matchedTexts.contains(item)
                let selected = isLeft ? engine.matchLeft == item : engine.matchRight == item
                let isWrong = wrongPair.map { $0.0 == item || $0.1 == item } ?? false
                let accent: Color? = done ? Palette.green : (isWrong ? Palette.red : (selected ? Palette.brand : nil))
                Button {
                    Feedback.tap()
                    // the left column is the language she is learning: let her hear a
                    // tile again even once it has been paired off
                    if isLeft { speakIfTarget(item, language: state.target, state: state) }
                    guard !done else { return }
                    if isLeft { engine.matchLeft = item } else { engine.matchRight = item }
                    evaluate()
                } label: {
                    VStack(spacing: 2) {
                        Text(item)
                            .font(.body(16))
                            .foregroundStyle(done ? Palette.greenDeep : Palette.ink)
                            .multilineTextAlignment(.center)
                        if let rom = Romanisation.of(item) {
                            Text(rom).font(.plain(11)).italic()
                                .foregroundStyle(Palette.inkSoft)
                                .multilineTextAlignment(.center)
                        }
                    }
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .padding(.horizontal, 8).padding(.vertical, 14)
                        .glass(radius: 20, tint: accent, material: false)
                        .overlay {
                            if let accent, !done {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(accent.opacity(0.75), lineWidth: 1.8)
                            }
                        }
                        .opacity(done ? 0.5 : 1)
                        .shake(isWrong ? 1 : 0)
                }
                .buttonStyle(PressableStyle(scale: 0.95))
                .animation(.easeOut(duration: 0.2), value: done)
                .animation(.easeInOut(duration: 0.35), value: isWrong)
            }
        }
    }

    private var matchedTexts: Set<String> { engine.matched }

    private func evaluate() {
        guard let l = engine.matchLeft, let r = engine.matchRight else { return }
        let pair = ex.matchPairs.first { $0[state.target] == l }
        let correct = pair?[state.native] == r
        engine.registerMatch(pair: pair ?? ex.pair, correct: correct)
        if correct {
            Feedback.success()
            engine.matched.insert(l); engine.matched.insert(r)
            if let pair { state.gradePair(pair, correct: true) }
            SpeechService.shared.speak(pair?[state.target] ?? l, language: state.target, rate: state.settings.speechRate)
            engine.matchLeft = nil; engine.matchRight = nil
            if engine.matched.count >= ex.matchPairs.count * 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    Feedback.celebrate(); Feedback.dingCorrect()
                    withAnimation { engine.completeMatch() }
                }
            }
        } else {
            Feedback.failure(); Feedback.dingWrong()
            if let pair { state.gradePair(pair, correct: false) }
            wrongPair = (l, r)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                wrongPair = nil
                engine.matchLeft = nil; engine.matchRight = nil
            }
        }
    }
}

// MARK: - Fill in the blank

struct FillBlankExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    MascotBubble(mood: .think, size: 42)
                    Spacer(minLength: 0)
                }
                SpeakableText(text: displaySentence, language: ex.answerLanguage,
                              font: .body(23),
                              glossaryText: ex.pair[ex.answerLanguage])
                if let hint = ex.hint {
                    Text(hint).font(.plain(14)).foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(radius: 28)

            FlowLayout(spacing: 10, lineSpacing: 10) {
                ForEach(ex.options, id: \.self) { opt in
                    Button {
                        Feedback.tap()
                        speakIfTarget(opt, language: ex.answerLanguage, state: state)
                        guard engine.verdict == nil else { return }
                        engine.chosen = opt
                    } label: {
                        Text(opt)
                            .font(.body(17))
                            .foregroundStyle(chipText(opt))
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .background {
                                OptionSurface(state: chipState(opt), selected: engine.chosen == opt,
                                              shape: Capsule())
                            }
                    }
                    .buttonStyle(PressableStyle(scale: 0.94))
                }
            }
        }
    }

    private var displaySentence: String {
        guard let chosen = engine.chosen else { return ex.prompt }
        return ex.prompt.replacingOccurrences(of: "____", with: chosen)
    }

    private func chipState(_ opt: String) -> OptionRow.OptionState {
        guard let v = engine.verdict else { return .idle }
        if Grader.normalise(opt) == Grader.normalise(ex.answer) { return .right }
        if engine.chosen == opt, case .wrong = v { return .wrong }
        return .idle
    }
    private func chipText(_ opt: String) -> Color {
        switch chipState(opt) {
        case .right: return .white
        case .wrong: return Palette.redDeep
        case .idle: return Palette.ink
        }
    }
}

// MARK: - The short text

/// A few sentences of her own, from a brief: what to say, how to start, and the words
/// she already knows for it. Each check marks what is wrong in the text itself, with
/// a numbered clue per mark — clues that say where to look first, give the opening
/// letters next, and show the fix only at the end.
struct ComposeExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine
    @FocusState private var focused: Bool

    private var task: CompositionTask? { ex.composition }
    /// Where the lesson scrolls to once a check comes back.
    static let reviewID = "compose-review"

    var body: some View {
        if let task {
            VStack(alignment: .leading, spacing: 18) {
                brief(task)
                editor(task)
                if let report = engine.composeReport, !report.isClean, engine.verdict == nil {
                    reviewCard(report)
                        .id(ComposeExercise.reviewID)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if engine.verdict == nil {
                    wordBank(task)
                }
            }
            .onAppear {
                if engine.typed.isEmpty { engine.typed = task.starter + " " }
            }
            .onChange(of: engine.composeRound) { _, _ in focused = false }
        }
    }

    private func brief(_ task: CompositionTask) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 11) {
                MascotBubble(mood: .happy, size: 42)
                Text(S.composeTask[state.native])
                    .font(.heading(15)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(task.outline.enumerated()), id: \.offset) { i, point in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(i + 1)")
                            .font(.heading(12)).foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(LinearGradient(colors: Tone.writing.colors,
                                                                     startPoint: .top, endPoint: .bottom)))
                        Text(point[task.native])
                            .font(.body(16.5)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if task.invitesOwnSentence {
                Label(S.composeOwn[state.native], systemImage: "plus.bubble")
                    .font(.plain(13)).foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 28, tint: UnitAccent.writing.main)
    }

    private func editor(_ task: CompositionTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                FlagBadge(language: task.target, size: 20)
                Text(S.composeYourText[state.native])
                    .font(.heading(12.5)).foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 0)
                let enough = engine.composeWords >= task.minimumWords
                Label("\(engine.composeWords)/\(task.minimumWords) \(S.wordsShort[state.native])",
                      systemImage: enough ? "checkmark.circle.fill" : "pencil")
                    .font(.heading(11.5))
                    .foregroundStyle(enough ? Palette.greenDeep : Palette.inkFaint)
            }
            TextEditor(text: $engine.typed)
                .font(.body(18))
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .focused($focused)
                .frame(minHeight: 120)
                .disabled(engine.verdict != nil || engine.checking)
        }
        .padding(16)
        .glass(radius: 24, tint: focused ? Palette.brand : nil)
    }

    private func wordBank(_ task: CompositionTask) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: S.composeWords[state.native].uppercased())
            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(task.wordBank, id: \.self) { word in
                    Button {
                        Feedback.tap()
                        speakIfTarget(word, language: task.target, state: state)
                        insert(word, spaced: true)
                    } label: {
                        Text(word)
                            .font(.body(15)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .glassCapsule(material: false, shadow: false)
                    }
                    .buttonStyle(PressableStyle(scale: 0.94))
                }
            }
        }
    }

    private func reviewCard(_ report: CompositionReport) -> some View {
        let round = engine.composeRound
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                OrbIcon("text.magnifyingglass", accent: .writing, size: 36, symbolScale: 0.42)
                Text(S.composeIssues(report.issues.count)[state.native])
                    .font(.heading(16)).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                GlassChip(text: "\(S.composeRound[state.native]) \(round)/\(LessonEngine.composeRounds)",
                          tint: UnitAccent.writing.deep)
            }

            Text(Self.marked(report))
                .font(.body(16.5))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glass(radius: 18, material: false, shadow: false)

            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(report.issues.enumerated()), id: \.element.id) { i, issue in
                    HStack(alignment: .top, spacing: 10) {
                        Text(Self.circled(i + 1))
                            .font(.heading(16)).foregroundStyle(UnitAccent.writing.deep)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(issue.hint(round: round, native: state.native))
                                .font(.plain(14.5)).foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if round >= LessonEngine.composeRounds, let why = issue.why {
                                Text(why[state.native])
                                    .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            Label(S.composeEdit[state.native], systemImage: "arrow.uturn.up")
                .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
        }
        .padding(16)
        .glass(radius: 26, tint: UnitAccent.writing.main)
    }

    /// Puts a word at the end of the text, with the space it needs in front.
    private func insert(_ word: String, spaced: Bool) {
        guard engine.verdict == nil else { return }
        if spaced, let last = engine.typed.last, last != " ", last != "\n" {
            engine.typed.append(" ")
        }
        engine.typed.append(word)
        if spaced { engine.typed.append(" ") }
    }

    // MARK: - The text, marked

    static func circled(_ n: Int) -> String {
        guard (1...20).contains(n), let scalar = UnicodeScalar(0x2460 + n - 1) else { return "(\(n))" }
        return String(Character(scalar))
    }

    /// Her text as it was checked, with each mistake washed in rose and numbered, and
    /// a caret where a word is missing.
    static func marked(_ report: CompositionReport) -> AttributedString {
        let text = report.text
        struct Mark { var start: String.Index; var end: String.Index?; var number: Int }
        var marks: [Mark] = []
        for (i, issue) in report.issues.enumerated() {
            if let range = issue.range, range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex {
                marks.append(Mark(start: range.lowerBound, end: range.upperBound, number: i + 1))
            } else if let at = issue.insertAt, at >= text.startIndex, at <= text.endIndex {
                marks.append(Mark(start: at, end: nil, number: i + 1))
            }
        }
        marks.sort { $0.start < $1.start }

        var out = AttributedString()
        var cursor = text.startIndex
        for mark in marks where mark.start >= cursor {
            out += AttributedString(String(text[cursor..<mark.start]))
            if let end = mark.end {
                var piece = AttributedString(String(text[mark.start..<end]))
                piece.backgroundColor = Palette.red.opacity(0.18)
                piece.foregroundColor = Palette.redDeep
                piece.underlineStyle = Text.LineStyle(pattern: .solid, color: Palette.red)
                out += piece
                cursor = end
            } else {
                var caret = AttributedString("\u{2038}")
                caret.foregroundColor = Palette.red
                caret.font = .display(20)
                out += caret
                cursor = mark.start
            }
            var number = AttributedString(circled(mark.number))
            number.foregroundColor = Palette.amberDeep
            number.font = .heading(12)
            number.baselineOffset = 6
            out += number
        }
        if cursor < text.endIndex { out += AttributedString(String(text[cursor...])) }
        return out
    }
}
