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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) {
                        StatsHeader()
                        TabHeader(eyebrow: S.homeHello[state.native], title: S.homeTitle(state.target)[state.native])
                        levelPicker
                        resumeCard(proxy)
                    }
                    .padding(.bottom, 26)
                    .id("top")

                    LazyVStack(spacing: 0) {
                        ForEach(units) { unit in
                            unitSection(unit).id(unit.id)
                        }
                        levelFooter
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, Metrics.hPad)
                .padding(.top, 6)
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .onChange(of: level) { _, _ in
                withAnimation(.easeInOut) { proxy.scrollTo("top", anchor: .top) }
            }
        }
        .background(AuroraBackground(mood: .home))
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
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.visible)
            .auroraSheet()
        }
        .sheet(item: $guidebookUnit) { unit in GuidebookView(unit: unit) }
        .sheet(item: $testTarget) { target in
            TestIntroSheet(target: target) { req in
                testTarget = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSession = req }
            }
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .auroraSheet()
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
        withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(unitID, anchor: .top) }
    }

    /// What tapping "Continue" on a node starts.
    private func launch(_ node: PathNode) {
        guard let unit = state.curriculum.unit(id: node.unitID) else { return }
        if node.isWriting { writingNode = node; return }
        let done = state.sessionsDone(node.id)
        let required = node.requiredSessions
        activeSession = SessionRequest(node: node, unit: unit, level: level, mode: .lesson,
                                       consumesHearts: !state.unlimited,
                                       focus: state.focus(for: node, session: min(done, required - 1)),
                                       sessionNumber: min(done + 1, required),
                                       sessionsTotal: required)
    }

    // MARK: - Level picker

    private var levelPicker: some View {
        HStack(spacing: 8) {
            ForEach(CEFR.allCases) { lvl in
                let unlocked = state.isLevelUnlocked(lvl)
                let on = level == lvl
                Button {
                    Feedback.tap()
                    if unlocked {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { level = lvl }
                    } else {
                        testTarget = PlacementTest.target(unlocking: lvl, state: state)
                    }
                } label: {
                    VStack(spacing: 1) {
                        HStack(spacing: 4) {
                            if !unlocked {
                                Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                            }
                            Text(lvl.label).font(.heading(15))
                        }
                        Text(unlocked ? "\(Int(state.completion(of: lvl) * 100))%" : "test")
                            .font(.plain(10.5))
                            .opacity(0.8)
                    }
                    .foregroundStyle(on ? .white : (unlocked ? Palette.ink : Palette.inkFaint))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if on {
                            Capsule().fill(Gradients.primary)
                                .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                                       startPoint: .top, endPoint: .center)))
                                .shadow(color: Palette.brand.opacity(0.35), radius: 10, y: 5)
                        } else {
                            GlassPane(shape: Capsule(), tint: nil, material: false, shadow: false)
                        }
                    }
                }
                .buttonStyle(.pressable)
            }
        }
    }

    // MARK: - Resume card

    @ViewBuilder
    private func resumeCard(_ proxy: ScrollViewProxy) -> some View {
        if let id = state.currentNodeID(in: level),
           let node = state.nodes(for: level).first(where: { $0.id == id }),
           let unit = state.curriculum.unit(id: node.unitID) {
            let done = state.sessionsDone(node.id)
            let required = node.requiredSessions
            let finished = done >= required
            let focus = state.focus(for: node, session: min(done, required - 1))
            let accent = node.isWriting ? UnitAccent.writing : (required > 1 ? focus.tint : unit.accent)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        ArcRing(progress: Double(done) / Double(max(1, required)), accent: accent, lineWidth: 5)
                            .frame(width: 84, height: 84)
                        OrbIcon(required > 1 && !finished ? focus.icon : node.icon, accent: accent, size: 64)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(finished ? S.homeAllDone[state.native] : S.homeResume[state.native])
                            .font(.heading(12)).kerning(0.8).textCase(.uppercase)
                            .foregroundStyle(accent.deep)
                        Text(node.title[state.native])
                            .font(.display(21)).foregroundStyle(Palette.ink)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Text(unit.title[state.native])
                            .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                if required > 1 {
                    HStack(spacing: 6) {
                        ForEach(Array(state.sessionPlan(for: node).enumerated()), id: \.offset) { i, f in
                            Capsule()
                                .fill(i < done ? AnyShapeStyle(Gradients.of(f.tint))
                                               : AnyShapeStyle(i == done ? f.tint.main.opacity(0.35) : Palette.locked))
                                .frame(height: 6)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Feedback.pop(); launch(node)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: node.isWriting ? "paperplane.fill"
                                  : (required > 1 ? focus.icon : "play.fill"))
                                .font(.system(size: 15, weight: .bold))
                            Text(finished ? S.repeatLesson[state.native]
                                 : (required > 1 ? "\(S.continueLesson[state.native]) · \(focus.label[state.native])"
                                                 : S.startLesson[state.native]))
                        }
                    }
                    .buttonStyle(.primary(Tone(accent), height: 52))

                    GlassCircleButton(icon: "scope", size: 52, tint: Palette.inkSoft,
                                      accessibility: S.homeResume[state.native]) {
                        Feedback.tap(); scrollToCurrent(proxy)
                    }
                }
            }
            .padding(18)
            .glass(radius: 30, tint: accent.main)
        }
    }

    // MARK: - Unit section

    @ViewBuilder
    private func unitSection(_ unit: Unit) -> some View {
        let nodes = unit.nodes(level: level, index: 0)
        let currentID = state.currentNodeID(in: level)
        VStack(spacing: 0) {
            unitBanner(unit)
                .padding(.bottom, 22)

            ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                NodeBubble(node: node,
                           accent: unit.accent,
                           isUnlocked: state.isUnlocked(node),
                           isCurrent: currentID == node.id,
                           sessionsDone: state.sessionsDone(node.id),
                           nextFocus: state.nextFocus(for: node)) {
                    Feedback.pop()
                    selectedNode = node
                }
                .offset(x: waveOffset(idx))
                .padding(.vertical, 4)
            }
            .padding(.bottom, 26)
        }
    }

    private func waveOffset(_ i: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, 48, 72, 48, 0, -48, -72, -48]
        return pattern[i % pattern.count]
    }

    private func unitBanner(_ unit: Unit) -> some View {
        let progress = state.completion(ofUnit: unit, level: level)
        return HStack(spacing: 14) {
            ZStack {
                ArcRing(progress: progress, accent: unit.accent, lineWidth: 4)
                    .frame(width: 62, height: 62)
                OrbIcon(unit.icon, accent: unit.accent, size: 48)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(unit.title[state.native])
                    .font(.heading(17.5)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let sub = unit.subtitle {
                    Text(sub[state.native])
                        .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                }
                Text("\(Int(progress * 100))% \(S.completedShort[state.native])")
                    .font(.heading(11.5)).foregroundStyle(unit.accent.deep)
                    .padding(.top, 1)
            }
            Spacer(minLength: 4)
            GlassCircleButton(icon: "book.closed", size: 44, tint: unit.accent.deep,
                              accessibility: S.unitGuide[state.native]) {
                Feedback.tap(); guidebookUnit = unit
            }
        }
        .padding(14)
        .glass(radius: 26, tint: unit.accent.main)
    }

    private var levelFooter: some View {
        VStack(spacing: 12) {
            if state.completion(of: level) >= 1 {
                MascotBubble(mood: .cheer, size: 92)
                Text("Level \(level.label) complete!")
                    .font(.display(20)).foregroundStyle(Gradients.holoLinear)
                if let next = CEFR.allCases.first(where: { $0 > level }) {
                    Button {
                        Feedback.pop(); state.unlock(level: next); withAnimation { level = next }
                    } label: { Text(next.label) }
                    .buttonStyle(.primary(.violet, stretch: false))
                }
            } else {
                MascotBubble(mood: .think, size: 64)
                Text("\(remaining) sessions left in this level")
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
    let nextFocus: SessionFocus
    let action: () -> Void

    @State private var pulse = false

    private var required: Int { node.requiredSessions }
    private var done: Bool { sessionsDone >= required }
    private var ratio: Double { min(1, Double(sessionsDone) / Double(max(1, required))) }

    var body: some View {
        VStack(spacing: 7) {
            if isCurrent && isUnlocked {
                Text(callToAction)
                    .font(.heading(12)).kerning(0.6)
                    .foregroundStyle(Palette.brand)
                    .padding(.horizontal, 14).frame(height: 30)
                    .glassCapsule(tint: Palette.brand)
                    .offset(y: pulse ? -3 : 2)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            }

            Button(action: action) {
                ZStack {
                    if isCurrent && isUnlocked {
                        Circle()
                            .fill(RadialGradient(colors: [tint.main.opacity(0.35), .clear],
                                                 center: .center, startRadius: 30, endRadius: 64))
                            .frame(width: 128, height: 128)
                            .scaleEffect(pulse ? 1.08 : 0.92)
                            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                    }
                    if required > 1 && isUnlocked {
                        SessionRing(passes: state.sessionPlan(for: node).map(\.tint), done: sessionsDone,
                                    lineWidth: 5)
                            .frame(width: 88, height: 88)
                    }
                    orb
                }
                .frame(width: 96, height: 96)
                .scaleEffect(isCurrent ? 1.04 : 1)
            }
            .buttonStyle(PressableStyle(scale: 0.93))

            if isUnlocked && required > 1 && sessionsDone > 0 && !done {
                Text("\(sessionsDone)/\(required)")
                    .font(.heading(11)).foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .glassCapsule(material: false, shadow: false)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var orb: some View {
        if !isUnlocked {
            OrbIcon("lock.fill", look: .muted, size: 70, symbolScale: 0.32)
        } else if done {
            OrbIcon(node.kind == .review ? "crown.fill" : "checkmark", look: .holo, size: 70, symbolScale: 0.36)
        } else {
            OrbIcon(symbol, accent: tint, size: 70, symbolScale: 0.36)
        }
    }

    /// A lesson wears the colour of the pass it is about to run — every listening pass
    /// on the path is the same aqua — and a writing chapter the colour of writing.
    private var tint: UnitAccent {
        if required > 1 { return nextFocus.tint }
        return node.isWriting ? .writing : accent
    }

    private var symbol: String {
        if sessionsDone > 0 && required > 1 { return nextFocus.icon }
        return node.icon
    }

    private var callToAction: String {
        if done { return S.repeatLesson[state.native].uppercased() }
        if sessionsDone > 0 { return S.continueLesson[state.native].uppercased() }
        return S.startLesson[state.native].uppercased()
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
    private var focus: SessionFocus { state.focus(for: node, session: min(done, required - 1)) }
    private var accent: UnitAccent {
        if required > 1 { return focus.tint }
        return node.isWriting ? .writing : (unit?.accent ?? .purple)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if case .writing(let chapter) = node.kind, unlocked {
                writingBrief(chapter)
            }

            if required > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: S.sessionPlan[state.native].uppercased())
                    HStack(spacing: 6) {
                        ForEach(Array(state.sessionPlan(for: node).enumerated()), id: \.offset) { i, f in
                            sessionChip(index: i, focus: f)
                        }
                    }
                    if unlocked && done < required {
                        HStack(spacing: 8) {
                            Image(systemName: focus.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(focus.tint.deep)
                            Text(focus.blurb[state.native])
                                .font(.plain(13.5)).foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glass(radius: 16, tint: focus.tint.main, material: false, shadow: false)
                    }
                }
            }

            if case .lesson(let lesson) = node.kind, unlocked {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: S.keyWords[state.native].uppercased())
                    FlowChips(items: Array(lesson.vocab.prefix(6)).map { $0[state.target] },
                              tint: accent.deep, language: state.target)
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
                        Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .bold))
                        Text(S.writingStart[state.native])
                    }
                }
                .buttonStyle(.primary(.writing))
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
                        Image(systemName: required > 1 ? focus.icon : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text(done >= required ? S.repeatLesson[state.native]
                             : (required > 1 ? "\(S.startLesson[state.native]) · \(focus.label[state.native])"
                                             : S.startLesson[state.native]))
                    }
                }
                .buttonStyle(.primary(required > 1 ? Tone(focus.tint) : .violet))
            } else if let target = PlacementTest.target(skippingTo: node, state: state) {
                Button {
                    Feedback.pop(); startTest(target)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 15, weight: .bold))
                        Text(S.testUnlockNode[state.native])
                    }
                }
                .buttonStyle(.primary(.violet))
            }
        }
        .padding(Metrics.hPad)
        .padding(.top, 14)
        .onAppear {
            // She is reading the chapter's key words; that is time enough for the
            // assistant to have written a few new sentences before she taps Start.
            guard unlocked, done > 0, let unit,
                  let brief = state.phraseBrief(for: node, unit: unit, level: level) else { return }
            PhraseForge.shared.warm(brief)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            OrbIcon(unlocked ? node.icon : "lock.fill",
                    look: unlocked ? .accent(accent) : .muted, size: 58)
            VStack(alignment: .leading, spacing: 6) {
                Text(node.title[state.native])
                    .font(.display(22)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    GlassChip(text: "\(node.xpReward) XP", icon: "bolt.fill", tint: Palette.amberDeep)
                    if required > 1 {
                        GlassChip(text: done >= required ? S.sessionDone[state.native]
                                  : "\(S.sessionOf[state.native]) \(min(done + 1, required))/\(required)",
                                  tint: Palette.brand)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// What this chapter is, in the two lines it takes to say it: who she is writing
    /// to, about what, and how much of it is being asked for.
    private func writingBrief(_ chapter: WritingChapter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(S.writingSub[state.native])
                .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                OrbIcon(chapter.theme.icon, accent: .writing, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.theme.title[state.native])
                        .font(.heading(15.5)).foregroundStyle(Palette.ink)
                    Text("\(chapter.turns) × \(chapter.minimumWords)+ \(S.wordsShort[state.native])")
                        .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .glass(radius: 20, tint: UnitAccent.writing.main, material: false, shadow: false)
        }
    }

    private func sessionChip(index: Int, focus f: SessionFocus) -> some View {
        let completed = index < done
        let current = index == done && unlocked
        return VStack(spacing: 6) {
            ZStack {
                if current {
                    Circle().strokeBorder(f.tint.main.opacity(0.5), lineWidth: 2)
                        .frame(width: 50, height: 50)
                }
                if completed {
                    OrbIcon("checkmark", look: .holo, size: 42, symbolScale: 0.34)
                } else if current {
                    OrbIcon(f.icon, accent: f.tint, size: 42, symbolScale: 0.36)
                } else {
                    Image(systemName: f.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(f.tint.deep)
                        .frame(width: 42, height: 42)
                        .glassCircle(tint: f.tint.main, material: false, shadow: false)
                }
            }
            .frame(width: 52, height: 52)
            Text(f.label[state.native])
                .font(.heading(10.5))
                .foregroundStyle(current ? f.tint.deep : Palette.inkSoft)
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
        FlowLayout(spacing: 7, lineSpacing: 7) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.body(14))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .glassCapsule(tint: tint, material: false, shadow: false)
                    .lineLimit(1)
                    .speakOnTap(item, language: language)
            }
        }
    }
}
