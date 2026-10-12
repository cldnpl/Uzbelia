import SwiftUI

extension AppState {
    /// Everything the learner has actually been taught so far.
    var learnedPairs: [Pair] {
        var out: [Pair] = []
        for pack in curriculum.levels {
            for unit in pack.units {
                for lesson in unit.lessons where hasStarted(lesson.id) {
                    out.append(contentsOf: lesson.allPairs)
                }
            }
        }
        if out.isEmpty {
            out = curriculum.levels.first?.units.first?.lessons.first?.allPairs ?? []
        }
        return out
    }

    var practiceReady: Bool {
        curriculum.allLessons.contains { hasStarted($0.id) }
    }

    /// The level she is working at: the highest open one she has started.
    var studyLevel: CEFR {
        CEFR.allCases.last { isLevelUnlocked($0) && completion(of: $0) > 0 }
            ?? CEFR.allCases.first { isLevelUnlocked($0) } ?? .a1
    }
}

struct PracticeHubView: View {
    @Environment(AppState.self) private var state
    @State private var session: SessionRequest?
    @State private var showWordList = false
    @State private var showUnitPicker = false
    @State private var showFlashcards = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatsHeader()
                TabHeader(eyebrow: S.practiceEyebrow[state.native],
                          title: S.practiceHeadline[state.native],
                          subtitle: S.practiceSub[state.native])

                mixedCard

                flashcardCard

                HStack(spacing: 12) {
                    tile(title: S.mistakesDrill[state.native],
                         subtitle: state.mistakesBank.isEmpty ? S.noMistakes[state.native] : S.mistakesSub[state.native],
                         icon: "bandage.fill", accent: .purple,
                         badge: state.mistakesBank.isEmpty ? nil : "\(state.mistakesBank.count)",
                         enabled: !state.mistakesBank.isEmpty) {
                        startMistakes()
                    }
                    tile(title: S.unitPractice[state.native],
                         subtitle: state.startedUnits.isEmpty ? S.noUnitsYet[state.native] : S.unitPracticeSub[state.native],
                         icon: "books.vertical.fill", accent: .teal,
                         badge: state.startedUnits.isEmpty ? nil : "\(state.startedUnits.count)",
                         enabled: !state.startedUnits.isEmpty) {
                        showUnitPicker = true
                    }
                }

                SectionHeader(title: S.skillDrill[state.native].uppercased())
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(Skill.allCases, id: \.self) { skill in
                        skillCard(skill)
                    }
                }

                Button {
                    Feedback.tap(); showWordList = true
                } label: {
                    HStack(spacing: 14) {
                        OrbIcon("list.bullet.rectangle.portrait.fill", accent: .purple, size: 44, symbolScale: 0.4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(S.wordList[state.native]).font(.heading(16.5)).foregroundStyle(Palette.ink)
                            Text("\(state.wordsLearned) / \(state.wordsSeen) · \(S.strength[state.native])")
                                .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .padding(14)
                    .glass(radius: 24)
                }
                .buttonStyle(.pressable)

                if !state.practiceReady {
                    Text(S.notEnoughYet[state.native])
                        .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.top, 6)
            .padding(.bottom, Metrics.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .background(AuroraBackground(mood: .practice))
        .fullScreenCover(item: $session) { LessonView(request: $0) }
        .fullScreenCover(isPresented: $showFlashcards) { FlashcardsView() }
        .sheet(isPresented: $showWordList) { WordListView().auroraSheet() }
        .sheet(isPresented: $showUnitPicker) {
            UnitPickerView { request in
                showUnitPicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { session = request }
            }
            .auroraSheet()
        }
    }

    // MARK: - Cards

    private var mixedCard: some View {
        let count = max(state.duePairs().count, min(12, state.learnedPairs.count))
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().strokeBorder(UnitAccent.sky.main.opacity(0.25), lineWidth: 1)
                        .frame(width: 82, height: 82)
                    OrbIcon("arrow.triangle.2.circlepath", accent: .sky, size: 64, symbolScale: 0.38)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(S.mixedReview[state.native])
                        .font(.display(22)).foregroundStyle(Palette.ink)
                    Text(S.mixedReviewSub[state.native])
                        .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    GlassChip(text: "\(count) \(S.words[state.native])", icon: "sparkles", tint: UnitAccent.sky.deep)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            Button { Feedback.pop(); startMixed() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 14, weight: .bold))
                    Text(S.startLesson[state.native])
                }
            }
            .buttonStyle(.primary(.sky, height: 52))
        }
        .padding(18)
        .glass(radius: 30, tint: Palette.sky)
    }

    /// Flashcards: a fan of three cards, the top one showing a word she knows.
    private var flashcardCard: some View {
        let words = state.flashcardWords
        let sample = words.last
        return Button {
            guard !words.isEmpty else { return }
            Feedback.pop(); showFlashcards = true
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(S.flashTitle[state.native])
                        .font(.display(19)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(words.isEmpty ? S.notEnoughYet[state.native] : S.flashSub[state.native])
                        .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !words.isEmpty {
                        GlassChip(text: "\(words.count) \(S.flashCards[state.native])",
                                  icon: "rectangle.stack.fill", tint: Palette.brandDeep)
                            .padding(.top, 4)
                    }
                }
                Spacer(minLength: 0)
                fan(word: sample?[state.target])
                    .frame(width: 104, height: 112)
            }
            .padding(18)
            .glass(radius: 30, tint: Palette.purple)
            .opacity(words.isEmpty ? 0.6 : 1)
        }
        .buttonStyle(.pressable)
        .disabled(words.isEmpty)
    }

    private func fan(word: String?) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let angle = Double(i - 1) * 9
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(i == 1 ? AnyShapeStyle(Color.white.opacity(0.92))
                                 : AnyShapeStyle(LinearGradient(colors: [Violet.v200, Violet.v300],
                                                                startPoint: .top, endPoint: .bottom)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white, lineWidth: 1.2))
                    .frame(width: 64, height: 86)
                    .shadow(color: Palette.glassShadow, radius: 6, y: 4)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .offset(x: CGFloat(i - 1) * 14)
                    .zIndex(i == 1 ? 3 : Double(i))
            }
            if let word {
                Text(word)
                    .font(.heading(13)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.6)
                    .frame(width: 54)
                    .zIndex(4)
            }
        }
    }

    private func tile(title: String, subtitle: String, icon: String, accent: UnitAccent,
                      badge: String?, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { Feedback.pop(); action() } }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    OrbIcon(icon, accent: accent, size: 50, symbolScale: 0.4)
                    Spacer(minLength: 0)
                    if let badge {
                        Text(badge).font(.heading(13)).foregroundStyle(accent.deep)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .glassCapsule(tint: accent.main, material: false, shadow: false)
                    }
                }
                Text(title).font(.heading(16)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
            .glass(radius: 26, tint: accent.main)
            .opacity(enabled ? 1 : 0.55)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
    }

    private func skillCard(_ skill: Skill) -> some View {
        // a drill for a skill she has just put aside would walk straight past the hold
        let held = state.isSnoozed(skill)
        return Button {
            Feedback.pop(); startSkill(skill)
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(LinearGradient(colors: [skill.tint.light, skill.tint.main.opacity(0.2)],
                                                     startPoint: .top, endPoint: .bottom),
                                      lineWidth: 3)
                        .frame(width: 92, height: 92)
                    OrbIcon(held ? "clock.badge.xmark" : skill.icon,
                            look: held ? .muted : .accent(skill.tint), size: 70, symbolScale: 0.38)
                }
                .padding(.top, 4)
                VStack(spacing: 3) {
                    Text(skill.label[state.native]).font(.heading(16.5)).foregroundStyle(Palette.ink)
                    Text(held ? "\(S.onHoldFor[state.native]) \(state.snoozeMinutesLeft(skill)) \(S.minutesShort[state.native])"
                              : skillHint(skill))
                        .font(.plain(12))
                        .foregroundStyle(held ? Palette.amberDeep : Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .glass(radius: 28)
            .opacity(held ? 0.6 : 1)
        }
        .buttonStyle(.pressable)
        .disabled(held)
    }

    private func skillHint(_ skill: Skill) -> String {
        switch skill {
        case .reading: return "Read and recognize"
        case .writing: return "Sentences and a short text"
        case .listening: return "Audio and dictation only"
        case .speaking: return "Read and repeat aloud"
        }
    }

    // MARK: - Session builders

    private func startMixed() {
        var pairs = state.duePairs(limit: 14)
        if pairs.count < 8 {
            pairs += state.learnedPairs.shuffled().prefix(14 - pairs.count)
        }
        launch(pairs: pairs, title: S.mixedReview, xp: 20)
    }

    private func startMistakes() {
        launch(pairs: Array(state.mistakesBank.shuffled().prefix(12)), title: S.mistakesDrill, xp: 25)
    }

    private func startSkill(_ skill: Skill) {
        guard !state.isSnoozed(skill) else { return }
        let pairs = Array(state.learnedPairs.shuffled().prefix(14))
        let ex = ExerciseFactory.practice(pairs: pairs, pool: state.curriculum.allPairs,
                                          native: state.native, settings: state.effectiveSettings,
                                          count: 10, productionBias: 0.5, restrictTo: skill,
                                          level: state.studyLevel)
        session = SessionRequest(mode: .practice, customExercises: ex,
                                 customTitle: skill.label, consumesHearts: false, xpReward: 20,
                                 accent: skill.tint)
    }

    private func launch(pairs: [Pair], title: Bilingual, xp: Int) {
        guard !pairs.isEmpty else { return }
        let ex = ExerciseFactory.practice(pairs: pairs, pool: state.curriculum.allPairs,
                                          native: state.native, settings: state.effectiveSettings,
                                          count: 12, productionBias: 0.55)
        session = SessionRequest(mode: .practice, customExercises: ex,
                                 customTitle: title, consumesHearts: false, xpReward: xp)
    }
}

// MARK: - Word list

struct WordListView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var pairs: [Pair] {
        let seen = state.learnedPairs.reduce(into: [String: Pair]()) { $0[$1.id] = $1 }
        let list = Array(seen.values)
        let filtered = query.isEmpty ? list : list.filter {
            Grader.normalise($0.en).contains(Grader.normalise(query)) ||
            Grader.normalise($0.tx).contains(Grader.normalise(query))
        }
        return filtered.sorted { state.strength(of: $0) < state.strength(of: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: S.wordList[state.native]) { dismiss() }
            GlassSearchField(text: $query, placeholder: S.searchWord[state.native])
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(pairs) { pair in
                        PairRow(pair: pair)
                        if pair.id != pairs.last?.id {
                            Divider().overlay(Palette.stroke).padding(.horizontal, 14)
                        }
                    }
                }
                .glass(radius: 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 18)
    }
}

/// The top of a sheet: its title, and a round glass button to close it.
struct SheetHeader: View {
    var title: String
    var subtitle: String? = nil
    let close: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.display(24)).foregroundStyle(Gradients.title)
                if let subtitle {
                    Text(subtitle).font(.plain(13.5)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            GlassCircleButton(icon: "xmark", size: 42, tint: Palette.inkSoft) {
                Feedback.tap(); close()
            }
        }
    }
}

// MARK: - Choose a chapter to repeat

struct UnitPickerView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let start: (SessionRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: S.unitPractice[state.native],
                        subtitle: S.unitPracticeSub[state.native]) { dismiss() }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(state.startedUnits, id: \.unit.id) { entry in
                        Button {
                            Feedback.pop()
                            start(state.unitPracticeRequest(for: entry.unit, level: entry.level))
                        } label: {
                            HStack(spacing: 13) {
                                OrbIcon(entry.unit.icon, accent: entry.unit.accent, size: 46, symbolScale: 0.4)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 6) {
                                        Tag(text: entry.level.label, tint: entry.unit.accent.deep)
                                        Text(entry.unit.title[state.native])
                                            .font(.heading(15.5)).foregroundStyle(Palette.ink)
                                            .lineLimit(1)
                                    }
                                    Text("\(entry.unit.allPairs.count) \(S.unitWords[state.native])")
                                        .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                                    ProgressBar(value: state.completion(ofUnit: entry.unit, level: entry.level),
                                                tint: entry.unit.accent.main, height: 6, showsShine: false)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkFaint)
                            }
                            .padding(14)
                            .glass(radius: 24, tint: entry.unit.accent.main)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 18)
    }
}
