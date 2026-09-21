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
    @State private var showQuit = false
    @State private var recorded = false
    @FocusState private var writing: Bool

    private var lang: Language { state.native }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if let engine {
                switch engine.phase {
                case .reviewing: building(engine)
                case .done: recap(engine)
                default: thread(engine)
                }
            } else {
                ProgressView().tint(Palette.purple)
            }
        }
        .task {
            guard engine == nil else { return }
            let new = ChatEngine(chapter: chapter, native: state.native)
            engine = new
            await new.begin(provider: state.aiProvider, apiKey: state.aiKey)
        }
        .alert(S.writingEndEarly[lang], isPresented: $showQuit) {
            Button(S.cancel[lang], role: .cancel) {}
            Button(S.confirm[lang]) {
                if let engine, !engine.records.isEmpty { engine.finishEarly() } else { dismiss() }
            }
        } message: { Text(S.writingEndMsg[lang]) }
    }

    // MARK: - The thread

    private func thread(_ engine: ChatEngine) -> some View {
        VStack(spacing: 0) {
            header(engine)
            Divider().overlay(Palette.stroke)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        Text(S.tapToTranslate[lang])
                            .font(.plain(11)).foregroundStyle(Palette.inkFaint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)

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
            Button {
                Feedback.tap(); showQuit = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .black)).foregroundStyle(Palette.inkFaint)
            }
            .buttonStyle(.plain)

            Mascot(mood: engine.phase == .thinking ? .think : .happy, size: 38)

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
                    .font(.heading(14)).foregroundStyle(Palette.purple)
                ProgressBar(value: engine.progress, tint: Palette.purple)
                    .frame(width: 62)
            }
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.vertical, 10)
        .background(Palette.bgElevated)
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
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16, bottomLeadingRadius: mine ? 16 : 5,
                    bottomTrailingRadius: mine ? 5 : 16, topTrailingRadius: 16,
                    style: .continuous)
                    .fill(mine ? Palette.purple : Palette.card)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16, bottomLeadingRadius: mine ? 16 : 5,
                    bottomTrailingRadius: mine ? 5 : 16, topTrailingRadius: 16,
                    style: .continuous)
                    .stroke(mine ? .clear : Palette.stroke, lineWidth: 1.5)
            )
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
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1.5))
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
                    .font(.plain(15))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...5)
                    .focused($writing)
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 2))
                    .disabled(engine.phase != .yourTurn)

                Button {
                    Feedback.pop()
                    writing = false
                    Task { await engine.send(provider: state.aiProvider, apiKey: state.aiKey) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(engine.canSend ? Palette.purple : Palette.locked))
                }
                .buttonStyle(.plain)
                .disabled(!engine.canSend)
            }

            HStack(spacing: 6) {
                Image(systemName: short ? "pencil" : "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(short ? Palette.inkFaint : Palette.green)
                Text("\(engine.wordsInDraft)/\(chapter.minimumWords) \(S.wordsShort[lang])")
                    .font(.plain(11)).foregroundStyle(short ? Palette.inkFaint : Palette.green)
                Spacer(minLength: 0)
                Text(engine.remaining <= 1 ? S.writingLastOne[lang]
                                           : "\(engine.remaining) \(S.writingLeft[lang])")
                    .font(.plain(11)).foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .background(
            Palette.bgElevated
                .overlay(alignment: .top) { Palette.stroke.frame(height: 1.5) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - The report

    private func building(_ engine: ChatEngine) -> some View {
        VStack(spacing: 16) {
            Mascot(mood: .think, size: 110)
            ProgressView().tint(Palette.purple)
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
                VStack(spacing: 9) {
                    Mascot(mood: engine.records.isEmpty ? .happy : .cheer, size: 92)
                    Text(engine.review?.headline[lang] ?? S.writingRecap[lang])
                        .font(.display(22)).foregroundStyle(Palette.ink)
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
                        statCard("\(stats.answered)", S.writingLeft[lang], Palette.purple)
                        statCard("\(stats.words)", S.wordsShort[lang], Palette.brand)
                        statCard("\(stats.distinctWords)", S.statsWords[lang], Palette.teal)
                        statCard("+\(engine.xpEarned)", "XP", Palette.amber)
                    }
                }

                if let tips = engine.review?.tips, !tips.isEmpty {
                    SectionHeader(title: S.recapTips[lang].uppercased())
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(Palette.amber).padding(.top, 2)
                                Text(tip[lang]).font(.plain(13)).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                        .fill(Palette.amber.opacity(0.12)))
                }

                if let turns = engine.review?.turns, !turns.isEmpty {
                    SectionHeader(title: S.recapDetail[lang].uppercased())
                    ForEach(turns) { turn in turnCard(turn) }
                }

                Button {
                    Feedback.pop()
                    register(engine)
                    onFinish?()
                    dismiss()
                } label: { Text(S.done[lang]) }
                .buttonStyle(.chunky(Palette.purple, Palette.purpleDeep))
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
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Palette.stroke, lineWidth: 1.5))
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
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Palette.redDeep).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(fix.original).font(.plain(12.5))
                                .strikethrough().foregroundStyle(Palette.inkSoft)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .black)).foregroundStyle(Palette.inkFaint)
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
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.greenSoft))
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            .stroke(Palette.stroke, lineWidth: 2))
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
