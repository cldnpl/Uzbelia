import SwiftUI

/// The unit "guidebook": grammar notes plus every word and phrase it teaches.
struct GuidebookView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let unit: Unit
    @State private var session: SessionRequest?

    private var level: CEFR { state.curriculum.level(of: unit.id) ?? .a1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    practiceButton

                    ForEach(unit.grammar) { note in
                        GrammarNoteCard(note: note)
                    }

                    ForEach(unit.lessons) { lesson in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: lesson.title[state.native].uppercased())
                            VStack(spacing: 0) {
                                ForEach(lesson.allPairs) { pair in
                                    PairRow(pair: pair)
                                    if pair.id != lesson.allPairs.last?.id {
                                        Divider().overlay(Palette.stroke).padding(.leading, 12)
                                    }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                                .fill(Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                                .stroke(Palette.stroke, lineWidth: 2))
                        }
                    }
                }
                .padding(Metrics.hPad)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .fullScreenCover(item: $session) { LessonView(request: $0) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(S.close[state.native]) { dismiss() }
                        .font(.heading(15))
                }
            }
        }
    }

    @ViewBuilder
    private var practiceButton: some View {
        if state.hasStartedUnit(unit, level: level) {
            VStack(spacing: 6) {
                Button {
                    Feedback.pop()
                    session = state.unitPracticeRequest(for: unit, level: level)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .black))
                        Text(S.reviewThisUnit[state.native])
                    }
                }
                .buttonStyle(.chunky(unit.accent.main, unit.accent.deep))
                Text(S.againAsYouLike[state.native])
                    .font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: unit.icon)
                .font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Circle().fill(unit.accent.main))
            VStack(alignment: .leading, spacing: 3) {
                Text(unit.title[state.native]).font(.heading(20)).foregroundStyle(Palette.ink)
                Text("\(unit.allPairs.count) \(S.words[state.native]) · \(unit.lessons.count) \(S.lessons[state.native])")
                    .font(.plain(13)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
    }
}

struct GrammarNoteCard: View {
    @Environment(AppState.self) private var state
    let note: GrammarNote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(Palette.amber)
                Text(note.title[state.native]).font(.heading(17)).foregroundStyle(Palette.ink)
            }
            Text(note.body[state.native])
                .font(.plain(15)).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if !note.examples.isEmpty {
                VStack(spacing: 0) {
                    ForEach(note.examples) { ex in
                        PairRow(pair: ex, compact: true)
                        if ex.id != note.examples.last?.id {
                            Divider().overlay(Palette.stroke).padding(.leading, 10)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.amber.opacity(0.08)))
            }
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            .stroke(Palette.stroke, lineWidth: 2))
    }
}

struct PairRow: View {
    @Environment(AppState.self) private var state
    let pair: Pair
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pair[state.target])
                    .font(.body(compact ? 15 : 16)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pair[state.native])
                    .font(.plain(compact ? 13 : 14)).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let hint = pair.hint {
                    Text(hint).font(.plain(12)).foregroundStyle(Palette.inkFaint)
                }
            }
            Spacer(minLength: 6)
            StrengthDots(value: state.strength(of: pair))
            Button {
                Feedback.tap()
                SpeechService.shared.speak(pair[state.target], language: state.target, rate: state.settings.speechRate)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.brand)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.brand.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, compact ? 8 : 10)
    }
}

struct StrengthDots: View {
    var value: Double
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(Double(i) / 4 < value ? Palette.green : Palette.locked)
                    .frame(width: 4, height: 11)
            }
        }
    }
}
