import SwiftUI

/// The unit "guidebook": grammar notes plus every word and phrase it teaches.
struct GuidebookView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let unit: Unit
    @State private var session: SessionRequest?

    private var level: CEFR { state.curriculum.level(of: unit.id) ?? .a1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                practiceButton

                ForEach(unit.grammar) { note in
                    GrammarNoteCard(note: note)
                }

                ForEach(unit.lessons) { lesson in
                    VStack(alignment: .leading, spacing: 9) {
                        SectionHeader(title: lesson.title[state.native].uppercased())
                        VStack(spacing: 0) {
                            ForEach(lesson.allPairs) { pair in
                                PairRow(pair: pair)
                                if pair.id != lesson.allPairs.last?.id {
                                    Divider().overlay(Palette.stroke).padding(.horizontal, 14)
                                }
                            }
                        }
                        .glass(radius: 24)
                    }
                }
            }
            .padding(Metrics.hPad)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(AuroraBackground(mood: .grammar))
        .fullScreenCover(item: $session) { LessonView(request: $0) }
    }

    @ViewBuilder
    private var practiceButton: some View {
        if state.hasStartedUnit(unit, level: level) {
            VStack(spacing: 7) {
                Button {
                    Feedback.pop()
                    session = state.unitPracticeRequest(for: unit, level: level)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .bold))
                        Text(S.reviewThisUnit[state.native])
                    }
                }
                .buttonStyle(.primary(Tone(unit.accent)))
                Text(S.againAsYouLike[state.native])
                    .font(.plain(12)).foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            OrbIcon(unit.icon, accent: unit.accent, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(S.unitGuide[state.native]).font(.heading(13)).foregroundStyle(Palette.inkSoft)
                Text(unit.title[state.native]).font(.display(24)).foregroundStyle(Gradients.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(unit.allPairs.count) \(S.words[state.native]) · \(unit.lessons.count) \(S.lessons[state.native])")
                    .font(.plain(13)).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
            GlassCircleButton(icon: "xmark", size: 42, tint: Palette.inkSoft) {
                Feedback.tap(); dismiss()
            }
        }
        .padding(.top, 8)
    }
}

struct GrammarNoteCard: View {
    @Environment(AppState.self) private var state
    let note: GrammarNote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                OrbIcon("lightbulb.fill", accent: .amber, size: 34, symbolScale: 0.42)
                Text(note.title[state.native]).font(.heading(17)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(note.body[state.native])
                .font(.plain(15)).foregroundStyle(Palette.inkSoft)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if !note.examples.isEmpty {
                VStack(spacing: 0) {
                    ForEach(note.examples) { ex in
                        PairRow(pair: ex, compact: true)
                        if ex.id != note.examples.last?.id {
                            Divider().overlay(Palette.stroke).padding(.horizontal, 12)
                        }
                    }
                }
                .glass(radius: 18, tint: Palette.amber, material: false, shadow: false)
            }
        }
        .padding(16)
        .glass(radius: 26)
    }
}

struct PairRow: View {
    @Environment(AppState.self) private var state
    let pair: Pair
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                SpeakableText(text: pair[state.target], language: state.target,
                              font: .body(compact ? 15 : 16.5))
                Text(pair[state.native])
                    .font(.plain(compact ? 13 : 14)).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let hint = pair.hint {
                    Text(hint).font(.plain(12)).foregroundStyle(Palette.inkFaint)
                }
            }
            Spacer(minLength: 6)
            StrengthDots(value: state.strength(of: pair))
            GlassCircleButton(icon: "speaker.wave.2.fill", size: 34, tint: Palette.brand,
                              accessibility: S.listenAgain[state.native]) {
                Feedback.tap()
                SpeechService.shared.speak(pair[state.target], language: state.target, rate: state.settings.speechRate)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, compact ? 9 : 11)
    }
}

struct StrengthDots: View {
    var value: Double
    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(Double(i) / 4 < value
                          ? AnyShapeStyle(LinearGradient(colors: [Palette.teal, Palette.green],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Palette.locked))
                    .frame(width: 4, height: 12)
            }
        }
    }
}
