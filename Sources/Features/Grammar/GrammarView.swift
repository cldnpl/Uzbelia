import SwiftUI

struct GrammarView: View {
    @Environment(AppState.self) private var state
    @State private var query = ""
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            StatsHeader()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 10) {
                        Mascot(mood: .think, size: 56)
                        SpeechBubble {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(S.grammarTitle[state.native]).font(.heading(18)).foregroundStyle(Palette.ink)
                                Text(S.grammarSub[state.native]).font(.plain(13)).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 6)

                    searchField

                    ForEach(state.curriculum.levels) { pack in
                        let units = filteredUnits(pack.units)
                        if !units.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Text(pack.level.label)
                                        .font(.display(16)).foregroundStyle(.white)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Capsule().fill(Palette.brand))
                                    Text(pack.level.blurb[state.native])
                                        .font(.heading(13)).foregroundStyle(Palette.inkSoft)
                                }
                                ForEach(units) { unit in
                                    unitBlock(unit)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Metrics.hPad)
                .padding(.bottom, 26)
            }
        }
        .background(Palette.bg)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkFaint)
            TextField(state.native == .it ? "Cerca una regola…" : "Qoidani qidiring…", text: $query)
                .font(.plain(15))
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint)
                }.buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 13).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.stroke, lineWidth: 2))
    }

    private func filteredUnits(_ units: [Unit]) -> [Unit] {
        guard !query.isEmpty else { return units.filter { !$0.grammar.isEmpty } }
        let q = Grader.normalise(query)
        return units.filter { unit in
            unit.grammar.contains {
                Grader.normalise($0.title[state.native]).contains(q) ||
                Grader.normalise($0.body[state.native]).contains(q)
            } || Grader.normalise(unit.title[state.native]).contains(q)
        }
    }

    private func unitBlock(_ unit: Unit) -> some View {
        let open = expanded.contains(unit.id) || !query.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                Feedback.tap()
                withAnimation(.easeInOut(duration: 0.22)) {
                    if expanded.contains(unit.id) { expanded.remove(unit.id) } else { expanded.insert(unit.id) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: unit.icon)
                        .font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(unit.accent.main))
                    Text(unit.title[state.native]).font(.heading(15.5)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Text("\(unit.grammar.count)").font(.plain(13)).foregroundStyle(Palette.inkFaint)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .black)).foregroundStyle(Palette.inkFaint)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                    .stroke(Palette.stroke, lineWidth: 2))
            }
            .buttonStyle(.plain)

            if open {
                ForEach(unit.grammar) { note in
                    GrammarNoteCard(note: note)
                        .padding(.leading, 8)
                }
            }
        }
    }
}
