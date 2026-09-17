import SwiftUI

struct LessonView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let request: SessionRequest

    @State private var engine: LessonEngine?
    @State private var showQuitAlert = false
    @State private var showStory = false
    @State private var outOfHearts = false
    @State private var results: SessionResults?

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            if let results {
                ResultsView(results: results) { dismiss() }
            } else if showStory, case .story(let dialogue)? = request.node?.kind {
                StoryReadingView(dialogue: dialogue) {
                    withAnimation(.easeInOut) { showStory = false }
                } onQuit: {
                    dismiss()
                }
            } else if let engine {
                lessonBody(engine)
            } else {
                ProgressView().tint(Palette.brand)
            }
        }
        .onAppear(perform: setUp)
        .alert(S.quitLesson[state.native], isPresented: $showQuitAlert) {
            Button(S.stay[state.native], role: .cancel) {}
            Button(S.quit[state.native], role: .destructive) { dismiss() }
        } message: { Text(S.quitLessonMsg[state.native]) }
        .sheet(isPresented: $outOfHearts) {
            HeartsSheet(onQuit: { outOfHearts = false; dismiss() })
                .presentationDetents([.height(380)])
        }
    }

    // MARK: - Setup

    private func setUp() {
        guard engine == nil else { return }
        if case .story? = request.node?.kind { showStory = true }
        let list: [Exercise]
        if request.mode != .lesson {
            list = request.customExercises
        } else if let node = request.node, let unit = request.unit {
            list = ExerciseFactory.session(for: node, unit: unit,
                                           curriculum: state.curriculum,
                                           native: state.native,
                                           settings: state.settings,
                                           focus: request.focus)
        } else {
            list = []
        }
        Glossary.prime(with: state.curriculum.allPairs)
        // story lines are built on the fly and live in no curriculum file
        Glossary.learn(list.map(\.pair))
        engine = LessonEngine(exercises: list)
    }

    // MARK: - Lesson body

    @ViewBuilder
    private func lessonBody(_ engine: LessonEngine) -> some View {
        VStack(spacing: 0) {
            topBar(engine)

            if let ex = engine.current {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(ex.instruction[state.native])
                            .font(.heading(21))
                            .foregroundStyle(Palette.ink)
                            .padding(.top, 14)

                        ExerciseHost(exercise: ex, engine: engine)
                            .id(ex.id)
                    }
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                Spacer()
            }

            footer(engine)
        }
        .onChange(of: engine.finished) { _, done in
            if done { finish(engine) }
        }
    }

    private func topBar(_ engine: LessonEngine) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 14) {
                Button {
                    Feedback.tap(); showQuitAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Palette.inkFaint)
                }
                ProgressBar(value: engine.progress, tint: barTint)
                if request.mode == .test {
                    StatPill(icon: "xmark.circle.fill",
                             text: "\(engine.mistakePairs.count)/\(request.testTarget?.allowedMistakes ?? 3)",
                             tint: Palette.purple)
                } else if request.consumesHearts && !state.unlimited {
                    StatPill(icon: "heart.fill", text: "\(state.hearts)", tint: Palette.red)
                        .contentTransition(.numericText())
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill").font(.system(size: 14, weight: .black))
                        Image(systemName: "infinity").font(.system(size: 14, weight: .black))
                    }
                    .foregroundStyle(Palette.red)
                }
            }
            sessionBadge
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.vertical, 10)
    }

    private var barTint: Color {
        request.mode == .test ? Palette.purple : Palette.green
    }

    @ViewBuilder
    private var sessionBadge: some View {
        HStack(spacing: 6) {
            if request.mode == .test {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 11, weight: .black))
                Text(S.testTitle[state.native].uppercased()).font(.heading(11)).kerning(0.7)
            } else if request.mode == .lesson, request.sessionsTotal > 1 {
                Image(systemName: request.focus.icon).font(.system(size: 11, weight: .black))
                Text("\(request.focus.label[state.native].uppercased()) · \(request.sessionNumber)/\(request.sessionsTotal)")
                    .font(.heading(11)).kerning(0.7)
            } else if let title = request.customTitle {
                Image(systemName: "dumbbell.fill").font(.system(size: 11, weight: .black))
                Text(title[state.native].uppercased()).font(.heading(11)).kerning(0.7)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(request.mode == .test ? Palette.purple : request.focus.tint.deep)
        .padding(.leading, 34)
    }

    // MARK: - Footer: check / continue + feedback

    @ViewBuilder
    private func footer(_ engine: LessonEngine) -> some View {
        let verdict = engine.verdict
        if engine.current?.kind == .match {
            // the matching game grades itself: no action bar at all
            Color.clear.frame(height: 0)
        } else {
        VStack(spacing: 12) {
            if let verdict {
                feedbackBanner(verdict, engine: engine)
            }

            HStack(spacing: 12) {
                if verdict == nil, engine.current?.kind == .speak {
                    Button {
                        Feedback.tap(); engine.skipSpeaking()
                    } label: {
                        Text(S.cantSpeak[state.native])
                            .font(.heading(13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .buttonStyle(.chunky(Palette.card, Palette.strokeDeep, text: Palette.inkSoft, height: 50))
                }

                if engine.current?.kind != .match {
                    Button {
                        if verdict == nil { performCheck(engine) } else { performContinue(engine) }
                    } label: {
                        if engine.checking {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text(S.doubleChecking[state.native])
                            }
                        } else {
                            Text(verdict == nil ? S.checkAnswer[state.native] : S.continueBtn[state.native])
                        }
                    }
                    .buttonStyle(.chunky(buttonFill(verdict), buttonEdge(verdict)))
                    .disabled(verdict == nil && !engine.canCheck)
                    .opacity(verdict == nil && !engine.canCheck ? 0.45 : 1)
                }
            }
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            (bannerTint(verdict)?.opacity(0.14) ?? Palette.bgElevated)
                .overlay(alignment: .top) { Palette.stroke.frame(height: 1.5).opacity(verdict == nil ? 1 : 0) }
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.easeOut(duration: 0.18), value: engine.verdict)
        }
    }

    private func bannerTint(_ v: Verdict?) -> Color? {
        switch v {
        case .correct, .almost, .alternative: return Palette.green
        case .wrong: return Palette.red
        case nil: return nil
        }
    }
    private func buttonFill(_ v: Verdict?) -> Color {
        switch v {
        case .wrong: return Palette.red
        default: return Palette.green
        }
    }
    private func buttonEdge(_ v: Verdict?) -> Color {
        switch v {
        case .wrong: return Palette.redDeep
        default: return Palette.greenDeep
        }
    }

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
            return FeedbackLine(label: S.courseSays[state.native], text: canonical,
                                meaning: ex.meaning(of: canonical))
        }
        let raw = engine.givenAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let key = Grader.normalise(raw)
        let accepted = Grader.alternatives(ex.answer).map(Grader.normalise)
        guard !accepted.contains(key), key != Grader.normalise(ex.solution) else { return nil }
        return FeedbackLine(label: ex.kind == .speak ? S.heardYou[state.native] : S.yourAnswer[state.native],
                            text: raw,
                            meaning: ex.meaning(of: raw))
    }

    private func render(_ line: FeedbackLine, size: CGFloat, tint: Color) -> Text {
        var out = Text("")
        if let label = line.label {
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
        let ex = engine.current
        let solution = ex.flatMap { solutionLine(v, ex: $0, engine: engine) }
        let given = ex.flatMap { givenLine(v, ex: $0, engine: engine) }
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: {
                switch v {
                case .correct: return "checkmark.circle.fill"
                case .alternative: return "checkmark.circle.badge.questionmark.fill"
                case .almost: return "exclamationmark.circle.fill"
                case .wrong: return "xmark.circle.fill"
                }
            }())
            .font(.system(size: 26, weight: .black))
            .foregroundStyle(bannerTint(v) ?? Palette.green)

            VStack(alignment: .leading, spacing: 3) {
                switch v {
                case .correct:
                    Text(S.correct[state.native])
                        .font(.heading(17)).foregroundStyle(Palette.greenDeep)
                case .alternative:
                    Text(S.alsoRight[state.native])
                        .font(.heading(17)).foregroundStyle(Palette.greenDeep)
                case .almost:
                    Text(S.almost[state.native]).font(.heading(15)).foregroundStyle(Palette.greenDeep)
                case .wrong:
                    Text(S.wrong[state.native]).font(.heading(15)).foregroundStyle(Palette.redDeep)
                }

                if let solution {
                    render(solution, size: 16, tint: Palette.ink)
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
                if let ex, ex.kind == .speak, let score = engine.speechScore {
                    Text("\(Int(score * 100))%")
                        .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                }
                // the note only earns its line when it says something the
                // translation above has not already said
                if let ex, let hint = ex.hint, ex.kind != .speak,
                   hint != solution?.meaning?.text, case .wrong = v {
                    Text(hint).font(.plain(13)).foregroundStyle(Palette.inkFaint)
                }
            }
            Spacer(minLength: 0)

            if let ex, let audio = ex.audioText ?? (ex.answerLanguage == state.target ? ex.answer : nil) {
                Button {
                    SpeechService.shared.speak(audio, language: state.target, rate: state.settings.speechRate)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(bannerTint(v) ?? Palette.green)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func performCheck(_ engine: LessonEngine) {
        let v = engine.grade()
        guard let ex = engine.current else { return }

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

    /// Records the verdict, and pays for it.
    private func settle(_ v: Verdict, ex: Exercise, engine: LessonEngine) {
        withAnimation(.easeOut(duration: 0.18)) { engine.commit(v) }
        if v.isAccepted {
            Feedback.success(); Feedback.dingCorrect()
        } else {
            Feedback.failure(); Feedback.dingWrong()
            if request.consumesHearts {
                state.loseHeart()
                if state.hearts == 0 { outOfHearts = true }
            }
        }
        state.gradePair(ex.pair, correct: v.isAccepted)

        // read the answer back on production exercises
        guard ex.answerLanguage == state.target, ex.kind != .speak else { return }
        switch v {
        case .correct:
            SpeechService.shared.speak(ex.answer, language: state.target, rate: state.settings.speechRate)
        case .alternative:
            // her own wording is the one worth hearing back
            SpeechService.shared.speak(engine.givenAnswer, language: state.target,
                                       rate: state.settings.speechRate)
        case .almost, .wrong:
            break
        }
    }

    private func performContinue(_ engine: LessonEngine) {
        Feedback.tap()
        SpeechService.shared.stop()
        withAnimation(.easeInOut(duration: 0.2)) { engine.advance() }
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
        withAnimation(.spring(response: 0.5)) {
            results = SessionResults(xp: passed == false ? 0 : xp,
                                     accuracy: acc,
                                     minutes: engine.minutes,
                                     mistakes: engine.mistakePairs,
                                     title: request.customTitle ?? request.node?.title ?? S.lessonDone,
                                     testPassed: passed)
        }
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
