import XCTest
@testable import Uzbelia

/// "Not right now": putting speaking or listening aside for a quarter of an hour.
final class SkillSnoozeTests: XCTestCase {

    private func learner() -> AppState {
        let s = AppState(persistent: false)
        s.chooseCourse(native: .it)
        return s
    }

    func testNothingIsOnHoldToBeginWith() {
        let state = learner()
        for skill in Skill.allCases { XCTAssertFalse(state.isSnoozed(skill)) }
        XCTAssertTrue(state.effectiveSettings.speakingExercises)
        XCTAssertTrue(state.effectiveSettings.listeningExercises)
    }

    func testPuttingSpeakingAsideStopsSpeakingAndLeavesListeningAlone() {
        let state = learner()
        state.snooze(.speaking)
        XCTAssertTrue(state.isSnoozed(.speaking))
        XCTAssertFalse(state.isSnoozed(.listening))
        XCTAssertFalse(state.effectiveSettings.speakingExercises)
        XCTAssertTrue(state.effectiveSettings.listeningExercises, "she only asked for silence, not deafness")
    }

    func testTheHoldRunsOutOnItsOwn() {
        let state = learner()
        state.snooze(.listening, minutes: 15)
        XCTAssertEqual(state.snoozeMinutesLeft(.listening), 15)

        state.snooze(.listening, minutes: -1)          // as if a quarter of an hour had passed
        XCTAssertFalse(state.isSnoozed(.listening))
        XCTAssertNil(state.snoozeEnds(.listening))
        XCTAssertTrue(state.effectiveSettings.listeningExercises)
    }

    func testItCanBeCalledOffEarly() {
        let state = learner()
        state.snooze(.speaking)
        state.wakeUp(.speaking)
        XCTAssertFalse(state.isSnoozed(.speaking))
    }

    func testAHoldSurvivesClosingTheApp() throws {
        var saved = PersistedState()
        saved.skillSnoozes[Skill.speaking.rawValue] = Date().addingTimeInterval(900)
        let data = try JSONEncoder().encode(saved)
        let back = try JSONDecoder().decode(PersistedState.self, from: data)
        XCTAssertNotNil(back.skillSnoozes[Skill.speaking.rawValue])
        XCTAssertEqual(back.skillSnoozes.count, 1)
    }

    func testAnOlderSaveWithNoHoldsStillLoads() throws {
        let legacy = #"{"xp":5,"onboarded":true}"#
        let saved = try JSONDecoder().decode(PersistedState.self, from: Data(legacy.utf8))
        XCTAssertTrue(saved.skillSnoozes.isEmpty)
    }

    func testASessionBuiltWhileOnHoldHasNoneOfThatSkill() {
        let state = learner()
        state.snooze(.speaking)
        state.snooze(.listening)
        guard let unit = state.curriculum.allUnits.first,
              let node = unit.nodes(level: .a1, index: 0).first else { return XCTFail() }
        let session = ExerciseFactory.session(for: node, unit: unit,
                                              curriculum: state.curriculum,
                                              native: .it,
                                              settings: state.effectiveSettings)
        XCTAssertFalse(session.isEmpty)
        XCTAssertFalse(session.contains { $0.trainsSkill == .speaking })
        XCTAssertFalse(session.contains { $0.trainsSkill == .listening })
    }

    // MARK: - What happens to the questions already queued

    func testQueuedQuestionsAreRewrittenRatherThanThrownAway() {
        let pair = Pair(it: "buongiorno", uz: "xayrli tong")
        let speak = Exercise(kind: .speak, pair: pair, prompt: pair.uz, promptLanguage: .uz,
                             answer: pair.uz, answerLanguage: .uz,
                             audioText: pair.uz, audioLanguage: .uz)
        let dictation = Exercise(kind: .listenType, pair: pair, prompt: "", promptLanguage: .uz,
                                 answer: pair.uz, answerLanguage: .uz,
                                 audioText: pair.uz, audioLanguage: .uz)
        let reading = Exercise(kind: .choice, pair: pair, prompt: pair.it, promptLanguage: .it,
                               answer: pair.uz, answerLanguage: .uz, options: [pair.uz, "salom"])

        let engine = LessonEngine(exercises: [reading, speak, dictation])
        XCTAssertEqual(engine.exercises.count, 3)

        engine.setAside(.speaking, native: .it)
        XCTAssertEqual(engine.exercises.count, 3, "the lesson keeps its length")
        XCTAssertEqual(engine.exercises[1].kind, .type, "a pronunciation becomes a written translation")
        XCTAssertNil(engine.exercises[1].audioText)
        XCTAssertEqual(engine.exercises[2].kind, .listenType, "listening was not what she put aside")
    }

    func testPuttingASkillAsideMovesPastTheQuestionOnScreen() {
        let pair = Pair(it: "grazie", uz: "rahmat")
        let speak = Exercise(kind: .speak, pair: pair, prompt: pair.uz, promptLanguage: .uz,
                             answer: pair.uz, answerLanguage: .uz)
        let after = Exercise(kind: .choice, pair: pair, prompt: pair.it, promptLanguage: .it,
                             answer: pair.uz, answerLanguage: .uz, options: [pair.uz, "salom"])
        let engine = LessonEngine(exercises: [speak, after])
        engine.setAside(.speaking, native: .it)
        XCTAssertEqual(engine.index, 1, "it does not sit there waiting for a microphone")
        XCTAssertEqual(engine.current?.kind, .choice)
    }

    func testARewrittenDictationAsksFromHerOwnLanguage() {
        let pair = Pair(it: "acqua", uz: "suv")
        let dictation = Exercise(kind: .listenType, pair: pair, prompt: "", promptLanguage: .uz,
                                 answer: pair.uz, answerLanguage: .uz,
                                 audioText: pair.uz, audioLanguage: .uz)
        let rewritten = dictation.withoutAudio(native: .it)
        XCTAssertEqual(rewritten.kind, .type)
        XCTAssertEqual(rewritten.prompt, "acqua")
        XCTAssertEqual(rewritten.promptLanguage, .it)
        XCTAssertEqual(rewritten.answer, "suv", "it still teaches the same word")
        XCTAssertNil(rewritten.audioLanguage)
    }
}

/// «Scopri il tuo livello»: the quiz that says where to start.
final class LevelFinderTests: XCTestCase {

    private var curriculum: Curriculum!
    override func setUp() {
        super.setUp()
        curriculum = ContentStore.loadCurriculum()
    }

    private func quiz() -> LevelFinder.Quiz {
        LevelFinder.quiz(curriculum: curriculum, native: .it, settings: Settings())
    }

    func testTheQuizWalksTheWholeCourseInOrder() {
        let q = quiz()
        XCTAssertGreaterThanOrEqual(q.rungs.count, 8)
        XCTAssertLessThanOrEqual(q.rungs.count, 14, "it has to be sittable in one go")
        XCTAssertFalse(q.exercises.isEmpty)

        let levels = q.rungs.map(\.level)
        XCTAssertEqual(levels, levels.sorted(), "the rungs must climb, or the turn means nothing")
        XCTAssertEqual(levels.first, .a1)
        XCTAssertEqual(levels.last, .b2, "someone fluent has to be able to reach the top")
    }

    func testTheQuizNeverNeedsAMicrophoneOrASpeaker() {
        for ex in quiz().exercises {
            XCTAssertNotEqual(ex.kind, .speak, "she may be taking this on a bus")
            XCTAssertNotEqual(ex.kind, .listenType)
            XCTAssertNotEqual(ex.kind, .listenChoice)
        }
    }

    func testKnowingNothingPlacesHerAtTheVeryBeginning() {
        let q = quiz()
        let everything = q.rungs.flatMap(\.pairs)
        let place = LevelFinder.placement(quiz: q, mistakes: everything)
        XCTAssertEqual(place?.level, .a1)
        XCTAssertEqual(place?.unitID, q.rungs.first?.unitID)
    }

    func testKnowingEverythingPlacesHerAtTheEnd() {
        let q = quiz()
        let place = LevelFinder.placement(quiz: q, mistakes: [])
        XCTAssertEqual(place?.level, .b2)
        XCTAssertEqual(place?.unitID, q.rungs.last?.unitID)
    }

    func testSheIsPlacedAtTheFirstThingSheDidNotKnow() {
        let q = quiz()
        guard q.rungs.count > 4 else { return XCTFail("too few rungs to test the turn") }
        // right up to rung 3, wrong from there on
        let missed = q.rungs.dropFirst(3).flatMap(\.pairs)
        let place = LevelFinder.placement(quiz: q, mistakes: missed)
        XCTAssertEqual(place?.unitID, q.rungs[3].unitID,
                       "she starts where her knowledge stopped, not where it ended")
    }

    func testOneUnluckyRungCostsHerNothingBeyondStartingEarlier() {
        let q = quiz()
        guard q.rungs.count > 5 else { return XCTFail() }
        let slip = q.rungs[2].pairs            // a whole rung fumbled by accident
        let place = LevelFinder.placement(quiz: q, mistakes: slip)
        XCTAssertEqual(place?.unitID, q.rungs[2].unitID, "it places her earlier, never later")
    }

    func testApplyingThePlacementOpensTheCourseUpToIt() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        let q = quiz()
        guard q.rungs.count > 4, let place = LevelFinder.placement(quiz: q,
                                                                   mistakes: q.rungs.dropFirst(4).flatMap(\.pairs))
        else { return XCTFail() }

        LevelFinder.apply(place, state: state)
        XCTAssertTrue(state.hasReached(unitID: place.unitID), "the chapter she was placed at is open")
        XCTAssertTrue(state.isLevelUnlocked(place.level))
        // and everything before it counts as done, so the path starts there
        let earlier = q.rungs.first!.unitID
        XCTAssertNotEqual(earlier, place.unitID)
    }

    func testTheQuizIsDifferentEachTimeItIsTaken() {
        var seen = Set<String>()
        for _ in 0..<6 {
            seen.insert(quiz().exercises.map { $0.pair.id }.joined(separator: "|"))
        }
        XCTAssertGreaterThan(seen.count, 3, "the same twelve questions every time would be guessable")
    }
}

/// Exactly the call the onboarding screen makes, because a quiz that comes out empty
/// shows the learner a blank screen and nothing else.
final class OnboardingQuizTests: XCTestCase {

    func testTheQuizTheOnboardingBuildsIsNeverEmpty() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        let q = LevelFinder.quiz(curriculum: state.curriculum,
                                 native: .it,
                                 settings: state.effectiveSettings)
        XCTAssertFalse(q.exercises.isEmpty, "the level test would open onto nothing")
        XCTAssertFalse(q.rungs.isEmpty)
        XCTAssertNotNil(q.floor)
    }

    func testItWorksBeforeAnyCourseHasBeenChosen() {
        // the screen can be reached with the app freshly installed
        let state = AppState(persistent: false)
        let q = LevelFinder.quiz(curriculum: state.curriculum,
                                 native: .it,
                                 settings: state.effectiveSettings)
        XCTAssertFalse(q.exercises.isEmpty)
    }

    func testItWorksForTheOtherDirectionToo() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .uz)
        let q = LevelFinder.quiz(curriculum: state.curriculum,
                                 native: .uz,
                                 settings: state.effectiveSettings)
        XCTAssertFalse(q.exercises.isEmpty)
    }
}
