import SwiftUI

struct LessonView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let request: SessionRequest
    /// Told what happened, for callers that place the learner by the outcome.
    var onFinish: ((SessionResults) -> Void)?

    @State private var engine: LessonEngine?
    @State private var quitDialog: GlassDialog?
    @State private var showStory = false
    @State private var outOfHearts = false
    @State private var results: SessionResults?
    /// The line that appears when a skill has just been put on hold.
    @State private var pausedNotice: Bilingual?
    /// True while the assistant is writing sentences for a chapter that has none yet.
    @State private var writingPhrases = false
    /// The unit's practice sentences: made of words she already has, so never "new".
    @State private var drills: Set<String> = []
    /// What the badges above a question said when it appeared. Answering grades the
    /// word, which would make "new" vanish mid-question and the screen jump.
    @State private var badgeMemo: [UUID: (new: Bool, mistake: Bool)] = [:]
    /// The streak grew with this session: shown after the results, before closing.
    @State private var streak: StreakMoment?

    var body: some View {
        ZStack {
            AuroraBackground(mood: results == nil ? .lesson : .celebrate)

            if let results {
                ResultsView(results: results) { leave() }
                    .transition(.opacity)
            } else if showStory, case .story(let dialogue)? = request.node?.kind {
                StoryReadingView(dialogue: dialogue) {
                    withAnimation(.easeInOut) { showStory = false }
                } onQuit: {
                    dismiss()
                }
            } else if let engine {
                lessonBody(engine)
            } else {
                VStack(spacing: 14) {
                    MascotBubble(mood: .think, size: 84)
                    ProgressView().tint(Palette.brand)
                    if writingPhrases {
                        Text(S.writingPhrases[state.native])
                            .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: writingPhrases)
            }
        }
        .task { await setUp() }
        .task(id: pausedNotice) {
            // long enough to read, short enough not to sit on top of the next question
            guard pausedNotice != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { pausedNotice = nil }
        }
        .glassDialog($quitDialog)
        .streakCelebration($streak) { dismiss() }
        .sheet(isPresented: $outOfHearts) {
            HeartsSheet(onQuit: { outOfHearts = false; dismiss() })
                .presentationDetents([.height(420)])
                .auroraSheet()
        }
    }

    // MARK: - Setup

    private func setUp() async {
        guard engine == nil else { return }
        if case .story? = request.node?.kind { showStory = true }
        let list: [Exercise]
        if request.mode != .lesson {
            list = request.customExercises
        } else if let node = request.node, let unit = request.unit {
            let fresh = await freshPhrases(for: node, unit: unit)
            list = ExerciseFactory.session(for: node, unit: unit,
                                           curriculum: state.curriculum,
                                           native: state.native,
                                           settings: state.effectiveSettings,
                                           focus: request.focus,
                                           fresh: fresh,
                                           familiarity: state.familiarity(with:))
        } else {
            list = []
        }
        Glossary.prime(with: state.curriculum.allPairs + state.curriculum.allDrills,
                       vocabulary: state.curriculum.allLessons.flatMap(\.vocab))
        // story lines, and every sentence the assistant writes, live in no file
        Glossary.learn(list.map(\.pair))
        drills = Set((request.unit?.allDrills ?? []).map(\.id))
        engine = LessonEngine(exercises: list)
    }

    /// The chapter's newly written sentences, if there are any to be had.
    ///
    /// The first pass over a node teaches the words themselves and wants none of
    /// this. Every later pass takes whatever is on disk — instantly — and, when the
    /// pool is still thin, waits a few seconds for a first batch rather than serving
    /// the same questions a fourth time. Either way another batch is ordered on the
    /// way out, so the wait is paid at most once per chapter.
    private func freshPhrases(for node: PathNode, unit: Unit) async -> [Pair] {
        guard request.focus != .discover,
              let level = state.curriculum.level(of: unit.id),
              let brief = state.phraseBrief(for: node, unit: unit, level: level) else { return [] }

        let held = await PhraseForge.shared.stored(for: node.id)
        guard held.count < PhraseForge.comfortable, brief.isPossible else {
            PhraseForge.shared.warm(brief)
            return held
        }
        withAnimation { writingPhrases = true }
        let ready = await PhraseForge.shared.ready(brief, waitingUpTo: 4)
        writingPhrases = false
        PhraseForge.shared.warm(brief)
        return ready
    }

    // MARK: - Lesson body

    @ViewBuilder
    private func lessonBody(_ engine: LessonEngine) -> some View {
        VStack(spacing: 0) {
            topBar(engine)

            if let ex = engine.current {
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 9) {
                            badges(for: ex)
                            Text(ex.instruction[state.native])
                                .font(.display(25))
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 10)

                        ExerciseHost(exercise: ex, engine: engine)
                            .id(ex.id)
                    }
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                // a checked text: straight to the marks and the clues
                .onChange(of: engine.composeRound) { _, round in
                    guard round > 0 else { return }
                    // after the keyboard has gone, or the scroll lands short
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(ComposeExercise.reviewID, anchor: .top)
                        }
                    }
                }
                }
            } else {
                Spacer()
            }

            footer(engine)
        }
        .onChange(of: engine.finished) { _, done in
            if done { finish(engine) }
        }
        .onChange(of: engine.current?.id, initial: true) { _, _ in
            guard let ex = engine.current, badgeMemo[ex.id] == nil else { return }
            let wordLike = ex.kind != .match && ex.kind != .compose
            badgeMemo[ex.id] = (new: wordLike && state.isNew(ex.pair) && !drills.contains(ex.pair.id),
                                mistake: !ex.isRetry && wordLike && state.isPastMistake(ex.pair))
        }
    }

    /// Says what this question is, when it is something worth knowing: a word she has
    /// never met, or one she got wrong and is meeting again.
    @ViewBuilder
    private func badges(for ex: Exercise) -> some View {
        let isNew = badgeMemo[ex.id]?.new ?? false
        let isOldMistake = badgeMemo[ex.id]?.mistake ?? false
        if ex.isRetry || isNew || isOldMistake {
            HStack(spacing: 7) {
                if ex.isRetry {
                    GlassChip(text: S.previousMistake[state.native], icon: "arrow.uturn.left",
                              tint: Palette.amberDeep)
                } else if isOldMistake {
                    GlassChip(text: S.previousMistake[state.native], icon: "bandage.fill",
                              tint: Palette.redDeep)
                }
                if isNew {
                    GlassChip(text: S.newWord[state.native], icon: "sparkles", tint: Palette.teal)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func topBar(_ engine: LessonEngine) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                GlassCircleButton(icon: "xmark", size: 42, tint: Palette.inkSoft,
                                  accessibility: S.quit[state.native]) {
                    Feedback.tap()
                    quitDialog = GlassDialog(title: S.quitLesson[state.native],
                                             message: S.quitLessonMsg[state.native],
                                             confirm: S.quit[state.native],
                                             cancel: S.stay[state.native],
                                             destructive: true,
                                             icon: "door.left.hand.open") { dismiss() }
                }
                ProgressBar(value: engine.progress, tint: barTint)
                if request.mode == .test {
                    StatPill(icon: "xmark.circle.fill",
                             text: "\(engine.mistakePairs.count)/\(request.testTarget?.allowedMistakes ?? 3)",
                             tint: Palette.purple)
                } else if request.consumesHearts && !state.unlimited {
                    StatPill(icon: "heart.fill", text: "\(state.hearts)", tint: Palette.brand)
                        .contentTransition(.numericText())
                } else {
                    InfinityPill(icon: "heart.fill", tint: Palette.brand)
                }
            }
            sessionBadge
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var barTint: Color {
        if request.mode == .test { return Palette.purple }
        if request.mode == .lesson { return request.focus.tint.main }
        return request.accent?.main ?? Palette.brand
    }

    @ViewBuilder
    private var sessionBadge: some View {
        HStack(spacing: 0) {
            if request.mode == .test {
                GlassChip(text: S.testTitle[state.native].uppercased(), icon: "checkmark.seal.fill",
                          tint: Palette.purpleDeep)
            } else if request.mode == .lesson, request.node != nil {
                let label = request.focus.label[state.native].uppercased()
                GlassChip(text: request.sessionsTotal > 1 ? "\(label) · \(request.sessionNumber)/\(request.sessionsTotal)"
                                                          : label,
                          icon: request.focus.icon, tint: request.focus.tint.deep)
            } else if let title = request.customTitle {
                GlassChip(text: title[state.native].uppercased(), icon: "dumbbell.fill",
                          tint: request.accent?.deep ?? Palette.brand)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 54)
    }

    // MARK: - Footer: check / continue + feedback

    @ViewBuilder
    private func footer(_ engine: LessonEngine) -> some View {
        let verdict = engine.verdict
        if engine.current?.kind == .match {
            // the matching game grades itself: no action bar at all
            Color.clear.frame(height: 0)
        } else {
            VStack(spacing: 14) {
                if let pausedNotice {
                    GlassToast(icon: "clock.badge.xmark", text: pausedNotice[state.native], tint: Palette.amber)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let verdict {
                    feedbackBanner(verdict, engine: engine)
                }
                // the Uzbek letters sit right above the button, which always sits right
                // above the keyboard: where the eye already is, never under the keys
                if verdict == nil, let ex = engine.current, ex.answerLanguage == .uz,
                   [.type, .listenType, .compose].contains(ex.kind), !engine.checking {
                    UzbekKeyRow { engine.typed.append($0) }
                        .transition(.opacity)
                }
                buttons(engine, verdict: verdict)
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.top, verdict == nil ? 12 : 18)
            .padding(.bottom, 12)
            .background {
                if verdict != nil {
                    GlassPane(shape: UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 0,
                                                            bottomTrailingRadius: 0, topTrailingRadius: 32,
                                                            style: .continuous),
                              tint: bannerTint(verdict))
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: engine.verdict)
        }
    }

    @ViewBuilder
    private func buttons(_ engine: LessonEngine, verdict: Verdict?) -> some View {
        let isCompose = engine.current?.kind == .compose
        HStack(spacing: 10) {
            // "not right now": puts the whole skill aside for a quarter of an hour,
            // here and in every session started while the hold lasts
            if verdict == nil, let skill = engine.current?.trainsSkill,
               skill == .speaking || skill == .listening {
                Button {
                    Feedback.tap()
                    state.snooze(skill)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pausedNotice = S.pausedNotice(skill, minutes: AppState.snoozeMinutes)
                        engine.setAside(skill, native: state.native)
                    }
                } label: {
                    Text((skill == .speaking ? S.cantSpeak : S.cantListen)[state.native])
                        .font(.heading(13.5))
                }
                .buttonStyle(.glass(nil, height: 56, text: Palette.inkSoft))
            }

            // the short text has a way out once she has had a couple of clues
            if verdict == nil, isCompose, engine.composeRound >= 2, !engine.checking {
                Button {
                    Feedback.tap()
                    guard let ex = engine.current else { return }
                    engine.revealComposition()
                    settle(engine.grade(), ex: ex, engine: engine)
                } label: {
                    Text(S.composeReveal[state.native]).font(.heading(13.5))
                }
                .buttonStyle(.glass(Palette.amber, height: 56))
            }

            Button {
                if verdict == nil { performCheck(engine) } else { performContinue(engine) }
            } label: {
                if engine.checking {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text(isCompose ? S.composeChecking[state.native] : S.doubleChecking[state.native])
                    }
                } else if verdict != nil {
                    Text(S.continueBtn[state.native])
                } else if isCompose {
                    Text(engine.composeReport == nil ? S.composeCheck[state.native] : S.composeRecheck[state.native])
                } else {
                    Text(S.checkAnswer[state.native])
                }
            }
            .buttonStyle(.primary(buttonTone(verdict)))
            .disabled(verdict == nil && !engine.canCheck)
        }
    }

    private func bannerTint(_ v: Verdict?) -> Color? {
        switch v {
        case .correct, .almost, .alternative: return Palette.green
        case .wrong: return Palette.red
        case nil: return nil
        }
    }

    /// One colour for the button, whatever happened: the banner above says how it went.
    private func buttonTone(_ v: Verdict?) -> Tone { .violet }

    /// One line of the banner: what was said, and what it means.
    private struct FeedbackLine {
        var label: String?
        var text: String
        var meaning: Glossary.Gloss?
    }

    /// The right answer, always read back with its translation — a correct pick the
    /// learner half-guessed should still tell her what she just said.
    private func solutionLine(_ v: Verdict, ex: Exercise, engine: LessonEngine) -> FeedbackLine? {
        let text: String
        switch v {
        case .alternative:
            // her wording was accepted, so hers is the answer worth showing first
            text = engine.givenAnswer
        case .almost(let fix):
            text = ex.kind == .fillBlank ? ex.solution : fix
        case .correct, .wrong:
            text = ex.solution
        }
        guard !text.isEmpty else { return nil }
        return FeedbackLine(text: text, meaning: ex.meaning(of: text))
    }

    /// What she actually answered, translated too — but only when it differs from
    /// the solution, so a clean hit stays a single line.
    private func givenLine(_ v: Verdict, ex: Exercise, engine: LessonEngine) -> FeedbackLine? {
        // when her own wording was accepted, the second line is the book's version
        if case .alternative(let canonical, _) = v {
            guard !canonical.isEmpty,
                  Grader.normalise(canonical) != Grader.normalise(engine.givenAnswer) else { return nil }
            // not "the right answer is" — hers was right; this is only the book's version
            return FeedbackLine(label: S.courseSays[state.native], text: canonical,
                                meaning: ex.meaning(of: canonical))
        }
        let raw = engine.givenAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let key = Grader.normalise(raw)
        let accepted = Grader.alternatives(ex.answer).map(Grader.normalise)
        guard !accepted.contains(key), key != Grader.normalise(ex.solution) else { return nil }
        let spoken = ex.kind == .speak || ex.kind == .speakRepeat
        return FeedbackLine(label: spoken ? S.heardYou[state.native] : S.yourAnswer[state.native],
                            text: raw,
                            meaning: ex.meaning(of: raw))
    }

    @ViewBuilder
    private func render(_ line: FeedbackLine, size: CGFloat, tint: Color) -> some View {
        // a short label sits in front of the answer; a whole sentence of a label gets
        // its own line, so the answer itself stays easy to find
        if let label = line.label, label.count > 24 {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.plain(size - 3)).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                body(of: line, size: size, tint: tint)
            }
        } else {
            body(of: line, size: size, tint: tint, label: line.label)
        }
    }

    private func body(of line: FeedbackLine, size: CGFloat, tint: Color, label: String? = nil) -> Text {
        var out = Text("")
        if let label {
            out = out + Text(label + " ").font(.plain(size - 3)).foregroundStyle(Palette.inkSoft)
        }
        out = out + Text(line.text).font(.body(size)).foregroundStyle(tint)
        if let meaning = line.meaning {
            let quoted = (meaning.literal ? "\u{2248} " : "") + "\u{201C}" + meaning.text + "\u{201D}"
            out = out + Text("  " + quoted).font(.plain(size - 2.5)).foregroundStyle(Palette.inkSoft)
        }
        return out
    }

    @ViewBuilder
    private func feedbackBanner(_ v: Verdict, engine: LessonEngine) -> some View {
        if let ex = engine.current, ex.kind == .compose {
            composeBanner(v, ex: ex, engine: engine)
        } else {
            answerBanner(v, engine: engine)
        }
    }

    @ViewBuilder
    private func answerBanner(_ v: Verdict, engine: LessonEngine) -> some View {
        let ex = engine.current
        let solution = ex.flatMap { solutionLine(v, ex: $0, engine: engine) }
        let given = ex.flatMap { givenLine(v, ex: $0, engine: engine) }
        HStack(alignment: .top, spacing: 12) {
            verdictOrb(v)

            VStack(alignment: .leading, spacing: 4) {
                switch v {
                case .correct:
                    Text(S.correct[state.native])
                        .font(.display(19)).foregroundStyle(Palette.greenDeep)
                case .alternative:
                    Text(S.alsoRight[state.native])
                        .font(.display(19)).foregroundStyle(Palette.greenDeep)
                        .accessibilityLabel(S.alsoRight[state.native])
                case .almost:
                    Text(S.almost[state.native]).font(.heading(15)).foregroundStyle(Palette.greenDeep)
                case .wrong:
                    Text(S.wrong[state.native]).font(.heading(15)).foregroundStyle(Palette.redDeep)
                }

                if let solution {
                    render(solution, size: 16.5, tint: Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .speakOnTap(solution.text, language: ex?.answerLanguage)
                }
                if let given {
                    render(given, size: 13.5, tint: Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .speakOnTap(given.text, language: ex?.answerLanguage)
                }

                if case .alternative(_, let note) = v, let note, !note.isEmpty {
                    Text(note).font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Every wording the app can recognise is already marked right before
                // this banner appears. What is left is hers to report: a flag, not a
                // second verdict — the app does not say "wrong" and then "right anyway".
                if let ex, case .wrong = v, AnswerJudge.isOpen(ex.kind),
                   !engine.givenAnswer.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        acceptAnyway(engine, ex: ex)
                    } label: {
                        Label(S.mineIsRightToo[state.native], systemImage: "flag")
                            .font(.heading(12))
                            .foregroundStyle(Palette.inkSoft)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .glassCapsule(material: false, shadow: false)
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, 4)
                }
                if let ex, ex.kind == .speak || ex.kind == .speakRepeat, let score = engine.speechScore {
                    Text("\(Int(score * 100))%")
                        .font(.heading(12)).foregroundStyle(Palette.inkSoft)
                }
                // the note only earns its line when it says something the
                // translation above has not already said
                if let ex, let hint = ex.hint, ex.kind != .speak, ex.kind != .speakRepeat,
                   hint != solution?.meaning?.text, case .wrong = v {
                    Text(hint).font(.plain(13)).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)

            if let ex, let audio = ex.audioText ?? (ex.answerLanguage == state.target ? ex.answer : nil) {
                GlassCircleButton(icon: "speaker.wave.2.fill", size: 40,
                                  tint: v.isAccepted ? Palette.greenDeep : Palette.redDeep,
                                  accessibility: S.listenAgain[state.native]) {
                    SpeechService.shared.speak(audio, language: state.target, rate: state.settings.speechRate)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func verdictOrb(_ v: Verdict) -> some View {
        let symbol: String
        switch v {
        case .correct, .alternative: symbol = "checkmark"
        case .almost: symbol = "exclamationmark"
        case .wrong: symbol = "xmark"
        }
        return OrbIcon(symbol, accent: v.isAccepted ? .green : .red, size: 40, symbolScale: 0.4)
    }

    /// The end of a short text: how it went, and the text as it now stands.
    private func composeBanner(_ v: Verdict, ex: Exercise, engine: LessonEngine) -> some View {
        let headline: String
        let text: String
        switch v {
        case .correct:
            headline = S.composeClean[state.native]
            text = engine.typed.trimmingCharacters(in: .whitespacesAndNewlines)
        case .almost, .alternative:
            headline = S.composeFixed[state.native]
            text = engine.typed.trimmingCharacters(in: .whitespacesAndNewlines)
        case .wrong(let corrected):
            headline = S.composeSeeFix[state.native]
            text = corrected
        }
        return HStack(alignment: .top, spacing: 12) {
            verdictOrb(v)
            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.display(19))
                    .foregroundStyle(v.isAccepted ? Palette.greenDeep : Palette.redDeep)
                Text(text)
                    .font(.body(15.5)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .speakOnTap(text, language: state.target)
            }
            Spacer(minLength: 0)
            GlassCircleButton(icon: "speaker.wave.2.fill", size: 40,
                              tint: v.isAccepted ? Palette.greenDeep : Palette.redDeep,
                              accessibility: S.listenAgain[state.native]) {
                SpeechService.shared.speak(text, language: state.target, rate: state.settings.speechRate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func performCheck(_ engine: LessonEngine) {
        guard let ex = engine.current else { return }
        if ex.kind == .compose { checkComposition(engine, ex: ex); return }
        let v = engine.grade()

        // A translation she wrote herself can be right in more than one way. Before
        // the miss is recorded, see whether the course, her own history, or the
        // assistant recognises her wording.
        guard case .wrong = v, AnswerJudge.isOpen(ex.kind) else {
            settle(v, ex: ex, engine: engine)
            return
        }
        let given = engine.givenAnswer
        if let offline = AnswerJudge.offline(given, for: ex,
                                             remembered: state.alternatives(for: ex.answer)) {
            settle(offline, ex: ex, engine: engine)
            return
        }
        guard AIClient.isConfigured(provider: state.aiProvider, key: state.aiKey) else {
            settle(v, ex: ex, engine: engine)
            return
        }
        engine.checking = true
        Task {
            let second = await AnswerJudge.secondOpinion(given, for: ex,
                                                         level: request.level ?? .a1,
                                                         native: state.native,
                                                         provider: state.aiProvider,
                                                         apiKey: state.aiKey)
            await MainActor.run {
                engine.checking = false
                if case .alternative = second {
                    // learnt for good: the same answer never has to be argued for twice
                    state.rememberAlternative(given, for: ex.answer)
                }
                settle(second ?? v, ex: ex, engine: engine)
            }
        }
    }

    /// One round of correcting the short text: the assistant when there is one, the
    /// offline checker otherwise. A clean text ends the exercise; anything else goes
    /// back to her, with clues that get more precise each round.
    private func checkComposition(_ engine: LessonEngine, ex: Exercise) {
        guard let task = ex.composition else { return }
        let text = engine.typed
        let provider = state.aiProvider, key = state.aiKey
        let curriculum = state.curriculum
        // the keyboard goes away while the text is read, so the marks can be seen
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        engine.checking = true
        Task {
            var report: CompositionReport?
            if AIClient.isConfigured(provider: provider, key: key) {
                report = try? await AIClient.correctComposition(provider: provider, key: key,
                                                                task: task, text: text)
            }
            let final = report ?? CompositionChecker.check(text, task: task, curriculum: curriculum)
            await MainActor.run {
                engine.checking = false
                // she may have typed on while it was reading: the report is about
                // the text it read, and the next check will read the new one
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    let clean = engine.recordComposeRound(final)
                    if clean {
                        settle(engine.grade(), ex: ex, engine: engine)
                    } else {
                        // not a wrong answer: a draft with things to fix
                        Feedback.pop()
                    }
                }
            }
        }
    }

    /// Records the verdict, and pays for it.
    private func settle(_ v: Verdict, ex: Exercise, engine: LessonEngine) {
        withAnimation(.easeOut(duration: 0.18)) { engine.commit(v) }
        if v.isAccepted {
            Feedback.success(); Feedback.dingCorrect()
        } else {
            Feedback.failure(); Feedback.dingWrong()
            // a text she needed to see corrected is a lesson, not a fault
            if request.consumesHearts && ex.kind != .compose {
                state.loseHeart()
                if state.hearts == 0 { outOfHearts = true }
            }
        }
        state.gradePair(ex.pair, correct: v.isAccepted)

        // read the answer back on production exercises
        guard ex.answerLanguage == state.target, ex.kind != .speak, ex.kind != .speakRepeat,
              ex.kind != .compose else { return }
        switch v {
        case .correct:
            readBack(ex.answer, after: ex, engine: engine)
        case .alternative:
            // her own wording is the one worth hearing back
            readBack(engine.givenAnswer, after: ex, engine: engine)
        case .almost, .wrong:
            break
        }
    }

    /// Reads an answer aloud once the chime is over, so the two do not talk over each
    /// other — and not at all if she has already moved on to the next question.
    private func readBack(_ text: String, after ex: Exercise, engine: LessonEngine) {
        let rate = state.settings.speechRate, language = state.target
        DispatchQueue.main.asyncAfter(deadline: .now() + Feedback.chimeGap) {
            guard engine.current?.id == ex.id, engine.verdict != nil else { return }
            SpeechService.shared.speak(text, language: language, rate: rate)
        }
    }

    /// She says her wording is good too. It is learnt for good, here and in every later
    /// lesson, and the question stops counting against her.
    private func acceptAnyway(_ engine: LessonEngine, ex: Exercise) {
        Feedback.success(); Feedback.dingCorrect()
        state.rememberAlternative(engine.givenAnswer, for: ex.answer)
        state.gradePair(ex.pair, correct: true)
        if request.consumesHearts { state.regainHeart() }
        outOfHearts = false
        withAnimation(.easeOut(duration: 0.18)) { engine.acceptAnswerAnyway() }
        if ex.answerLanguage == state.target {
            readBack(engine.givenAnswer, after: ex, engine: engine)
        }
    }

    private func performContinue(_ engine: LessonEngine) {
        Feedback.tap()
        SpeechService.shared.stop()
        withAnimation(.easeInOut(duration: 0.2)) { engine.advance() }
    }

    /// Closes the lesson — by way of the streak, the first time today.
    private func leave() {
        if let moment = state.takeStreakMoment() { streak = moment } else { dismiss() }
    }

    private func finish(_ engine: LessonEngine) {
        let base = request.mode == .lesson ? (request.node?.xpReward ?? 15) : request.xpReward
        let xp = engine.xpEarned(base: base)
        let acc = engine.accuracy
        var passed: Bool?

        switch request.mode {
        case .lesson:
            if let node = request.node {
                state.finishSession(nodeID: node.id, xpEarned: xp, accuracy: acc,
                                    minutes: engine.minutes, mistakes: engine.mistakePairs)
            }
        case .practice:
            state.addXP(xp, minutes: engine.minutes)
            state.save()
        case .test:
            let ok = acc >= (request.testTarget?.passMark ?? 0.8)
            passed = ok
            if ok, let target = request.testTarget {
                state.markPassedTest(target, accuracy: acc)
                state.addXP(xp, minutes: engine.minutes)
            }
            state.save()
        }

        if passed == false { Feedback.failure() } else { Feedback.celebrate() }
        let outcome = SessionResults(xp: passed == false ? 0 : xp,
                                     accuracy: acc,
                                     minutes: engine.minutes,
                                     mistakes: engine.mistakePairs,
                                     title: request.customTitle ?? request.node?.title ?? S.lessonDone,
                                     testPassed: passed)
        onFinish?(outcome)
        withAnimation(.spring(response: 0.5)) { results = outcome }
    }
}

struct SessionResults {
    var xp: Int
    var accuracy: Double
    var minutes: Int
    var mistakes: [Pair]
    var title: Bilingual
    /// Only set for knowledge checks.
    var testPassed: Bool?
}
