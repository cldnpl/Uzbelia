import SwiftUI

struct GrammarView: View {
    @Environment(AppState.self) private var state
    @State private var query = ""
    /// The chapter whose rules are open, in a sheet of their own.
    ///
    /// They used to unfold in place, inside the list: every card slid down from the
    /// row above it on a spring, pushed the rest of the list along, and slid back up
    /// through the header when closed — the bounce and the fading recoil. A sheet
    /// leaves the list exactly where it was.
    @State private var openUnit: Unit?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatsHeader()
                TabHeader(eyebrow: S.grammarEyebrow[state.native],
                          title: S.grammarHeadline[state.native],
                          subtitle: S.grammarSub[state.native])

                GlassSearchField(text: $query, placeholder: S.searchRule[state.native])

                ForEach(state.curriculum.levels) { pack in
                    let units = filteredUnits(pack.units)
                    if !units.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text(pack.level.label)
                                    .font(.display(15)).foregroundStyle(.white)
                                    .padding(.horizontal, 12).frame(height: 30)
                                    .background(Capsule().fill(Gradients.primary))
                                    .shadow(color: Palette.brand.opacity(0.3), radius: 6, y: 3)
                                Text(pack.level.blurb[state.native])
                                    .font(.heading(14)).foregroundStyle(Palette.inkSoft)
                            }
                            ForEach(units) { unit in
                                unitRow(unit)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.top, 6)
            .padding(.bottom, Metrics.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AuroraBackground(mood: .grammar))
        .sheet(item: $openUnit) { unit in
            GrammarUnitSheet(unit: unit, query: query)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .auroraSheet(.grammar)
        }
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

    private func unitRow(_ unit: Unit) -> some View {
        Button {
            Feedback.tap()
            openUnit = unit
        } label: {
            HStack(spacing: 12) {
                OrbIcon(unit.icon, accent: unit.accent, size: 40, symbolScale: 0.4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(unit.title[state.native]).font(.heading(15.5)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    // what is inside, so a chapter can be found without opening it
                    Text(unit.grammar.map { $0.title[state.native] }.joined(separator: " · "))
                        .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Text("\(unit.grammar.count)")
                    .font(.heading(12.5)).foregroundStyle(unit.accent.deep)
                    .frame(width: 28, height: 28)
                    .glassCircle(tint: unit.accent.main, material: false, shadow: false)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkFaint)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(radius: 22)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

/// One chapter's grammar, on a sheet: every rule of it, top to bottom, ready to read.
struct GrammarUnitSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let unit: Unit
    /// What she was searching for, if anything: the rules that match come first.
    var query: String = ""

    private var notes: [GrammarNote] {
        let q = Grader.normalise(query)
        guard !q.isEmpty else { return unit.grammar }
        let hits = unit.grammar.filter {
            Grader.normalise($0.title[state.native]).contains(q) ||
            Grader.normalise($0.body[state.native]).contains(q)
        }
        return hits + unit.grammar.filter { !hits.contains($0) }
    }

    private var level: CEFR? { state.curriculum.level(of: unit.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    OrbIcon(unit.icon, accent: unit.accent, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text([level?.label, S.grammarEyebrow[state.native]]
                                .compactMap { $0 }.joined(separator: " · ").uppercased())
                            .font(.heading(11.5)).kerning(0.8).foregroundStyle(Palette.inkSoft)
                        Text(unit.title[state.native])
                            .font(.display(23)).foregroundStyle(Gradients.title)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    GlassCircleButton(icon: "xmark", size: 40, tint: Palette.inkSoft) {
                        Feedback.tap(); dismiss()
                    }
                }
                .padding(.bottom, 4)

                ForEach(notes) { note in
                    GrammarNoteCard(note: note)
                }
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.top, 26)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }
}
