import XCTest
@testable import Uzbelia

/// The knowledge checks that let a learner skip ahead.
final class PlacementTestTests: XCTestCase {

    private func freshState() -> AppState {
        let s = AppState(persistent: false)
        s.chooseCourse(native: .it)
        return s
    }

    func testSkippingAheadOffersATestForEverythingMissed() {
        let state = freshState()
        let nodes = state.nodes(for: .a1)
        let far = nodes[7]
        XCTAssertFalse(state.isUnlocked(far))

        let target = PlacementTest.target(skippingTo: far, state: state)
        XCTAssertNotNil(target)
        XCTAssertEqual(target?.nodesToClear.count, 7, "every skipped node must be covered")
        XCTAssertEqual(target?.questionCount, 15)
        XCTAssertEqual(target?.allowedMistakes, 3)
    }

    func testNoTestIsOfferedForTheNodeYouAreAlreadyOn() {
        let state = freshState()
        let nodes = state.nodes(for: .a1)
        XCTAssertNil(PlacementTest.target(skippingTo: nodes[0], state: state),
                     "the first node is already open")
    }

    func testLevelTestDrawsFromTheLevelBelow() {
        let state = freshState()
        let target = PlacementTest.target(unlocking: .b1, state: state)
        XCTAssertEqual(target.level, .a2)
        XCTAssertEqual(target.questionCount, 20)
        let pairs = PlacementTest.pairs(for: target, state: state)
        let a2 = Set(state.curriculum.levels.first { $0.level == .a2 }!.units.flatMap(\.allPairs))
        XCTAssertTrue(pairs.allSatisfy { a2.contains($0) }, "a B1 test must ask A2 material")
        XCTAssertGreaterThan(pairs.count, 100)
    }

    func testTestSessionsAreAnswerableWithoutAMicrophone() {
        let state = freshState()
        let target = PlacementTest.target(unlocking: .a2, state: state)
        let request = PlacementTest.request(for: target, state: state)
        XCTAssertEqual(request.mode, .test)
        XCTAssertFalse(request.consumesHearts)
        XCTAssertEqual(request.customExercises.count, target.questionCount)
        XCTAssertFalse(request.customExercises.contains { $0.kind == .speak },
                       "a test must not depend on speech recognition")
    }

    func testPassingATestClearsTheSkippedNodesAndUnlocksTheLevel() {
        let state = freshState()
        let nodes = state.nodes(for: .a1)
        let far = nodes[7]
        let target = PlacementTest.target(skippingTo: far, state: state)!

        state.markPassedTest(target, accuracy: 0.9)
        for id in target.nodesToClear {
            XCTAssertTrue(state.isCompleted(id), "\(id) should count as learned")
        }
        XCTAssertTrue(state.isUnlocked(far))

        let levelTarget = PlacementTest.target(unlocking: .b2, state: state)
        state.markPassedTest(levelTarget, accuracy: 0.85)
        XCTAssertTrue(state.isLevelUnlocked(.b2))
        XCTAssertTrue(state.isLevelUnlocked(.b1), "levels unlock cumulatively")
    }
}
