import SwiftUI

/// A free conversation with Anorcha: she asks, you answer in your own words, and at
/// the end you get a written report with the corrections.
struct VideoCallView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let level: CEFR

    @State private var engine: CallEngine?
    @State private var recognizer = RecognizerService.shared
    @State private var recording = false
    @State private var showKeyboard = false
    @State private var preparing = true
    @State private var avatarPulse = false
    @State private var streak: StreakMoment?
    @FocusState private var typing: Bool

    private var target: Language { state.target }

    var body: some View {
        ZStack {
            AuroraBackground(mood: .night)

            if preparing || engine == nil {
                preparingView
            } else if let engine {
                switch engine.phase {
                case .dialling: ringing(engine)
                case .reviewing: buildingReview(engine)
                case .ended: recap(engine)
                default: inCall(engine)
                }
            }
        }
        // a call is a night-time screen whatever the phone is set to: every glass
        // pane and every colour on it takes its dark variant
        .environment(\.colorScheme, .dark)
        // the celebration is a daytime screen, like the rest of the app
        .streakCelebration($streak) { dismiss() }
        .task { await prepare() }
        .onDisappear {
            SpeechService.shared.stop()
            recognizer.reset()
        }
    }

    // MARK: - Preparing the call

    /// The call opens on the planned greeting; with the assistant on, every line after
    /// it is written from her answers as they come. Nothing is generated up front, so
    /// the phone rings at once instead of after a round trip.
    private func prepare() async {
        guard engine == nil else { return }
        var plan = CallPlanner.plan(level: level, state: state)
        let context = CallPlanner.context(for: plan, level: level, state: state, target: target)
        let configured = AIClient.isAvailable(provider: state.aiProvider, key: state.aiKey,
                                              for: .conversation)
        plan.generatedByAI = configured

        let built = CallEngine(level: level, target: state.target, plan: plan)
        built.context = context
        built.live = configured
        await MainActor.run {
            engine = built
            preparing = false
            // a language the phone cannot hear is answered by typing from the start
            if !state.target.canBeHeard { showKeyboard = true }
        }
    }

    private var preparingView: some View {
        VStack(spacing: 18) {
            MascotBubble(mood: .think, size: 120)
            ProgressView().tint(Palette.pink)
            Text(S.callCalling[state.native])
                .font(.heading(15)).foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Ringing

    private func ringing(_ engine: CallEngine) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().strokeBorder(Palette.pink.opacity(0.25), lineWidth: 1)
                    .frame(width: avatarPulse ? 250 : 210, height: avatarPulse ? 250 : 210)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: avatarPulse)
                Circle()
                    .fill(RadialGradient(colors: [Palette.pink.opacity(0.35), .clear],
                                         center: .center, startRadius: 40, endRadius: 120))
                    .frame(width: 240, height: 240)
                    .scaleEffect(avatarPulse ? 1.05 : 0.9)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: avatarPulse)
                MascotBubble(mood: .happy, size: 170)
            }
            .onAppear { avatarPulse = true }

            VStack(spacing: 6) {
                Text("Anorcha").font(.display(30)).foregroundStyle(.white)
                Text(S.callCalling[state.native])
                    .font(.heading(15)).foregroundStyle(.white.opacity(0.65))
                HStack(spacing: 8) {
                    Text(level.label)
                        .font(.heading(13)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient(colors: Tone.pink.colors,
                                                                  startPoint: .leading, endPoint: .trailing)))
                    if let unit = engine.plan.focusUnit {
                        Text(unit.title[state.native])
                            .font(.plain(13)).foregroundStyle(Palette.pink)
                    }
                }
                .padding(.top, 6)
            }

            Text(S.callFreeAnswer[state.native])
                .font(.plain(13)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)

            Spacer()

            HStack(spacing: 54) {
                roundButton(icon: "phone.down.fill", accent: .red) { dismiss() }
                roundButton(icon: "video.fill", accent: .green) {
                    Feedback.pop()
                    withAnimation(.easeInOut) { engine.answerCall() }
                }
            }
            .padding(.bottom, 44)
        }
    }

    private func roundButton(icon: String, accent: UnitAccent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            OrbIcon(icon, accent: accent, size: 78, symbolScale: 0.34)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
    }

    // MARK: - In call

    private func inCall(_ engine: CallEngine) -> some View {
        VStack(spacing: 0) {
            topBar(engine)
            videoStage(engine)
            questionArea(engine)
            Spacer(minLength: 6)
            answerArea(engine)
        }
        .task(id: "\(engine.index)-\(engine.phase)") {
            switch engine.phase {
            case .anorchaSpeaking:
                guard let q = engine.question else { return }
                SpeechService.shared.speak(q.spoken(in: target), language: target,
                                           rate: state.settings.speechRate)
                try? await Task.sleep(for: .milliseconds(450))
                while SpeechService.shared.isSpeaking { try? await Task.sleep(for: .milliseconds(150)) }
                withAnimation { engine.anorchaFinishedSpeaking() }
            case .reacting:
                // in a live call this is where Anorcha reads what was just said and
                // writes her answer; offline it returns at once
                await engine.composeNextTurn(provider: state.aiProvider,
                                             apiKey: state.aiKey)
                if let reaction = engine.reaction {
                    SpeechService.shared.speak(reaction[target], language: target,
                                               rate: state.settings.speechRate)
                    try? await Task.sleep(for: .milliseconds(350))
                    while SpeechService.shared.isSpeaking { try? await Task.sleep(for: .milliseconds(150)) }
                }
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation { engine.advance() }
            default:
                break
            }
        }
    }

    private func topBar(_ engine: CallEngine) -> some View {
        HStack(spacing: 12) {
            Button {
                Feedback.tap(); SpeechService.shared.stop(); engine.hangUp()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Anorcha").font(.heading(16)).foregroundStyle(.white)
                Text("\(engine.elapsed) · \(S.callQuestionOf[state.native]) \(engine.questionNumber)/\(engine.questionTotal)")
                    .font(.plain(11.5)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if engine.plan.generatedByAI {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.purple)
            }
            Button {
                Feedback.tap(); engine.showSubtitles.toggle()
            } label: {
                Image(systemName: engine.showSubtitles ? "captions.bubble.fill" : "captions.bubble")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(engine.showSubtitles ? Palette.pink : .white.opacity(0.6))
            }
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 8).padding(.bottom, 8)
    }

    private func videoStage(_ engine: CallEngine) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x3B2F86).opacity(0.75), Color(hex: 0x5A3FB0).opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1.2))
                .overlay {
                    Mascot(mood: engine.phase == .reacting ? .cheer : .happy, size: 132)
                        .scaleEffect(SpeechService.shared.isSpeaking ? 1.05 : 1)
                        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                                   value: SpeechService.shared.isSpeaking)
                }
                .overlay(alignment: .topLeading) {
                    if SpeechService.shared.isSpeaking {
                        Label("Anorcha", systemImage: "waveform")
                            .font(.heading(11)).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .glassCapsule(material: false, shadow: false)
                            .padding(12)
                    }
                }
                .frame(height: 210)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x15132B).opacity(0.85))
                .overlay {
                    VStack(spacing: 5) {
                        Image(systemName: recording ? "waveform" : "person.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(recording ? Palette.pink : .white.opacity(0.45))
                            .scaleEffect(1 + CGFloat(recognizer.level) * 0.4)
                        if recording {
                            Text("• REC").font(.heading(9)).foregroundStyle(Palette.red)
                        }
                    }
                }
                .frame(width: 70, height: 92)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .padding(12)
        }
        .padding(.horizontal, Metrics.hPad)
    }

    @ViewBuilder
    private func questionArea(_ engine: CallEngine) -> some View {
        VStack(spacing: 10) {
            if engine.phase == .reacting, let reaction = engine.reaction {
                Text(reaction[target])
                    .font(.body(17)).foregroundStyle(Palette.green)
                    .padding(.top, 12)
                    .speakOnTap(reaction[target], language: target)
            } else if engine.phase == .reacting, engine.thinking {
                HStack(spacing: 7) {
                    ProgressView().tint(Palette.pink).scaleEffect(0.8)
                    Text(S.callThinking[state.native])
                        .font(.plain(13)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 12)
            } else if let q = engine.question, engine.showSubtitles {
                VStack(spacing: 6) {
                    if let lead = q.lead {
                        Text(lead[target])
                            .font(.plain(14)).foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    SpeakableText(text: q.text[target], language: target,
                                  font: .body(18), color: .white, alignment: .center)
                    if engine.showTranslation {
                        Text(q.spoken(in: state.native))
                            .font(.plain(13)).foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .glass(radius: 22, material: false, shadow: false)
            }

            if engine.phase != .reacting {
                HStack(spacing: 10) {
                    pill(icon: "character.book.closed.fill", label: S.callTranslate[state.native],
                         on: engine.showTranslation) { engine.showTranslation.toggle() }
                    pill(icon: "arrow.clockwise", label: S.listenAgain[state.native], on: false) {
                        if let q = engine.question {
                            SpeechService.shared.speak(q.spoken(in: target), language: target,
                                                       rate: state.settings.speechRate)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 10)
    }

    private func pill(icon: String, label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Feedback.tap(); action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(label).font(.heading(11))
            }
            .foregroundStyle(on ? .white : .white.opacity(0.7))
            .padding(.horizontal, 13).padding(.vertical, 8)
            .glassCapsule(tint: on ? Palette.pink : nil, material: false, shadow: false)
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Answering, in your own words

    @ViewBuilder
    private func answerArea(_ engine: CallEngine) -> some View {
        VStack(spacing: 12) {
            if engine.phase == .yourTurn {
                if recording {
                    VStack(spacing: 6) {
                        Text(S.callListening[state.native])
                            .font(.heading(14)).foregroundStyle(Palette.pink)
                        if !recognizer.transcript.isEmpty {
                            Text(recognizer.transcript)
                                .font(.body(15)).foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .opacity(recognizer.isPartial ? 0.6 : 1)
                                .animation(.easeOut(duration: 0.15), value: recognizer.transcript)
                                .padding(.horizontal, 20)
                        }
                    }
                } else if recognizer.isTranscribing {
                    HStack(spacing: 7) {
                        ProgressView().tint(Palette.pink).scaleEffect(0.8)
                        Text(S.transcribing[state.native])
                            .font(.heading(14)).foregroundStyle(Palette.pink)
                    }
                } else if !recognizer.transcript.isEmpty {
                    Text(recognizer.transcript)
                        .font(.body(15)).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 20)
                } else if !showKeyboard {
                    Text(S.callSpeakNow[state.native])
                        .font(.plain(13)).foregroundStyle(.white.opacity(0.55))
                }
            }

            if showKeyboard, engine.phase == .yourTurn {
                HStack(spacing: 8) {
                    TextField(S.typeHere[state.native], text: Binding(
                        get: { engine.typed }, set: { engine.typed = $0 }), axis: .vertical)
                        .font(.body(15))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1...3)
                        .focused($typing)
                        .padding(13)
                        .glass(radius: 20, material: false, shadow: false)
                    Button {
                        Feedback.pop()
                        engine.submit(engine.typed, typed: true)
                        typing = false
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(LinearGradient(colors: Tone.pink.colors,
                                                                     startPoint: .top, endPoint: .bottom)))
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            HStack(spacing: 22) {
                smallControl(icon: showKeyboard ? "keyboard.chevron.compact.down" : "keyboard",
                             accent: nil) {
                    showKeyboard.toggle()
                    typing = showKeyboard
                }
                micButton(engine)
                smallControl(icon: "phone.down.fill", accent: .red) {
                    SpeechService.shared.stop(); recognizer.reset(); engine.hangUp()
                }
            }
            .frame(maxWidth: .infinity)

            if engine.phase == .yourTurn {
                Button {
                    Feedback.tap(); recognizer.reset(); engine.skip()
                } label: {
                    Text(S.callSkipTurn[state.native])
                        .font(.heading(12)).foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.bottom, 18)
    }

    private func micButton(_ engine: CallEngine) -> some View {
        Button {
            Feedback.pop()
            guard !recognizer.isTranscribing else { return }
            if recording { stopRecording(engine) } else { startRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.pink.opacity(0.4), .clear],
                                         center: .center, startRadius: 30, endRadius: 70))
                    .frame(width: 130 + CGFloat(recognizer.level * 40),
                           height: 130 + CGFloat(recognizer.level * 40))
                    .opacity(recording ? 1 : 0)
                OrbIcon(recording ? "stop.fill" : "mic.fill", accent: recording ? .red : .pink,
                        size: 84, symbolScale: 0.36)
            }
            .frame(width: 110, height: 100)
        }
        .buttonStyle(PressableStyle(scale: 0.93))
        // no recogniser knows this language yet: the keyboard is the way to answer
        .disabled(engine.phase != .yourTurn || !target.canBeHeard)
        .opacity(engine.phase == .yourTurn && target.canBeHeard ? 1 : 0.4)
    }

    private func smallControl(icon: String, accent: UnitAccent?, action: @escaping () -> Void) -> some View {
        Button {
            Feedback.tap(); action()
        } label: {
            if let accent {
                OrbIcon(icon, accent: accent, size: 56, symbolScale: 0.34)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .glassCircle(material: false)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.92))
    }

    private func startRecording() {
        recognizer.reset()
        recording = true
        Task { await recognizer.start(language: target) }
    }

    private func stopRecording(_ engine: CallEngine) {
        recording = false
        // the same waiting the pronunciation exercises do: an Uzbek answer is
        // transcribed by whoever can actually hear Uzbek, which takes a moment
        Task {
            await recognizer.stopAndTranscribe()
            engine.submit(recognizer.transcript, typed: false)
            recognizer.reset()
        }
    }

    // MARK: - Building the report

    private func buildingReview(_ engine: CallEngine) -> some View {
        VStack(spacing: 18) {
            MascotBubble(mood: .think, size: 120)
            ProgressView().tint(Palette.pink)
            Text(S.callBuilding[state.native])
                .font(.heading(15)).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .task {
            await engine.buildReview(curriculum: state.curriculum,
                                     provider: state.aiProvider,
                                     apiKey: state.aiKey)
            state.addXP(engine.xpEarned, minutes: max(1, engine.records.count / 3))
            // so the next call knows where it has already been
            state.rememberCallQuestions(engine.askedQuestions())
            state.save()
        }
    }

    // MARK: - The recap

    private func recap(_ engine: CallEngine) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 10) {
                    MascotBubble(mood: .cheer, size: 104)
                    Text(engine.review?.headline[state.native] ?? S.recapTitle[state.native])
                        .font(.display(24)).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if let source = engine.review?.source {
                        Label(source == .ai ? S.callAIOn[state.native] : S.callAIOff[state.native],
                              systemImage: source == .ai ? "sparkles" : "iphone.gen3")
                            .font(.heading(11)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                if let stats = engine.review?.stats {
                    HStack(spacing: 10) {
                        statCard("\(stats.answered)/\(stats.total)", S.recapAnswers[state.native], Palette.green)
                        statCard("\(stats.words)", S.recapWords[state.native], Palette.brand)
                        statCard("\(stats.distinctWords)", S.recapDistinct[state.native], Palette.purple)
                        statCard("+\(engine.xpEarned)", "XP", Palette.amber)
                    }
                }

                if let tips = engine.review?.tips, !tips.isEmpty {
                    sectionTitle(S.recapTips[state.native])
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.amber)
                                    .padding(.top, 2)
                                Text(tip[state.native])
                                    .font(.plain(13.5)).foregroundStyle(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .glass(radius: 22, tint: Palette.amber, material: false, shadow: false)
                }

                sectionTitle(S.recapDetail[state.native])
                ForEach(engine.review?.turns ?? []) { turn in
                    turnCard(turn)
                }

                VStack(spacing: 10) {
                    Button {
                        Feedback.pop()
                        engine.restart(with: CallPlanner.plan(level: level, state: state))
                    } label: { Text(S.callAgain[state.native]) }
                    .buttonStyle(.primary(.pink))

                    Button {
                        Feedback.tap()
                        if let moment = state.takeStreakMoment() { streak = moment } else { dismiss() }
                    } label: { Text(S.close[state.native]) }
                    .buttonStyle(.glass(nil, text: .white))
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.bottom, 30)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.heading(12)).kerning(1.1)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 4)
    }

    private func statCard(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.display(17)).foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.heading(8.5)).kerning(0.4)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glass(radius: 18, tint: tint, material: false, shadow: false)
    }

    private func turnCard(_ turn: TurnReview) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(turn.question[target])
                .font(.heading(14)).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .speakOnTap(turn.question[target], language: target)

            HStack(spacing: 7) {
                statusBadge(turn.status)
                Spacer(minLength: 0)
            }

            if turn.said.isEmpty {
                Text("—").font(.body(15)).foregroundStyle(.white.opacity(0.4))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(S.recapYouSaid[state.native].uppercased())
                        .font(.heading(9)).kerning(0.6).foregroundStyle(.white.opacity(0.4))
                    Text(turn.said)
                        .font(.body(15)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .speakOnTap(turn.said, language: target)
                }
            }

            if turn.corrections.isEmpty, turn.status == .good {
                Label(S.recapNoIssues[state.native], systemImage: "checkmark.circle.fill")
                    .font(.plain(12.5)).foregroundStyle(Palette.green)
            }

            ForEach(turn.corrections) { fix in
                correctionRow(fix)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 24, material: false)
    }

    private func statusBadge(_ status: TurnReview.Status) -> some View {
        let (text, tint): (String, Color) = {
            switch status {
            case .good: return (S.recapOK[state.native], Palette.green)
            case .tooShort: return (S.recapShort[state.native], Palette.amber)
            case .wrongLanguage: return (S.recapWrongLang[state.native], Palette.red)
            case .skipped: return (S.recapSkipped[state.native], Palette.inkFaint)
            }
        }()
        return Text(text.uppercased())
            .font(.heading(9.5)).kerning(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.18)))
    }

    private func correctionRow(_ fix: Correction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: fix.kind.icon)
                    .font(.system(size: 10, weight: .bold))
                Text(fix.kind.label[state.native].uppercased())
                    .font(.heading(9)).kerning(0.5)
            }
            .foregroundStyle(Palette.pink)

            if !fix.suggestion.isEmpty {
                (Text(fix.suggestion).font(.body(15)).foregroundStyle(.white)
                 + Text("  \(S.recapInstead[state.native]) ").font(.plain(12)).foregroundStyle(.white.opacity(0.45))
                 + Text(fix.original).font(.plain(13)).foregroundStyle(.white.opacity(0.5)).strikethrough())
                    .fixedSize(horizontal: false, vertical: true)
                    .speakOnTap(fix.suggestion, language: target)
            }
            Text(fix.note[state.native])
                .font(.plain(12.5)).foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 16, tint: Palette.pink, material: false, shadow: false)
    }
}
