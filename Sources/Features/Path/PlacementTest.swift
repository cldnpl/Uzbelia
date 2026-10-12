import SwiftUI

/// What a knowledge check is trying to unlock.
struct TestTarget: Identifiable, Hashable {
    enum Kind: Hashable {
        case skipTo(nodeID: String)     // jump ahead inside a level
        case unlockLevel(CEFR)          // open a whole CEFR level
    }

    var kind: Kind
    var level: CEFR
    /// Nodes that get marked as done when the test is passed.
    var nodesToClear: [String]
    var title: Bilingual
    var questionCount: Int
    var passMark: Double = 0.8

    var id: String {
        switch kind {
        case .skipTo(let n): return "skip-\(n)"
        case .unlockLevel(let l): return "level-\(l.rawValue)"
        }
    }

    var allowedMistakes: Int {
        Int((Double(questionCount) * (1 - passMark)).rounded())
    }
}

enum PlacementTest {

    /// Test to jump straight to a locked node: everything the learner skipped over.
    static func target(skippingTo node: PathNode, state: AppState) -> TestTarget? {
        let ids = state.nodeIDs(for: node.level)
        guard let idx = ids.firstIndex(of: node.id), idx > 0 else { return nil }
        let skipped = ids[0..<idx].filter { !state.isCompleted($0) }
        guard !skipped.isEmpty else { return nil }
        return TestTarget(kind: .skipTo(nodeID: node.id),
                          level: node.level,
                          nodesToClear: Array(skipped),
                          title: node.title,
                          questionCount: 15)
    }

    /// Test to open a locked level: the level below it, end to end.
    static func target(unlocking level: CEFR, state: AppState) -> TestTarget {
        let previous = CEFR.allCases.last { $0 < level } ?? .a1
        return TestTarget(kind: .unlockLevel(level),
                          level: previous,
                          nodesToClear: [],
                          title: Bilingual("Level \(level.label)"),
                          questionCount: 20)
    }

    /// The pool a test draws its questions from.
    static func pairs(for target: TestTarget, state: AppState) -> [Pair] {
        switch target.kind {
        case .skipTo:
            let wanted = Set(target.nodesToClear)
            var out: [Pair] = []
            for unit in state.curriculum.allUnits {
                for lesson in unit.lessons where wanted.contains(lesson.id) {
                    out.append(contentsOf: lesson.allPairs)
                }
                if wanted.contains("\(unit.id)-review") || wanted.contains("\(unit.id)-story") {
                    out.append(contentsOf: unit.allPairs)
                }
            }
            return out.isEmpty ? state.curriculum.allPairs : out
        case .unlockLevel:
            let pack = state.curriculum.levels.first { $0.level == target.level }
            return pack?.units.flatMap(\.allPairs) ?? state.curriculum.allPairs
        }
    }

    static func request(for target: TestTarget, state: AppState) -> SessionRequest {
        let source = pairs(for: target, state: state)
        let exercises = ExerciseFactory.placementTest(pairs: source,
                                                      pool: state.curriculum.allPairs,
                                                      native: state.native,
                                                      settings: state.effectiveSettings,
                                                      count: target.questionCount)
        return SessionRequest(mode: .test,
                              customExercises: exercises,
                              customTitle: target.title,
                              consumesHearts: false,
                              xpReward: 30,
                              testTarget: target)
    }
}

// MARK: - Intro sheet

struct TestIntroSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let target: TestTarget
    let start: (SessionRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                OrbIcon("checkmark.seal.fill", accent: .purple, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(S.testTitle[state.native])
                        .font(.display(22)).foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 12) {
                rule(icon: "list.number",
                     text: "\(target.questionCount) \(S.testQuestions[state.native])")
                rule(icon: "checkmark.seal.fill",
                     text: "\(S.testPassMark[state.native]) \(Int(target.passMark * 100))%")
                rule(icon: "xmark.circle",
                     text: "\(S.testMistakes[state.native]) \(target.allowedMistakes)")
                rule(icon: "heart.slash", text: S.testNoHearts[state.native])
            }
            .padding(16)
            .glass(radius: 24)

            Spacer(minLength: 0)

            Button {
                Feedback.pop()
                start(PlacementTest.request(for: target, state: state))
            } label: { Text(S.testStart[state.native]) }
            .buttonStyle(.primary(.violet))

            Button { dismiss() } label: { Text(S.cancel[state.native]) }
                .buttonStyle(.glass)
        }
        .padding(Metrics.hPad)
        .padding(.top, 16)
    }

    private var subtitle: String {
        switch target.kind {
        case .skipTo:
            return "Pass it and every lesson up to “\(target.title.en)” unlocks."
        case .unlockLevel(let lvl):
            return "Questions from level \(target.level.label). Pass it and all of \(lvl.label) opens."
        }
    }

    private func rule(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.purpleDeep)
                .frame(width: 30, height: 30)
                .glassCircle(tint: Palette.purple, material: false, shadow: false)
            Text(text).font(.plain(14.5)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
    }
}
