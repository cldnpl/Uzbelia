import XCTest
@testable import Uzbelia

/// The free-conversation video call: question planning and the end-of-call report.
final class CallPlannerTests: XCTestCase {

    private func freshState() -> AppState {
        let s = AppState(persistent: false)
        s.chooseCourse(.uz)
        return s
    }

    func testEveryUnitHasContextualQuestions() {
        let state = freshState()
        XCTAssertEqual(state.questions.units.count, state.curriculum.allUnits.count)
        for unit in state.curriculum.allUnits {
            let qs = state.questions.questions(forUnit: unit.id)
            XCTAssertGreaterThanOrEqual(qs.count, 6, "\(unit.id) has too few call questions")
            for q in qs {
                XCTAssertFalse(q.en.isEmpty || q.tx.isEmpty)
                XCTAssertTrue(q.en.contains("?") || q.en.contains("."),
                              "\(unit.id): '\(q.en)' does not read like a prompt")
            }
        }
        for level in CEFR.allCases {
            for slot in ["open", "follow", "close"] {
                XCTAssertGreaterThanOrEqual(state.questions.generic(level, slot).count, 2,
                                            "\(level.label).\(slot) needs variants")
            }
        }
    }

    func testACallIsBuiltAroundTheChapterYouReached() {
        let state = freshState()
        // walk the learner up to the food unit
        let food = state.curriculum.unit(id: "a1u4")!
        let target = PlacementTest.target(skippingTo: food.nodes(level: .a1, index: 0)[0], state: state)!
        state.markPassedTest(target, accuracy: 0.9)

        let plan = CallPlanner.plan(level: .a1, state: state)
        XCTAssertEqual(plan.focusUnit?.id, "a1u4")
        XCTAssertGreaterThanOrEqual(plan.questions.count, 5)

        let fromFocus = plan.questions.filter { $0.unitID == "a1u4" }
        XCTAssertGreaterThanOrEqual(fromFocus.count, 3,
                                    "most questions should come from the current chapter")
        XCTAssertTrue(plan.questions.first?.origin == .opening)
        XCTAssertTrue(plan.questions.last?.origin == .closing)
        XCTAssertFalse(plan.questions.contains { $0.unitID == "a1u8" },
                       "a call must not ask about chapters the learner has not reached")
    }

    func testTwoCallsAreNeverIdentical() {
        let state = freshState()
        let food = state.curriculum.unit(id: "a1u4")!
        let target = PlacementTest.target(skippingTo: food.nodes(level: .a1, index: 0)[0], state: state)!
        state.markPassedTest(target, accuracy: 0.9)

        var signatures = Set<String>()
        for _ in 0..<12 {
            let plan = CallPlanner.plan(level: .a1, state: state)
            signatures.insert(plan.questions.map { $0.text.tx }.joined(separator: "|"))
        }
        XCTAssertGreaterThan(signatures.count, 8, "calls repeat themselves too often")
    }

    /// The bug this guards against: a call about family that jumped to bus tickets
    /// and then to "Why?", because the plan was a shuffled bag of questions.
    func testACallStaysOnOneSubjectAtATime() {
        let state = freshState()
        let food = state.curriculum.unit(id: "a1u4")!
        let target = PlacementTest.target(skippingTo: food.nodes(level: .a1, index: 0)[0], state: state)!
        state.markPassedTest(target, accuracy: 0.9)
        let bank = state.questions
        let chapter = bank.questions(forUnit: "a1u4")

        for _ in 0..<20 {
            let plan = CallPlanner.plan(level: .a1, state: state)
            let body = plan.questions.dropFirst().dropLast()
            XCTAssertTrue(body.allSatisfy { $0.unitID == "a1u4" },
                          "nothing from other chapters in the middle of a call")
            var expected: [Bilingual] = []          // what may come next in this thread
            var lastStart = -1
            for q in body {
                if let i = chapter.firstIndex(of: q.text) {
                    XCTAssertTrue(expected.isEmpty || q.lead != nil,
                                  "a new subject is announced, never just switched to")
                    XCTAssertGreaterThan(i, lastStart, "threads keep the chapter's own order")
                    lastStart = i
                    expected = bank.followUps(forUnit: "a1u4", question: i)
                } else {
                    XCTAssertEqual(q.text, expected.first,
                                   "'\(q.text.en)' does not follow from the question before it")
                    expected.removeFirst()
                }
            }
        }
    }

    func testEveryChapterQuestionHasItsFollowUps() {
        let state = freshState()
        for unit in state.curriculum.allUnits {
            let questions = state.questions.questions(forUnit: unit.id)
            for i in questions.indices {
                let follows = state.questions.followUps(forUnit: unit.id, question: i)
                XCTAssertEqual(follows.count, 2, "\(unit.id) #\(i) needs two follow-ups")
                for f in follows {
                    XCTAssertFalse(f.en.isEmpty || f.tx.isEmpty)
                    XCTAssertFalse(questions.contains(f), "\(unit.id): a follow-up repeats a question")
                }
            }
        }
    }

    func testEveryLevelCanBeCalled() {
        let state = freshState()
        state.unlock(level: .b2)
        for level in CEFR.allCases {
            let plan = CallPlanner.plan(level: level, state: state)
            XCTAssertFalse(plan.questions.isEmpty, "\(level.label) produced no questions")
            XCTAssertNotNil(plan.focusUnit)
        }
    }
}

/// What the assistant is told before it writes a call, and how the app keeps two
/// calls from coming out the same.
final class CallContextTests: XCTestCase {

    private func learnerAtFoodChapter() -> AppState {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        let food = state.curriculum.unit(id: "a1u4")!
        let target = PlacementTest.target(skippingTo: food.nodes(level: .a1, index: 0)[0], state: state)!
        state.markPassedTest(target, accuracy: 0.9)
        return state
    }

    func testTheBriefingCarriesTheLearnersOwnSituation() {
        let state = learnerAtFoodChapter()
        state.rememberCallQuestions(["Nonushtaga nima yeysiz?"])
        let plan = CallPlanner.plan(level: .a1, state: state)
        let ctx = CallPlanner.context(for: plan, level: .a1, state: state, target: .uz)

        XCTAssertEqual(ctx.unitTitle, plan.focusUnit?.title.tx)
        XCTAssertFalse(ctx.vocabulary.isEmpty)
        XCTAssertFalse(ctx.lessonTopics.isEmpty)
        XCTAssertFalse(ctx.earlierUnits.contains(ctx.unitTitle),
                       "the current chapter is not one of the chapters behind her")

        let briefing = ctx.briefing
        XCTAssertTrue(briefing.contains("A1"))
        XCTAssertTrue(briefing.contains(ctx.unitTitle))
        XCTAssertTrue(briefing.contains(ctx.angle))
        XCTAssertTrue(briefing.contains("Nonushtaga nima yeysiz?"),
                      "a question already asked must reach the model as one to avoid")
    }

    func testEachCallGetsADifferentAngle() {
        let state = learnerAtFoodChapter()
        let plan = CallPlanner.plan(level: .a1, state: state)
        var angles = Set<String>()
        var vocabularies = Set<String>()
        for _ in 0..<20 {
            let ctx = CallPlanner.context(for: plan, level: .a1, state: state, target: .uz)
            angles.insert(ctx.angle)
            vocabularies.insert(ctx.vocabulary.joined(separator: "|"))
        }
        XCTAssertGreaterThan(angles.count, 3, "every call is briefed with the same slant")
        XCTAssertGreaterThan(vocabularies.count, 3, "the same words in the same order every time")
    }

    func testAskedQuestionsAreRememberedWithoutRepeatsOrUnboundedGrowth() {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        state.rememberCallQuestions(["Qalaysiz?", "Qalaysiz?", "  ", "Ismingiz nima?"])
        XCTAssertEqual(state.recentCallQuestions, ["Qalaysiz?", "Ismingiz nima?"])

        state.rememberCallQuestions((0..<80).map { "Savol \($0)?" })
        XCTAssertEqual(state.recentCallQuestions.count, 60)
        XCTAssertEqual(state.recentCallQuestions.last, "Savol 79?")
        XCTAssertFalse(state.recentCallQuestions.contains("Qalaysiz?"), "the oldest ones drop off")
    }

    func testAnOlderSaveWithoutCallHistoryStillLoads() throws {
        let legacy = #"{"xp":300,"streak":4,"onboarded":true}"#
        let saved = try JSONDecoder().decode(PersistedState.self, from: Data(legacy.utf8))
        XCTAssertEqual(saved.xp, 300)
        XCTAssertEqual(saved.streak, 4)
        XCTAssertTrue(saved.recentCallQuestions.isEmpty)
    }
}

final class CallReviewerTests: XCTestCase {

    private var curriculum: Curriculum!
    override func setUp() {
        super.setUp()
        curriculum = ContentStore.loadCurriculum(.uz)
    }

    private func review(_ answers: [String], level: CEFR = .a1) -> CallReview {
        let turns = answers.map {
            CallTurnRecord(question: Bilingual(en: "Question?", tx: "Savol?"),
                           answer: $0, seconds: 5, typed: true)
        }
        return CallReviewer.review(turns: turns, target: .uz,
                                   curriculum: curriculum, level: level)
    }

    func testSkippedAnswersAreReported() {
        let r = review(["", "   "])
        XCTAssertEqual(r.turns.filter { $0.status == .skipped }.count, 2)
        XCTAssertEqual(r.stats.answered, 0)
    }

    func testAnsweringInTheWrongLanguageIsCaught() {
        let r = review(["my name is Claudia and I live in Rome"])       // English, learning Uzbek
        XCTAssertEqual(r.turns[0].status, .wrongLanguage)
        XCTAssertTrue(r.turns[0].corrections.contains { $0.kind == .language })
    }

    func testSpellingSlipsGetTheRightSuggestion() {
        let r = review(["rahmet, men yaxshiman"])
        let fix = r.turns[0].corrections.first { $0.kind == .spelling }
        XCTAssertEqual(fix?.original, "rahmet")
        XCTAssertEqual(fix?.suggestion, "rahmat")
    }

    func testUzbekGrammarRules() {
        let plural = review(["menda uchta kitoblar bor"])
        XCTAssertTrue(plural.turns[0].corrections.contains {
            $0.kind == .grammar && $0.suggestion.contains("uchta kitob")
        }, "the plural after a numeral should be corrected")

        let split = review(["men yaxshi man bugun"])
        XCTAssertTrue(split.turns[0].corrections.contains {
            $0.kind == .grammar && $0.suggestion.contains("yaxshiman")
        }, "a detached personal ending should be joined")
    }

    func testAGoodAnswerIsLeftAlone() {
        let r = review(["men bugun juda yaxshiman va ishga boraman"])
        XCTAssertEqual(r.turns[0].status, .good)
        XCTAssertFalse(r.turns[0].corrections.contains { $0.kind == .grammar },
                       "a correct sentence must not be 'corrected'")
    }

    func testShortAnswersAreFlaggedButNotPunished() {
        let one = review(["ha"], level: .b1)
        XCTAssertEqual(one.turns[0].status, .tooShort)
        XCTAssertFalse(one.tips.contains { $0.en.contains("short") },
                       "a single short answer is not a habit worth nagging about")

        // it only becomes advice when it is a pattern
        let many = review(["ha", "yaxshi", "bilmayman"], level: .b1)
        XCTAssertEqual(many.turns.filter { $0.status == .tooShort }.count, 3)
        XCTAssertTrue(many.tips.contains { $0.en.contains("short") })
    }

    func testStatsAndHeadline() {
        let r = review(["men Toshkentdanman va bu yerda yashayman",
                        "men har kuni ishga boraman",
                        ""])
        XCTAssertEqual(r.stats.total, 3)
        XCTAssertEqual(r.stats.answered, 2)
        XCTAssertGreaterThan(r.stats.words, 8)
        XCTAssertGreaterThan(r.stats.distinctWords, 5)
        XCTAssertFalse(r.headline.en.isEmpty)
        XCTAssertFalse(r.tips.isEmpty)
    }

    func testAValidWordTheCourseDoesNotTeachIsLeftAlone() {
        // "deyman" (I say) is correct Uzbek but absent from the corpus: it must not be
        // "fixed" into "yeyman" (I eat) just because they are one letter apart.
        let r = review(["men rahmet deyman"])
        let fixes = r.turns[0].corrections.filter { $0.kind == .spelling }
        XCTAssertTrue(fixes.contains { $0.original == "rahmet" && $0.suggestion == "rahmat" },
                      "a real typo should still be caught")
        XCTAssertFalse(fixes.contains { $0.original == "deyman" },
                       "a word with a different initial letter is not a typo")
    }

    func testTheReviewerNeverCorrectsWhatItCannotJustify() {
        // a name it has never seen must not be "fixed" into something random
        let r = review(["men Klaudiyaman"])
        XCTAssertFalse(r.turns[0].corrections.contains {
            $0.kind == .spelling && $0.suggestion.count < 4
        })
    }
}

final class CallEngineFlowTests: XCTestCase {

    func testAFullCallRecordsEveryAnswer() {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        let plan = CallPlanner.plan(level: .a1, state: state)
        let engine = CallEngine(level: .a1, target: .uz, plan: plan)

        XCTAssertEqual(engine.phase, .dialling)
        engine.answerCall()
        XCTAssertEqual(engine.phase, .anorchaSpeaking)

        for i in 0..<plan.questions.count {
            engine.anorchaFinishedSpeaking()
            XCTAssertEqual(engine.phase, .yourTurn)
            engine.submit(i == 1 ? "" : "men yaxshiman", typed: true)
            XCTAssertEqual(engine.phase, .reacting)
            engine.advance()
        }
        XCTAssertEqual(engine.phase, .reviewing)
        XCTAssertEqual(engine.records.count, plan.questions.count)
        XCTAssertEqual(engine.xpEarned, 10 + (plan.questions.count - 1) * 5)
    }

    func testWithoutAKeyTheCallStillRunsOnItsScript() async {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        let plan = CallPlanner.plan(level: .a1, state: state)
        let engine = CallEngine(level: .a1, target: .uz, plan: plan)
        let scripted = plan.questions.map { $0.text.tx }

        engine.answerCall()
        engine.anorchaFinishedSpeaking()
        engine.submit("men yaxshiman", typed: true)
        XCTAssertNotNil(engine.reaction, "offline, the acknowledgement is immediate")

        await engine.composeNextTurn(provider: .none, apiKey: "")
        XCTAssertFalse(engine.thinking)
        XCTAssertEqual(engine.plan.questions.map { $0.text.tx }, scripted,
                       "no key means the planned questions are left alone")
    }

    func testALiveCallWaitsForTheReactionInsteadOfCanningIt() async {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        let plan = CallPlanner.plan(level: .a1, state: state)
        let engine = CallEngine(level: .a1, target: .uz, plan: plan)
        engine.live = true
        engine.context = CallPlanner.context(for: plan, level: .a1, state: state, target: .uz)

        engine.answerCall()
        engine.anorchaFinishedSpeaking()
        engine.submit("men yaxshiman", typed: true)
        XCTAssertNil(engine.reaction, "the reaction is written from what she said, not picked from a list")

        // a key that cannot work must not strand the call
        await engine.composeNextTurn(provider: .gemini, apiKey: "")
        XCTAssertEqual(engine.phase, .reacting)
        engine.advance()
        XCTAssertEqual(engine.phase, .anorchaSpeaking)
    }

    /// What the assistant reads: both sides, in order, with a skipped answer marked
    /// as skipped rather than left blank.
    func testTheTranscriptCarriesBothSidesOfTheCall() {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        let plan = CallPlanner.plan(level: .a1, state: state)
        let engine = CallEngine(level: .a1, target: .uz, plan: plan)

        engine.answerCall()
        XCTAssertEqual(engine.transcript.map(\.speaker), [.anorcha])
        XCTAssertEqual(engine.transcript.last?.text, plan.questions[0].spoken(in: .uz))

        engine.anorchaFinishedSpeaking()
        engine.submit("men yaxshiman", typed: false)
        let reaction = engine.reaction?.tx
        engine.advance()
        engine.anorchaFinishedSpeaking()
        engine.skip()

        let lines = engine.transcript
        XCTAssertEqual(lines.map(\.speaker), [.anorcha, .learner, .anorcha, .anorcha, .learner])
        XCTAssertEqual(lines[1].text, "men yaxshiman")
        XCTAssertEqual(lines[2].text, reaction)
        XCTAssertEqual(lines[3].text, plan.questions[1].spoken(in: .uz),
                       "the lead-in is part of what she heard")
        XCTAssertEqual(lines[4].text, CallEngine.skippedMark)
    }

    func testSkippingAQuestionNeedsNoReaction() {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        let plan = CallPlanner.plan(level: .a1, state: state)
        let engine = CallEngine(level: .a1, target: .uz, plan: plan)
        engine.answerCall()
        engine.anorchaFinishedSpeaking()
        engine.skip()
        XCTAssertNil(engine.reaction)
        XCTAssertEqual(engine.askedQuestions(), [plan.questions[0].text.tx])
    }

    func testHangingUpEarlyStillReviewsWhatWasSaid() {
        let state = AppState(persistent: false)
        state.chooseCourse(.uz)
        let plan = CallPlanner.plan(level: .a1, state: state)
        let engine = CallEngine(level: .a1, target: .uz, plan: plan)
        engine.answerCall()
        engine.anorchaFinishedSpeaking()
        engine.submit("men italiyalikman", typed: true)
        engine.advance()
        engine.hangUp()
        XCTAssertEqual(engine.phase, .reviewing)
        XCTAssertEqual(engine.records.count, 1)
    }
}

/// The optional AI connection: everything that can be checked without a key.
final class AIClientTests: XCTestCase {

    func testOfflineIsTheDefault() {
        let settings = Settings()
        XCTAssertEqual(settings.aiProvider, .none)
        XCTAssertTrue(settings.aiKey.isEmpty)
        XCTAssertFalse(AIClient.isConfigured(provider: settings.aiProvider, key: settings.aiKey))
    }

    func testAKeyAloneIsNotEnoughWithoutAProvider() {
        XCTAssertFalse(AIClient.isConfigured(provider: .none, key: "AIzaSomething"))
        XCTAssertFalse(AIClient.isConfigured(provider: .gemini, key: "   "))
        XCTAssertTrue(AIClient.isConfigured(provider: .gemini, key: "AIzaSomething"))
        XCTAssertTrue(AIClient.isConfigured(provider: .claude, key: "sk-ant-x"))
    }

    func testCallingWithoutAKeyFailsImmediatelyInsteadOfHittingTheNetwork() async {
        do {
            _ = try await AIClient.complete(provider: .none, key: "", system: "s",
                                            prompt: "p", maxTokens: 10, json: false)
            XCTFail("should have thrown")
        } catch {
            XCTAssertTrue(error is AIClient.Failure)
        }
    }

    func testJSONIsExtractedFromChattyModelReplies() {
        let fenced = "Here are the questions:\n```json\n[{\"target\":\"a\",\"native\":\"b\"}]\n```\nHappy studying!"
        XCTAssertEqual(AIClient.extractJSON(fenced), "[{\"target\":\"a\",\"native\":\"b\"}]")

        let object = "Sure! {\"headline\":\"ok\",\"tips\":[]} hope it helps"
        XCTAssertEqual(AIClient.extractJSON(object), "{\"headline\":\"ok\",\"tips\":[]}")

        XCTAssertEqual(AIClient.extractJSON("  plain text  "), "plain text")
    }

    func testProviderErrorsAreReadable() {
        let google = #"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}"#
        XCTAssertEqual(AIClient.readableMessage(from: google),
                       "API key not valid. Please pass a valid API key.")

        let anthropic = #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
        XCTAssertEqual(AIClient.readableMessage(from: anthropic), "invalid x-api-key")

        XCTAssertEqual(AIClient.readableMessage(from: "not json at all"), "not json at all")

        let described = (AIClient.Failure.http(400, google) as LocalizedError).errorDescription ?? ""
        XCTAssertTrue(described.contains("API key not valid"))
        XCTAssertFalse(described.contains("INVALID_ARGUMENT"), "the raw payload should not leak into the UI")
    }

    func testProviderMetadataIsUsable() {
        XCTAssertEqual(AIProvider.allCases.count, 3)
        for provider in AIProvider.allCases where provider != .none {
            XCTAssertFalse(provider.console.isEmpty, "\(provider) has no console address")
            XCTAssertFalse(provider.keyPrefixHint.isEmpty)
            XCTAssertFalse(provider.label.en.isEmpty)
        }
    }

    func testTheOldClaudeOnlyKeyIsMigrated() throws {
        let legacy = #"{"sounds":true,"claudeAPIKey":"sk-ant-legacy"}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(legacy.utf8))
        XCTAssertEqual(settings.aiProvider, .claude)
        XCTAssertEqual(settings.aiKey, "sk-ant-legacy")

        // and it is never written back out
        let round = try JSONEncoder().encode(settings)
        XCTAssertFalse(String(data: round, encoding: .utf8)!.contains("claudeAPIKey"))
    }

    func testSettingsSurviveARoundTrip() throws {
        var settings = Settings()
        settings.aiProvider = .gemini
        settings.aiKey = "AIzaTest"
        settings.dailyGoal = 100
        let data = try JSONEncoder().encode(settings)
        let back = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(back.aiProvider, .gemini)
        XCTAssertEqual(back.aiKey, "AIzaTest")
        XCTAssertEqual(back.dailyGoal, 100)
    }
}

/// The free tier allows twenty requests a day: the extras must stop long before the
/// video call does, and a "no more today" from Google must stop everything at once.
final class AIBudgetTests: XCTestCase {

    override func setUp() { AIBudget.reset() }
    override func tearDown() { AIBudget.reset() }

    func testExtrasStopLongBeforeConversations() {
        for _ in 0..<AIBudget.ceiling(for: .extra) { AIBudget.spend() }
        XCTAssertFalse(AIBudget.canSpend(.extra), "a tapped word must not eat the call's requests")
        XCTAssertTrue(AIBudget.canSpend(.feedback))
        XCTAssertTrue(AIBudget.canSpend(.conversation))
    }

    func testTheDailyRefusalPausesEverythingUntilTheTimeGoogleGave() {
        let body = #"{"error":{"code":429,"details":[{"quotaId":"GenerateRequestsPerDayPerProjectPerModel-FreeTier"},{"@type":"type.googleapis.com/google.rpc.RetryInfo","retryDelay": "120s"}]}}"#
        XCTAssertTrue(AIBudget.noteRefusal(code: 429, body: body))
        XCTAssertFalse(AIBudget.canSpend(.conversation))
        XCTAssertEqual(AIBudget.pausedUntil?.timeIntervalSinceNow ?? 0, 120, accuracy: 5)
    }

    func testAPerMinuteLimitIsNotTheEndOfTheDay() {
        let body = #"{"error":{"code":429,"details":[{"quotaId":"GenerateRequestsPerMinutePerProjectPerModel"}]}}"#
        XCTAssertFalse(AIBudget.noteRefusal(code: 429, body: body))
        XCTAssertTrue(AIBudget.canSpend(.conversation))
    }
}
