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
}

struct PracticeHubView: View {
    @Environment(AppState.self) private var state
    @State private var session: SessionRequest?
    @State private var showWordList = false
    @State private var showUnitPicker = false

    var body: some View {
        VStack(spacing: 0) {
            StatsHeader()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 10) {
                        Mascot(mood: .happy, size: 58)
                        SpeechBubble {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(S.practiceTitle[state.native]).font(.heading(18)).foregroundStyle(Palette.ink)
                                Text(S.practiceSub[state.native]).font(.plain(13)).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 6)

                    bigCard(title: S.mixedReview[state.native],
                            subtitle: S.mixedReviewSub[state.native],
                            icon: "arrow.triangle.2.circlepath",
                            tint: .sky,
                            badge: "\(max(state.duePairs().count, min(12, state.learnedPairs.count)))") {
                        startMixed()
                    }

                    bigCard(title: S.mistakesDrill[state.native],
                            subtitle: state.mistakesBank.isEmpty ? S.noMistakes[state.native] : S.mistakesSub[state.native],
                            icon: "bandage.fill",
                            tint: .red,
                            badge: state.mistakesBank.isEmpty ? nil : "\(state.mistakesBank.count)",
                            enabled: !state.mistakesBank.isEmpty) {
                        startMistakes()
                    }

                    bigCard(title: S.unitPractice[state.native],
                            subtitle: state.startedUnits.isEmpty ? S.noUnitsYet[state.native]
                                                                 : S.unitPracticeSub[state.native],
                            icon: "books.vertical.fill",
                            tint: .teal,
                            badge: state.startedUnits.isEmpty ? nil : "\(state.startedUnits.count)",
                            enabled: !state.startedUnits.isEmpty) {
                        showUnitPicker = true
                    }

                    SectionHeader(title: S.skillDrill[state.native].uppercased())
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Skill.allCases, id: \.self) { skill in
                            skillCard(skill)
                        }
                    }

                    Button {
                        Feedback.tap(); showWordList = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .font(.system(size: 18, weight: .black)).foregroundStyle(Palette.purple)
                            Text(S.wordList[state.native]).font(.heading(16)).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("\(state.wordsSeen)").font(.heading(15)).foregroundStyle(Palette.inkSoft)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .black))
                                .foregroundStyle(Palette.inkFaint)
                        }
                        .padding(15)
                        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    if !state.practiceReady {
                        Text(S.notEnoughYet[state.native])
                            .font(.plain(13)).foregroundStyle(Palette.inkFaint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, Metrics.hPad)
                .padding(.bottom, 26)
            }
        }
        .background(Palette.bg)
        .fullScreenCover(item: $session) { LessonView(request: $0) }
        .sheet(isPresented: $showWordList) { WordListView() }
        .sheet(isPresented: $showUnitPicker) {
            UnitPickerView { request in
                showUnitPicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { session = request }
            }
        }
    }

    // MARK: - Cards

    private func bigCard(title: String, subtitle: String, icon: String, tint: UnitAccent,
                         badge: String? = nil, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { Feedback.pop(); action() } }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .black)).foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.22)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.heading(17)).foregroundStyle(.white)
                    Text(subtitle).font(.plain(12.5)).foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                if let badge {
                    Text(badge).font(.heading(14)).foregroundStyle(tint.deep)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(.white))
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(LinearGradient(colors: [tint.main, tint.deep], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(tint.deep).offset(y: Metrics.chunkDepth))
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func skillCard(_ skill: Skill) -> some View {
        Button {
            Feedback.pop(); startSkill(skill)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: skill.icon)
                    .font(.system(size: 20, weight: .black)).foregroundStyle(skill.tint.main)
                Text(skill.label[state.native]).font(.heading(15)).foregroundStyle(Palette.ink)
                Text(skillHint(skill)).font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .stroke(skill.tint.main.opacity(0.35), lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .fill(Palette.stroke).offset(y: 4))
        }
        .buttonStyle(.plain)
    }

    private func skillHint(_ skill: Skill) -> String {
        switch (skill, state.native) {
        case (.reading, .it): return "Scegli la traduzione giusta"
        case (.reading, .uz): return "To'g'ri tarjimani tanlang"
        case (.writing, .it): return "Scrivi tu la frase"
        case (.writing, .uz): return "Jumlani o'zingiz yozing"
        case (.listening, .it): return "Solo ascolto e dettato"
        case (.listening, .uz): return "Faqat tinglash va diktant"
        case (.speaking, .it): return "Pronuncia al microfono"
        case (.speaking, .uz): return "Mikrofonga gapiring"
        }
    }

    // MARK: - Session builders

    private func startMixed() {
        var pairs = state.duePairs(limit: 16)
        if pairs.count < 8 {
            pairs += state.learnedPairs.shuffled().prefix(16 - pairs.count)
        }
        launch(pairs: pairs, title: S.mixedReview, xp: 20)
    }

    private func startMistakes() {
        launch(pairs: Array(state.mistakesBank.shuffled().prefix(14)), title: S.mistakesDrill, xp: 25)
    }

    private func startSkill(_ skill: Skill) {
        let pairs = Array(state.learnedPairs.shuffled().prefix(14))
        let ex = ExerciseFactory.practice(pairs: pairs, pool: state.curriculum.allPairs,
                                          native: state.native, settings: state.effectiveSettings,
                                          count: 12, productionBias: 0.5, restrictTo: skill)
        session = SessionRequest(mode: .practice, customExercises: ex,
                                 customTitle: skill.label, consumesHearts: false, xpReward: 20)
    }

    private func launch(pairs: [Pair], title: Bilingual, xp: Int) {
        guard !pairs.isEmpty else { return }
        let ex = ExerciseFactory.practice(pairs: pairs, pool: state.curriculum.allPairs,
                                          native: state.native, settings: state.effectiveSettings,
                                          count: 15, productionBias: 0.55)
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
            Grader.normalise($0.it).contains(Grader.normalise(query)) ||
            Grader.normalise($0.uz).contains(Grader.normalise(query))
        }
        return filtered.sorted { state.strength(of: $0) < state.strength(of: $1) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(pairs) { pair in
                    PairRow(pair: pair)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Palette.bg)
                }
            }
            .listStyle(.plain)
            .background(Palette.bg)
            .searchable(text: $query)
            .navigationTitle(S.wordList[state.native])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(S.close[state.native]) { dismiss() }.font(.heading(15))
                }
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(S.unitPracticeSub[state.native])
                        .font(.plain(13)).foregroundStyle(Palette.inkSoft)

                    ForEach(state.startedUnits, id: \.unit.id) { entry in
                        Button {
                            Feedback.pop()
                            start(state.unitPracticeRequest(for: entry.unit, level: entry.level))
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: entry.unit.icon)
                                    .font(.system(size: 17, weight: .black)).foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(Circle().fill(entry.unit.accent.main))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Tag(text: entry.level.label, tint: entry.unit.accent.deep)
                                        Text(entry.unit.title[state.native])
                                            .font(.heading(15.5)).foregroundStyle(Palette.ink)
                                            .lineLimit(1)
                                    }
                                    Text("\(entry.unit.allPairs.count) \(S.unitWords[state.native])")
                                        .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                                    ProgressBar(value: state.completion(ofUnit: entry.unit, level: entry.level),
                                                tint: entry.unit.accent.main, height: 7)
                                        .frame(height: 7)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .black)).foregroundStyle(Palette.inkFaint)
                            }
                            .padding(13)
                            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                                .fill(Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                                .stroke(Palette.stroke, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Metrics.hPad)
            }
            .background(Palette.bg)
            .navigationTitle(S.unitPractice[state.native])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(S.close[state.native]) { dismiss() }.font(.heading(15))
                }
            }
        }
    }
}
