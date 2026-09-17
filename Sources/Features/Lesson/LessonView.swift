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
                        Text(verdict == nil ? S.checkAnswer[state.native] : S.continueBtn[state.native])
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
        case .correct, .almost: return Palette.green
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

    @ViewBuilder
    private func feedbackBanner(_ v: Verdict, engine: LessonEngine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: {
                switch v {
                case .correct: return "checkmark.circle.fill"
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
                case .almost(let fix):
                    Text(S.almost[state.native]).font(.heading(15)).foregroundStyle(Palette.greenDeep)
                    Text(fix).font(.body(16)).foregroundStyle(Palette.ink)
                case .wrong(let expected):
                    Text(S.wrong[state.native]).font(.heading(15)).foregroundStyle(Palette.redDeep)
                    Text(expected).font(.body(16)).foregroundStyle(Palette.ink)
                }
                if let ex = engine.current, ex.kind == .speak, let score = engine.speechScore {
                    Text("\(Int(score * 100))%")
                        .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                }
                if let ex = engine.current, let hint = ex.hint, ex.kind != .speak,
                   case .wrong = v {
                    Text(hint).font(.plain(13)).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)

            if let ex = engine.current, let audio = ex.audioText ?? (ex.answerLanguage == state.target ? ex.answer : nil) {
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
        let v = engine.check()
        switch v {
        case .correct, .almost:
            Feedback.success(); Feedback.dingCorrect()
        case .wrong:
            Feedback.failure(); Feedback.dingWrong()
            if request.consumesHearts {
                state.loseHeart()
                if state.hearts == 0 { outOfHearts = true }
            }
        }
        if let ex = engine.current {
            state.gradePair(ex.pair, correct: { if case .wrong = v { return false } else { return true } }())
        }
        // read the answer back on production exercises
        if let ex = engine.current, ex.answerLanguage == state.target, ex.kind != .speak {
            if case .correct = v {
                SpeechService.shared.speak(ex.answer, language: state.target, rate: state.settings.speechRate)
            }
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
