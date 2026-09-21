import SwiftUI

struct PathView: View {
    @Environment(AppState.self) private var state
    @State private var level: CEFR = .a1
    @State private var selectedNode: PathNode?
    @State private var activeSession: SessionRequest?
    @State private var guidebookUnit: Unit?
    @State private var testTarget: TestTarget?
    /// The writing chapter is not a set of exercises, so it opens its own screen.
    @State private var writingNode: PathNode?

    var body: some View {
        VStack(spacing: 0) {
            StatsHeader(levelLabel: level.label)
            levelPicker
            Divider().overlay(Palette.stroke)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(units) { unit in
                            unitSection(unit).id(unit.id)
                        }
                        levelFooter
                            .padding(.top, 8)
                            .padding(.bottom, 30)
                    }
                    .padding(.top, 10)
                }
                .onAppear { scrollToCurrent(proxy) }
                .onChange(of: level) { _, _ in scrollToCurrent(proxy) }
            }
        }
        .background(Palette.bg)
        .onAppear { level = startingLevel }
        .sheet(item: $selectedNode) { node in
            NodeSheet(node: node, level: level) { req in
                selectedNode = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSession = req }
            } startTest: { target in
                selectedNode = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { testTarget = target }
            } startWriting: { chapterNode in
                selectedNode = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { writingNode = chapterNode }
            }
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $guidebookUnit) { unit in GuidebookView(unit: unit) }
        .sheet(item: $testTarget) { target in
            TestIntroSheet(target: target) { req in
                testTarget = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSession = req }
            }
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $activeSession) { req in
            LessonView(request: req)
        }
        .fullScreenCover(item: $writingNode) { node in
            if case .writing(let chapter) = node.kind {
                ChatChapterView(chapter: chapter, node: node)
            }
        }
    }

    // MARK: - Data

    private var units: [Unit] {
        state.curriculum.levels.first { $0.level == level }?.units ?? []
    }

    private var startingLevel: CEFR {
        CEFR.allCases.last { state.isLevelUnlocked($0) && state.completion(of: $0) < 1 }
            ?? CEFR.allCases.last { state.isLevelUnlocked($0) }
            ?? .a1
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard let current = state.currentNodeID(in: level),
              let unitID = state.curriculum.allUnits.first(where: { unit in
                  unit.nodes(level: level, index: 0).contains { $0.id == current }
              })?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut) { proxy.scrollTo(unitID, anchor: .top) }
        }
    }

    // MARK: - Level picker

    private var levelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CEFR.allCases) { lvl in
                    let unlocked = state.isLevelUnlocked(lvl)
                    Button {
                        Feedback.tap()
                        if unlocked {
                            withAnimation { level = lvl }
                        } else {
                            testTarget = PlacementTest.target(unlocking: lvl, state: state)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if !unlocked {
                                Image(systemName: "lock.fill").font(.system(size: 11, weight: .black))
                            }
                            Text(lvl.label).font(.heading(14))
                            Text("\(Int(state.completion(of: lvl) * 100))%")
                                .font(.plain(11.5))
                                .opacity(unlocked ? 0.75 : 0)
                        }
                        .foregroundStyle(level == lvl ? .white : (unlocked ? Palette.ink : Palette.inkFaint))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(level == lvl ? Palette.brand : Palette.locked))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.vertical, 9)
        }
        .background(Palette.bg)
    }

    // MARK: - Unit section

    @ViewBuilder
    private func unitSection(_ unit: Unit) -> some View {
        let nodes = unit.nodes(level: level, index: 0)
        let currentID = state.currentNodeID(in: level)
        VStack(spacing: 0) {
            unitBanner(unit)
                .padding(.horizontal, Metrics.hPad)
                .padding(.bottom, 16)

            ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                NodeBubble(node: node,
                           accent: unit.accent,
                           isUnlocked: state.isUnlocked(node),
                           isCurrent: currentID == node.id,
                           sessionsDone: state.sessionsDone(node.id)) {
                    Feedback.pop()
                    selectedNode = node
                }
                .offset(x: waveOffset(idx))
                .padding(.vertical, 1)
            }
            .padding(.bottom, 14)
        }
    }

    private func waveOffset(_ i: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, 46, 70, 46, 0, -46, -70, -46]
        return pattern[i % pattern.count]
    }

    private func unitBanner(_ unit: Unit) -> some View {
        let progress = state.completion(ofUnit: unit, level: level)
        return HStack(spacing: 14) {
            Image(systemName: unit.icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(.white.opacity(0.22)))
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.title[state.native])
                    .font(.heading(18)).foregroundStyle(.white)
                if let sub = unit.subtitle {
                    Text(sub[state.native])
                        .font(.plain(12.5)).foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
                ProgressBar(value: progress, tint: .white, track: .white.opacity(0.25), height: 8)
                    .frame(height: 8)
                    .padding(.top, 2)
            }
            Button {
                Feedback.tap(); guidebookUnit = unit
            } label: {
                Image(systemName: "book.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(LinearGradient(colors: [unit.accent.main, unit.accent.deep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .background(
            RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(unit.accent.deep).offset(y: Metrics.chunkDepth)
        )
    }

    private var levelFooter: some View {
        VStack(spacing: 12) {
            if state.completion(of: level) >= 1 {
                Mascot(mood: .cheer, size: 80)
                Text(state.native == .it ? "Livello \(level.label) completato! 🎉"
                                         : "\(level.label) darajasi tugadi! 🎉")
                    .font(.heading(17)).foregroundStyle(Palette.ink)
                if let next = CEFR.allCases.first(where: { $0 > level }) {
                    Button {
                        Feedback.pop(); state.unlock(level: next); withAnimation { level = next }
                    } label: { Text(next.label) }
                    .buttonStyle(.chunky(Palette.purple, Palette.purpleDeep, stretch: false))
                }
            } else {
                Mascot(mood: .think, size: 62)
                Text(state.native == .it ? "Ancora \(remaining) sessioni in questo livello"
                                         : "Ushbu darajada yana \(remaining) mashg'ulot")
                    .font(.plain(13)).foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var remaining: Int {
        state.nodeIDs(for: level).reduce(0) { total, id in
            total + max(0, state.requiredSessions(forNodeID: id) - state.sessionsDone(id))
        }
    }
}

// MARK: - A single node on the path

struct NodeBubble: View {
    @Environment(AppState.self) private var state
    let node: PathNode
    let accent: UnitAccent
    let isUnlocked: Bool
    let isCurrent: Bool
    let sessionsDone: Int
    let action: () -> Void

    @State private var pulse = false

    private var required: Int { node.requiredSessions }
    private var done: Bool { sessionsDone >= required }
    private var ratio: Double { min(1, Double(sessionsDone) / Double(max(1, required))) }
    private var fill: Color { isUnlocked ? (done ? Palette.amber : accent.main) : Palette.locked }
    private var edge: Color { isUnlocked ? (done ? Palette.amberDeep : accent.deep) : Palette.lockedDeep }

    var body: some View {
        VStack(spacing: 6) {
            if isCurrent && isUnlocked {
                Text(callToAction)
                    .font(.heading(12)).kerning(0.6)
                    .foregroundStyle(done ? Palette.amberDeep : accent.deep)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        Capsule().fill(Palette.card)
                            .overlay(Capsule().stroke(Palette.stroke, lineWidth: 2))
                    )
                    .offset(y: pulse ? -3 : 2)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            }

            Button(action: action) {
                ZStack {
                    // session ring: one notch per required pass
                    if required > 1 && isUnlocked {
                        Circle()
                            .stroke(Palette.locked, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 84, height: 84)
                        Circle()
                            .trim(from: 0, to: ratio)
                            .stroke(done ? Palette.amber : accent.main,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 84, height: 84)
                            .animation(.spring(response: 0.5), value: ratio)
                    }

                    Circle().fill(edge).frame(width: 70, height: 70).offset(y: 6)
                    Circle().fill(fill).frame(width: 70, height: 70)
                        .overlay(
                            Circle().fill(.white.opacity(0.18))
                                .frame(width: 44, height: 20).offset(y: -14).blur(radius: 3)
                        )

                    Image(systemName: symbol)
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(isUnlocked ? .white : Palette.inkFaint)
                }
                .scaleEffect(isCurrent ? 1.05 : 1)
                .animation(.spring(response: 0.4), value: isCurrent)
            }
            .buttonStyle(NodePressStyle())

            if isUnlocked && required > 1 && sessionsDone > 0 && !done {
                Text("\(sessionsDone)/\(required)")
                    .font(.heading(11)).foregroundStyle(Palette.inkFaint)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var symbol: String {
        if !isUnlocked { return "lock.fill" }
        if done { return node.kind == .review ? "crown.fill" : "checkmark" }
        if sessionsDone > 0 { return node.focus(forSession: sessionsDone).icon }
        return node.icon
    }

    private var callToAction: String {
        if done { return S.repeatLesson[state.native].uppercased() }
        if sessionsDone > 0 { return S.continueLesson[state.native].uppercased() }
        return S.startLesson[state.native].uppercased()
    }
}

private struct NodePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Node detail sheet

struct NodeSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let node: PathNode
    let level: CEFR
    let start: (SessionRequest) -> Void
    let startTest: (TestTarget) -> Void
    let startWriting: (PathNode) -> Void

    private var unit: Unit? { state.curriculum.unit(id: node.unitID) }
    private var unlocked: Bool { state.isUnlocked(node) }
    private var done: Int { state.sessionsDone(node.id) }
    private var required: Int { node.requiredSessions }
    private var focus: SessionFocus { node.focus(forSession: min(done, required - 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if case .writing(let chapter) = node.kind, unlocked {
                writingBrief(chapter)
            }

            if required > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: S.sessionPlan[state.native].uppercased())
                    HStack(spacing: 8) {
                        ForEach(Array(node.sessionPlan.enumerated()), id: \.offset) { i, f in
                            sessionChip(index: i, focus: f)
                        }
                    }
                }
            }

            if case .lesson(let lesson) = node.kind, unlocked {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: S.keyWords[state.native].uppercased())
                    FlowChips(items: Array(lesson.vocab.prefix(6)).map { $0[state.target] },
                              language: state.target)
                }
            }

            if !unlocked {
                Text(S.lockedMsg[state.native])
                    .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if unlocked, node.isWriting {
                Button {
                    Feedback.pop(); startWriting(node)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .black))
                        Text(S.writingStart[state.native])
                    }
                }
                .buttonStyle(.chunky(Palette.purple, Palette.purpleDeep))
            } else if unlocked {
                Button {
                    guard let unit else { return }
                    Feedback.pop()
                    start(SessionRequest(node: node, unit: unit, level: level, mode: .lesson,
                                         consumesHearts: !state.unlimited,
                                         focus: focus,
                                         sessionNumber: min(done + 1, required),
                                         sessionsTotal: required))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: focus.icon).font(.system(size: 15, weight: .black))
                        Text(done >= required ? S.repeatLesson[state.native]
                                              : "\(S.startLesson[state.native]) · \(focus.label[state.native])")
                    }
                }
                .buttonStyle(.chunky(focus.tint.main, focus.tint.deep))
            } else if let target = PlacementTest.target(skippingTo: node, state: state) {
                Button {
                    Feedback.pop(); startTest(target)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 15, weight: .black))
                        Text(S.testUnlockNode[state.native])
                    }
                }
                .buttonStyle(.chunky(Palette.purple, Palette.purpleDeep))
            }
        }
        .padding(Metrics.hPad)
        .padding(.top, 8)
        .background(Palette.bgElevated)
        .onAppear {
            // She is reading the chapter's key words; that is time enough for the
            // assistant to have written a few new sentences before she taps Start.
            guard unlocked, done > 0, let unit,
                  let brief = state.phraseBrief(for: node, unit: unit, level: level) else { return }
            PhraseForge.shared.warm(brief)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: node.icon)
                .font(.system(size: 20, weight: .black)).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(unit?.accent.main ?? Palette.brand))
            VStack(alignment: .leading, spacing: 3) {
                Text(node.title[state.native]).font(.heading(19)).foregroundStyle(Palette.ink)
                HStack(spacing: 8) {
                    Tag(text: "\(node.xpReward) XP", tint: Palette.amberDeep)
                    if required > 1 {
                        Tag(text: done >= required ? S.sessionDone[state.native]
                                                   : "\(S.sessionOf[state.native]) \(min(done + 1, required))/\(required)",
                            tint: Palette.brand)
                    }
                }
            }
            Spacer()
        }
    }

    /// What this chapter is, in the two lines it takes to say it: who she is writing
    /// to, about what, and how much of it is being asked for.
    private func writingBrief(_ chapter: WritingChapter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(S.writingSub[state.native])
                .font(.plain(13.5)).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Image(systemName: chapter.theme.icon)
                    .font(.system(size: 17, weight: .black)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.purple))
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.theme.title[state.native])
                        .font(.heading(15)).foregroundStyle(Palette.ink)
                    Text("\(chapter.turns) × \(chapter.minimumWords)+ \(S.wordsShort[state.native])")
                        .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(Palette.purple.opacity(0.12)))
        }
    }

    private func sessionChip(index: Int, focus f: SessionFocus) -> some View {
        let completed = index < done
        let current = index == done
        return VStack(spacing: 4) {
            Image(systemName: completed ? "checkmark" : f.icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(completed ? .white : (current ? .white : f.tint.main))
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(completed ? Palette.green
                                            : (current ? f.tint.main : f.tint.main.opacity(0.14)))
                )
            Text(f.label[state.native])
                .font(.plain(9.5))
                .foregroundStyle(current ? f.tint.deep : Palette.inkFaint)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Simple wrapping chip row.
struct FlowChips: View {
    let items: [String]
    var tint: Color = Palette.brand
    /// Set when the chips hold words in the language being learnt: a tap then reads
    /// the word out loud.
    var language: Language?

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.plain(13))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(tint.opacity(0.12)))
                    .lineLimit(1)
                    .speakOnTap(item, language: language)
            }
        }
    }
}
