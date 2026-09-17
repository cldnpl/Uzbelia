import XCTest
@testable import Uzbelia

/// Exercises the pieces of state the screens read on every redraw.
final class AppStateTests: XCTestCase {

    private func freshState(unlimited: Bool = true) -> AppState {
        let s = AppState(persistent: false)
        s.chooseCourse(native: .it)
        s.settings.unlimitedResources = unlimited
        return s
    }

    private func finish(_ state: AppState, _ node: PathNode, times: Int) {
        for _ in 0..<times {
            state.finishSession(nodeID: node.id, xpEarned: 10, accuracy: 1, minutes: 1, mistakes: [])
        }
    }

    func testDuePairsSurvivesDuplicateTranslations() {
        let state = freshState()
        for pair in state.curriculum.allPairs.prefix(80) {
            state.gradePair(pair, correct: false)
        }
        let due = state.duePairs(limit: 40)          // used to trap on duplicate keys
        XCTAssertLessThanOrEqual(due.count, 40)
        let strengths = due.map { state.strength(of: $0) }
        XCTAssertEqual(strengths, strengths.sorted(), "weakest words must come first")
    }

    func testPracticeHubHasSomethingToShowFromTheStart() {
        let state = freshState()
        XCTAssertFalse(state.learnedPairs.isEmpty, "the practice tab must never be empty")
        XCTAssertFalse(state.practiceReady)
    }

    // MARK: - Five sessions per lesson

    func testALessonNeedsFiveSessionsBeforeTheNextNodeOpens() {
        let state = freshState()
        let nodes = state.nodes(for: .a1)
        XCTAssertEqual(nodes[0].requiredSessions, 5)
        XCTAssertTrue(state.isUnlocked(nodes[0]))

        for pass in 1...4 {
            finish(state, nodes[0], times: 1)
            XCTAssertFalse(state.isUnlocked(nodes[1]), "opened after only \(pass) sessions")
            XCTAssertFalse(state.isCompleted(nodes[0]))
        }
        finish(state, nodes[0], times: 1)
        XCTAssertTrue(state.isCompleted(nodes[0]))
        XCTAssertTrue(state.isUnlocked(nodes[1]))
        XCTAssertFalse(state.isUnlocked(nodes[2]))
    }

    func testTheFiveSessionsTrainFiveDifferentThings() {
        let state = freshState()
        let node = state.nodes(for: .a1)[0]
        var seen: [SessionFocus] = []
        for pass in 0..<5 {
            seen.append(state.nextFocus(for: node))
            finish(state, node, times: 1)
            XCTAssertEqual(state.sessionsDone(node.id), pass + 1)
        }
        XCTAssertEqual(Set(seen).count, 5, "the five passes must all be different")
        XCTAssertEqual(seen.first, .discover)
        XCTAssertEqual(seen.last, .review)
    }

    func testStoriesAndReviewsAreSingleSession() {
        let state = freshState()
        let nodes = state.nodes(for: .a1)
        let story = nodes.first { if case .story = $0.kind { return true } else { return false } }!
        let review = nodes.first { if case .review = $0.kind { return true } else { return false } }!
        XCTAssertEqual(story.requiredSessions, 1)
        XCTAssertEqual(review.requiredSessions, 1)
        finish(state, story, times: 1)
        XCTAssertTrue(state.isCompleted(story))
    }

    func testUnitProgressCountsSessionsNotJustNodes() {
        let state = freshState()
        let unit = state.curriculum.levels[0].units[0]
        let node = unit.nodes(level: .a1, index: 0)[0]
        XCTAssertEqual(state.completion(ofUnit: unit, level: .a1), 0)
        finish(state, node, times: 1)
        let afterOne = state.completion(ofUnit: unit, level: .a1)
        XCTAssertGreaterThan(afterOne, 0, "the bar must move after a single session")
        XCTAssertLessThan(afterOne, 0.2)
    }

    // MARK: - Unlimited resources

    func testHeartsAndGemsAreUnlimitedByDefault() {
        let state = freshState()
        XCTAssertTrue(state.unlimited)
        for _ in 0..<20 { state.loseHeart() }
        XCTAssertEqual(state.hearts, AppState.heartCap, "a gift build never runs out of hearts")
    }

    func testHeartsStillWorkWhenTheLimitIsTurnedBackOn() {
        let state = freshState(unlimited: false)
        for _ in 0..<AppState.heartCap { state.loseHeart() }
        XCTAssertEqual(state.hearts, 0)
        XCTAssertTrue(state.refillHearts(costingGems: true))
        XCTAssertEqual(state.hearts, AppState.heartCap)
    }

    // MARK: - Progress, streak, levels

    func testFinishingASessionAwardsXPAndStreak() {
        let state = freshState()
        let node = state.nodes(for: .a1)[0]
        state.finishSession(nodeID: node.id, xpEarned: 20, accuracy: 0.9,
                            minutes: 3, mistakes: [Pair(it: "ciao", uz: "salom")])
        XCTAssertEqual(state.xp, 20)
        XCTAssertEqual(state.xpToday, 20)
        XCTAssertEqual(state.streak, 1)
        XCTAssertEqual(state.mistakesBank.count, 1)
    }

    func testStreakCountsOnlyOncePerDay() {
        let state = freshState()
        let nodes = state.nodes(for: .a1)
        finish(state, nodes[0], times: 2)
        XCTAssertEqual(state.streak, 1)
        XCTAssertEqual(state.xp, 20)
    }

    func testLevelsUnlockCumulatively() {
        let state = freshState()
        XCTAssertTrue(state.isLevelUnlocked(.a1))
        XCTAssertFalse(state.isLevelUnlocked(.b1))
        state.unlock(level: .b1)
        XCTAssertTrue(state.isLevelUnlocked(.a2))
        XCTAssertTrue(state.isLevelUnlocked(.b1))
        XCTAssertFalse(state.isLevelUnlocked(.b2))
    }
}
