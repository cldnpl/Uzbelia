import SwiftUI

/// The writing chapter, on screen: a messaging thread with Anorcha, and the report
/// that follows it.
///
/// It looks like a chat app on purpose. A page headed "Produzione scritta" with a
/// text box under it gets three words and a shrug; the same request inside a
/// conversation, from someone who is waiting for an answer, gets a paragraph.
struct ChatChapterView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    let chapter: WritingChapter
    let node: PathNode
    var onFinish: (() -> Void)?

    @State private var engine: ChatEngine?
    @State private var quitDialog: GlassDialog?
    @State private var recorded = false
    @State private var streak: StreakMoment?
    @FocusState private var writing: Bool

    private var lang: Language { state.native }

    var body: some View {
        ZStack {
            AuroraBackground(mood: .lesson)
            if let engine {
                switch engine.phase {
                case .reviewing: building(engine)
                case .done: recap(engine)
                default: thread(engine)
                }
            } else {
                ProgressView().tint(Palette.brand)
            }
        }
        .task {
            guard engine == nil else { return }
            let new = ChatEngine(chapter: chapter, target: state.target)
            engine = new
            await new.begin(provider: state.aiProvider, apiKey: state.aiKey)
        }
        .glassDialog($quitDialog)
        .streakCelebration($streak) { onFinish?(); dismiss() }
    }

    // MARK: - The thread

    private func thread(_ engine: ChatEngine) -> some View {
        VStack(spacing: 0) {
            header(engine)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        Text(S.tapToTranslate[lang])
                            .font(.heading(11)).foregroundStyle(Palette.inkSoft)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .glassCapsule(material: false, shadow: false)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)

                        ForEach(engine.messages) { message in
                            bubble(message, engine: engine).id(message.id)
                        }
                        if engine.phase == .thinking || engine.phase == .opening {
                            typingBubble.id("typing")
                        }
                        Color.clear.frame(height: 4).id("bottom")
                    }
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.bottom, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: engine.messages.count) { _, _ in scroll(proxy) }
                .onChange(of: engine.phase) { _, _ in scroll(proxy) }
                .onAppear { scroll(proxy, animated: false) }
            }

            composer(engine)
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let jump = { proxy.scrollTo("bottom", anchor: .bottom) }
        if animated { withAnimation(.easeOut(duration: 0.25)) { jump() } } else { jump() }
    }

    private func header(_ engine: ChatEngine) -> some View {
        HStack(spacing: 12) {
            GlassCircleButton(icon: "xmark", size: 40, tint: Palette.inkSoft,
                              accessibility: S.writingEndEarly[lang]) {
                Feedback.tap()
                quitDialog = GlassDialog(title: S.writingEndEarly[lang], message: S.writingEndMsg[lang],
                                         confirm: S.confirm[lang], cancel: S.cancel[lang],
                                         icon: "bubble.left.and.text.bubble.right.fill") {
                    if !engine.records.isEmpty { engine.finishEarly() } else { dismiss() }
                }
            }

            MascotBubble(mood: engine.phase == .thinking ? .think : .happy, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Anorcha").font(.heading(16)).foregroundStyle(Palette.ink)
                Text(engine.phase == .thinking ? S.anorchaTyping[lang]
                                               : chapter.theme.title[lang])
                    .font(.plain(11.5)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(engine.written)/\(chapter.turns)")
                    .font(.heading(14)).foregroundStyle(UnitAccent.writing.deep)
                ProgressBar(value: engine.progress, tint: UnitAccent.writing.main, height: 6)
                    .frame(width: 66)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glass(radius: 28)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func bubble(_ message: ChatEngine.Message, engine: ChatEngine) -> some View {
        let mine = message.who == .learner
        let shown = engine.revealed.contains(message.id)
        HStack {
            if mine { Spacer(minLength: 44) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.plain(15))
                    .foregroundStyle(mine ? .white : Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                if shown, let translation = message.translation {
                    Text(translation)
                        .font(.plain(12.5))
                        .foregroundStyle(mine ? .white.opacity(0.75) : Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 15).padding(.vertical, 11)
            .background {
                let shape = UnevenRoundedRectangle(
                    topLeadingRadius: 22, bottomLeadingRadius: mine ? 22 : 6,
                    bottomTrailingRadius: mine ? 6 : 22, topTrailingRadius: 22,
                    style: .continuous)
                if mine {
                    shape.fill(Gradients.primary)
                        .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.25), .clear],
                                                           startPoint: .top, endPoint: .center)))
                        .shadow(color: Palette.brand.opacity(0.3), radius: 10, y: 5)
                } else {
                    GlassPane(shape: shape, tint: nil, material: false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard message.translation != nil else { return }
                Feedback.tap()
                withAnimation(.easeOut(duration: 0.18)) {
                    if shown { engine.revealed.remove(message.id) }
                    else { engine.revealed.insert(message.id) }
                }
            }
            if !mine { Spacer(minLength: 44) }
        }
        .transition(.move(edge: mine ? .trailing : .leading).combined(with: .opacity))
    }

    private var typingBubble: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Palette.inkFaint)
                        .frame(width: 6, height: 6)
                        .opacity(0.4)
                        .modifier(TypingDot(delay: Double(i) * 0.18))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glass(radius: 22, material: false)
            Spacer(minLength: 44)
        }
    }

    // MARK: - Writing

    private func composer(_ engine: ChatEngine) -> some View {
        @Bindable var engine = engine
        let short = engine.wordsInDraft < chapter.minimumWords
        return VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField(S.writeHere[lang], text: $engine.draft, axis: .vertical)
                    .font(.plain(16))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...5)
                    .focused($writing)
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .glass(radius: 24, tint: writing ? Palette.brand : nil)
                    .disabled(engine.phase != .yourTurn)

                Button {
                    Feedback.pop()
                    writing = false
                    Task { await engine.send(provider: state.aiProvider, apiKey: state.aiKey) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(engine.canSend ? .white : Palette.inkFaint)
                        .frame(width: 50, height: 50)
                        .background {
                            if engine.canSend {
                                Circle().fill(Gradients.primary)
                                    .shadow(color: Palette.brand.opacity(0.4), radius: 10, y: 5)
                            } else {
                                Circle().fill(Palette.locked)
                            }
                        }
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                .disabled(!engine.canSend)
            }

            HStack(spacing: 6) {
                Image(systemName: short ? "pencil" : "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(short ? Palette.inkSoft : Palette.greenDeep)
                Text("\(engine.wordsInDraft)/\(chapter.minimumWords) \(S.wordsShort[lang])")
                    .font(.heading(11)).foregroundStyle(short ? Palette.inkSoft : Palette.greenDeep)
                Spacer(minLength: 0)
                Text(engine.remaining <= 1 ? S.writingLastOne[lang]
                                           : "\(engine.remaining) \(S.writingLeft[lang])")
                    .font(.plain(11)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 9)
        .padding(.bottom, 10)
    }

    // MARK: - The report

    private func building(_ engine: ChatEngine) -> some View {
        VStack(spacing: 16) {
            MascotBubble(mood: .think, size: 120)
            ProgressView().tint(Palette.brand)
            Text(S.writingReview[lang])
                .font(.heading(15)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .task {
            await engine.buildReview(curriculum: state.curriculum,
                                     provider: state.aiProvider,
                                     apiKey: state.aiKey)
            register(engine)
        }
    }

    private func recap(_ engine: ChatEngine) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 10) {
                    MascotBubble(mood: engine.records.isEmpty ? .happy : .cheer, size: 104)
                    Text(engine.review?.headline[lang] ?? S.writingRecap[lang])
                        .font(.display(25)).foregroundStyle(Gradients.title)
                        .multilineTextAlignment(.center)
                    if engine.records.isEmpty {
                        Text(S.writingNoWords[lang])
                            .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

                if let stats = engine.review?.stats {
                    HStack(spacing: 10) {
                        statCard("\(stats.answered)", S.writingLeft[lang], UnitAccent.writing.main)
                        statCard("\(stats.words)", S.wordsShort[lang], Palette.brand)
                        statCard("\(stats.distinctWords)", S.statsWords[lang], Palette.teal)
                        statCard("+\(engine.xpEarned)", "XP", Palette.pink)
                    }
                }

                if let tips = engine.review?.tips, !tips.isEmpty {
                    SectionHeader(title: S.recapTips[lang].uppercased())
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(UnitAccent.writing.main).padding(.top, 2)
                                Text(tip[lang]).font(.plain(13)).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glass(radius: 22, tint: UnitAccent.writing.main)
                }

                if let turns = engine.review?.turns, !turns.isEmpty {
                    SectionHeader(title: S.recapDetail[lang].uppercased())
                    ForEach(turns) { turn in turnCard(turn) }
                }

                Button {
                    Feedback.pop()
                    register(engine)
                    if let moment = state.takeStreakMoment() {
                        streak = moment
                    } else {
                        onFinish?()
                        dismiss()
                    }
                } label: { Text(S.done[lang]) }
                .buttonStyle(.primary(.violet))
                .padding(.top, 6)
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.bottom, 28)
        }
    }

    private func statCard(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.display(17)).foregroundStyle(tint)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.heading(8.5)).kerning(0.4)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glass(radius: 18, tint: tint, material: false)
    }

    private func turnCard(_ turn: TurnReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(turn.question[state.target])
                .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(S.yourMessage[lang].uppercased())
                    .font(.heading(9)).kerning(0.6).foregroundStyle(Palette.inkFaint)
                Text(turn.said.isEmpty ? "—" : turn.said)
                    .font(.plain(14)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(turn.corrections) { fix in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: fix.kind.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.redDeep).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(fix.original).font(.plain(12.5))
                                .strikethrough().foregroundStyle(Palette.inkSoft)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold)).foregroundStyle(Palette.inkFaint)
                            Text(fix.suggestion).font(.heading(12.5)).foregroundStyle(Palette.green)
                        }
                        Text(fix.note[lang]).font(.plain(11.5)).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let better = turn.betterVersion, !better.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(S.betterWay[lang])
                        .font(.heading(10)).foregroundStyle(Palette.inkFaint)
                    Text(better).font(.plain(13.5)).foregroundStyle(Palette.green)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glass(radius: 16, tint: Palette.green, material: false, shadow: false)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 24)
    }

    // MARK: - Writing it down

    /// Marks the chapter done exactly once, however the learner leaves it.
    private func register(_ engine: ChatEngine) {
        guard !recorded, !engine.records.isEmpty else { return }
        recorded = true
        let minutes = max(1, Int(Date().timeIntervalSince(engine.startedAt) / 60))
        state.finishSession(nodeID: node.id,
                            xpEarned: engine.xpEarned,
                            accuracy: engine.accuracy,
                            minutes: minutes,
                            mistakes: [])
        // words she used unprompted count as practice, same as anywhere else
        for pair in engine.practisedPairs(from: state.curriculum) {
            state.gradePair(pair, correct: true)
        }
        state.save()
    }
}

/// The three dots, breathing.
private struct TypingDot: ViewModifier {
    let delay: Double
    @State private var up = false
    func body(content: Content) -> some View {
        content
            .opacity(up ? 1 : 0.35)
            .offset(y: up ? -2 : 0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay),
                       value: up)
            .onAppear { up = true }
    }
}
