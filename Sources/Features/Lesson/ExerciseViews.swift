import SwiftUI

// MARK: - Router

struct ExerciseHost: View {
    let exercise: Exercise
    @Bindable var engine: LessonEngine

    var body: some View {
        switch exercise.kind {
        case .choice:        ChoiceExercise(ex: exercise, engine: engine)
        case .listenChoice:  ListenChoiceExercise(ex: exercise, engine: engine)
        case .wordBank:      WordBankExercise(ex: exercise, engine: engine)
        case .type:          TypeExercise(ex: exercise, engine: engine, listening: false)
        case .listenType:    TypeExercise(ex: exercise, engine: engine, listening: true)
        case .speak:         SpeakExercise(ex: exercise, engine: engine)
        case .match:         MatchExercise(ex: exercise, engine: engine)
        case .fillBlank:     FillBlankExercise(ex: exercise, engine: engine)
        }
    }
}

// MARK: - Shared pieces

struct PromptCard: View {
    @Environment(AppState.self) private var state
    var text: String
    var language: Language
    var speakable: Bool = true
    var mood: Mascot.Mood = .happy

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Mascot(mood: mood, size: 64)
            SpeechBubble {
                VStack(alignment: .leading, spacing: 8) {
                    SpeakableText(text: text, language: language, font: .body(20))
                    if speakable && language == state.target {
                        AudioButtons(text: text, language: language, compact: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct AudioButtons: View {
    @Environment(AppState.self) private var state
    var text: String
    var language: Language
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Feedback.tap()
                SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate)
            } label: {
                Label(S.listenAgain[state.native], systemImage: "speaker.wave.2.fill")
                    .font(.heading(compact ? 12 : 14))
                    .labelStyle(compact ? AnyLabelStyle(IconOnlyLabelStyle()) : AnyLabelStyle(DefaultLabelStyle()))
                    .foregroundStyle(Palette.brand)
                    .padding(.horizontal, compact ? 9 : 12).padding(.vertical, compact ? 6 : 8)
                    .background(Capsule().fill(Palette.brand.opacity(0.13)))
            }
            .buttonStyle(.plain)

            Button {
                Feedback.tap()
                SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate, slow: true)
            } label: {
                Label(S.slowly[state.native], systemImage: "tortoise.fill")
                    .font(.heading(compact ? 12 : 14))
                    .labelStyle(compact ? AnyLabelStyle(IconOnlyLabelStyle()) : AnyLabelStyle(DefaultLabelStyle()))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, compact ? 9 : 12).padding(.vertical, compact ? 6 : 8)
                    .background(Capsule().fill(Palette.locked))
            }
            .buttonStyle(.plain)
        }
    }
}

struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView
    init<S: LabelStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// One tappable answer option.
struct OptionRow: View {
    var text: String
    var selected: Bool
    var state: OptionState = .idle
    var index: Int?
    var action: () -> Void

    enum OptionState { case idle, right, wrong }

    var body: some View {
        Button(action: action) {
            ChunkyCard(fill: fill, edge: edge, border: border, radius: Metrics.radiusSmall, depth: 4, pressed: selected) {
                HStack(spacing: 12) {
                    if let index {
                        Text("\(index + 1)")
                            .font(.heading(13))
                            .foregroundStyle(border ?? Palette.inkFaint)
                            .frame(width: 22, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(border ?? Palette.stroke, lineWidth: 1.6))
                    }
                    Text(text)
                        .font(.body(17))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        switch state {
        case .right: return Palette.greenSoft
        case .wrong: return Palette.redSoft
        case .idle: return selected ? Palette.brand.opacity(0.12) : Palette.card
        }
    }
    private var edge: Color {
        switch state {
        case .right: return Palette.green.opacity(0.4)
        case .wrong: return Palette.red.opacity(0.4)
        case .idle: return selected ? Palette.brand.opacity(0.35) : Palette.stroke
        }
    }
    private var border: Color? {
        switch state {
        case .right: return Palette.green
        case .wrong: return Palette.red
        case .idle: return selected ? Palette.brand : Palette.stroke
        }
    }
    private var textColor: Color {
        switch state {
        case .right: return Palette.greenDeep
        case .wrong: return Palette.redDeep
        case .idle: return Palette.ink
        }
    }
}

// MARK: - Multiple choice

struct ChoiceExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

// MARK: - Listening → choice

struct ListenChoiceExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine
    @State private var played = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                BigSpeakerButton(text: ex.audioText ?? ex.answer, language: ex.audioLanguage ?? state.target)
                AudioButtons(text: ex.audioText ?? ex.answer, language: ex.audioLanguage ?? state.target)
                Spacer(minLength: 0)
            }
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

struct BigSpeakerButton: View {
    @Environment(AppState.self) private var state
    var text: String
    var language: Language
    @State private var ring = false

    var body: some View {
        Button {
            Feedback.pop()
            SpeechService.shared.speak(text, language: language, rate: state.settings.speechRate)
            ring.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.brandDeep).frame(width: 92, height: 92).offset(y: 5)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.brand).frame(width: 92, height: 92)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: ring)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Word bank

struct WordBankExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PromptCard(text: ex.prompt, language: ex.promptLanguage)

            // answer tray
            VStack(spacing: 0) {
                ChipFlow(items: engine.built.map { (id: $0, text: ex.tokens[$0]) }) { item in
                    Feedback.tap()
                    speakIfTarget(item.text, language: ex.answerLanguage, state: state)
                    guard engine.verdict == nil else { return }
                    engine.built.removeAll { $0 == item.id }
                }
                .frame(minHeight: 48, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Palette.stroke).frame(height: 2)
                Spacer().frame(height: 10)
                Rectangle().fill(Palette.stroke).frame(height: 2)
            }

            // bank
            ChipFlow(items: ex.tokens.enumerated()
                .filter { !engine.built.contains($0.offset) }
                .map { (id: $0.offset, text: $0.element) }) { item in
                    Feedback.tap()
                    speakIfTarget(item.text, language: ex.answerLanguage, state: state)
                    guard engine.verdict == nil else { return }
                    engine.built.append(item.id)
                }
                .padding(.top, 6)
        }
    }
}

struct ChipFlow: View {
    var items: [(id: Int, text: String)]
    var onTap: ((id: Int, text: String)) -> Void

    var body: some View {
        FlexibleStack(data: items, spacing: 8, lineSpacing: 8) { item in
            Button { onTap(item) } label: {
                Text(item.text)
                    .font(.body(17))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Palette.card)
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Palette.stroke, lineWidth: 2))
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Palette.stroke).offset(y: 3)
                    )
            }
            .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 16) {
            if listening {
                HStack(spacing: 14) {
                    BigSpeakerButton(text: ex.audioText ?? ex.answer, language: ex.audioLanguage ?? state.target)
                    AudioButtons(text: ex.audioText ?? ex.answer, language: ex.audioLanguage ?? state.target)
                    Spacer(minLength: 0)
                }
            } else {
                PromptCard(text: ex.prompt, language: ex.promptLanguage, mood: .think)
                HStack(spacing: 6) {
                    FlagBadge(language: ex.answerLanguage, size: 22)
                    Text(ex.answerLanguage == .it ? "Italiano" : "O'zbekcha")
                        .font(.heading(12)).foregroundStyle(Palette.inkFaint)
                }
            }

            TextField(S.typeHere[state.native], text: $engine.typed, axis: .vertical)
                .font(.body(18))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(2...4)
                .focused($focused)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                        .fill(Palette.card)
                        .overlay(RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                            .stroke(focused ? Palette.brand : Palette.stroke, lineWidth: 2))
                )
                .disabled(engine.verdict != nil)

            if ex.answerLanguage == .uz {
                UzbekKeyRow { char in
                    engine.typed.append(char)
                }
            }
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
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Palette.brand.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Speaking

struct SpeakExercise: View {
    @Environment(AppState.self) private var state
    let ex: Exercise
    @Bindable var engine: LessonEngine
    @State private var recognizer = RecognizerService.shared
    @State private var recording = false

    private var approximate: Bool { !recognizer.isExact(for: state.target) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                Mascot(mood: .cheer, size: 60)
                SpeechBubble {
                    VStack(alignment: .leading, spacing: 8) {
                        SpeakableText(text: ex.prompt, language: ex.promptLanguage, font: .body(21))
                        if let hint = ex.hint {
                            Text(hint).font(.plain(13)).foregroundStyle(Palette.inkSoft)
                        }
                        AudioButtons(text: ex.prompt, language: state.target, compact: true)
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                micButton
                if recognizer.status == .listening {
                    Text(S.listening[state.native])
                        .font(.heading(14)).foregroundStyle(Palette.pink)
                } else if recognizer.isTranscribing {
                    HStack(spacing: 7) {
                        ProgressView().tint(Palette.pink).scaleEffect(0.8)
                        Text(S.transcribing[state.native])
                            .font(.heading(14)).foregroundStyle(Palette.pink)
                    }
                } else if !recognizer.transcript.isEmpty {
                    VStack(spacing: 4) {
                        Text(S.heardYou[state.native]).font(.plain(12)).foregroundStyle(Palette.inkFaint)
                        Text(recognizer.transcript).font(.body(16)).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text(S.tapToSpeak[state.native])
                        .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                }

                if recognizer.status == .denied {
                    Text(state.native == .it
                         ? "Microfono non autorizzato. Attivalo in Impostazioni."
                         : "Mikrofonga ruxsat yo'q. Sozlamalardan yoqing.")
                        .font(.plain(12)).foregroundStyle(Palette.red).multilineTextAlignment(.center)
                } else if approximate {
                    Text(S.approximateRecog[state.native])
                        .font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onDisappear { recognizer.reset() }
    }

    private var micButton: some View {
        Button {
            Feedback.pop()
            if recording { stopRecording() } else { startRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(Palette.pink.opacity(0.25))
                    .frame(width: 108 + CGFloat(recognizer.level * 42),
                           height: 108 + CGFloat(recognizer.level * 42))
                    .opacity(recording ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: recognizer.level)
                Circle().fill(Palette.pink.opacity(0.85)).frame(width: 96, height: 96).offset(y: 5)
                Circle().fill(recording ? Palette.red : Palette.pink).frame(width: 96, height: 96)
                Image(systemName: recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 36, weight: .black)).foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
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
                Button {
                    Feedback.tap()
                    // the left column is the language she is learning: let her hear a
                    // tile again even once it has been paired off
                    if isLeft { speakIfTarget(item, language: state.target, state: state) }
                    guard !done else { return }
                    if isLeft { engine.matchLeft = item } else { engine.matchRight = item }
                    evaluate()
                } label: {
                    ChunkyCard(fill: done ? Palette.greenSoft : (isWrong ? Palette.redSoft : (selected ? Palette.brand.opacity(0.14) : Palette.card)),
                               edge: done ? Palette.green.opacity(0.35) : (selected ? Palette.brand.opacity(0.35) : Palette.stroke),
                               border: done ? Palette.green : (isWrong ? Palette.red : (selected ? Palette.brand : Palette.stroke)),
                               radius: Metrics.radiusSmall, depth: 4) {
                        Text(item)
                            .font(.body(15.5))
                            .foregroundStyle(done ? Palette.greenDeep.opacity(0.6) : Palette.ink)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8).padding(.vertical, 14)
                    }
                    .opacity(done ? 0.55 : 1)
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.2), value: done)
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
                    Feedback.celebrate()
                    withAnimation { engine.completeMatch() }
                }
            }
        } else {
            Feedback.failure()
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                Mascot(mood: .think, size: 60)
                SpeechBubble {
                    VStack(alignment: .leading, spacing: 8) {
                        SpeakableText(text: displaySentence, language: ex.answerLanguage,
                                      font: .body(20))
                        if let hint = ex.hint {
                            Text(hint).font(.plain(13)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            FlowLayout(spacing: 9, lineSpacing: 9) {
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
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(chipFill(opt))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(chipBorder(opt), lineWidth: 2))
                            )
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(chipBorder(opt).opacity(0.5)).offset(y: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var displaySentence: String {
        guard let chosen = engine.chosen else { return ex.prompt }
        return ex.prompt.replacingOccurrences(of: "____", with: chosen)
    }

    private func chipFill(_ opt: String) -> Color {
        guard let v = engine.verdict else { return engine.chosen == opt ? Palette.brand.opacity(0.14) : Palette.card }
        if Grader.normalise(opt) == Grader.normalise(ex.answer) { return Palette.greenSoft }
        if engine.chosen == opt, case .wrong = v { return Palette.redSoft }
        return Palette.card
    }
    private func chipBorder(_ opt: String) -> Color {
        guard let v = engine.verdict else { return engine.chosen == opt ? Palette.brand : Palette.stroke }
        if Grader.normalise(opt) == Grader.normalise(ex.answer) { return Palette.green }
        if engine.chosen == opt, case .wrong = v { return Palette.red }
        return Palette.stroke
    }
    private func chipText(_ opt: String) -> Color {
        guard engine.verdict != nil else { return Palette.ink }
        if Grader.normalise(opt) == Grader.normalise(ex.answer) { return Palette.greenDeep }
        return Palette.ink
    }
}
