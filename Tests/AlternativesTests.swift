import XCTest
@testable import Uzbelia

/// More than one wording can be right. These are the rules that decide which.
final class AlternativeAnswerTests: XCTestCase {

    private let course = [
        Pair(it: "A domani!", uz: "Ertaga ko'rishguncha!"),
        Pair(it: "A domani!", uz: "Ertagacha!"),          // the same goodbye, said shorter
        Pair(it: "Come stai?", uz: "Qalaysan?"),
        Pair(it: "Sto bene", uz: "Yaxshiman"),
        Pair(it: "buonanotte", uz: "xayrli tun")
    ]

    override func setUp() {
        super.setUp()
        Glossary.prime(with: course)
    }

    private func translation(of prompt: Pair, into language: Language) -> Exercise {
        Exercise(kind: .type, pair: prompt,
                 prompt: prompt[language.other], promptLanguage: language.other,
                 answer: prompt[language], answerLanguage: language)
    }

    // MARK: - Which questions are open at all

    func testOnlyFreeTranslationsCanHaveASecondRightAnswer() {
        XCTAssertTrue(AnswerJudge.isOpen(.type))
        XCTAssertTrue(AnswerJudge.isOpen(.wordBank))
        // dictation has exactly one right answer: what was said
        XCTAssertFalse(AnswerJudge.isOpen(.listenType))
        XCTAssertFalse(AnswerJudge.isOpen(.choice))
        XCTAssertFalse(AnswerJudge.isOpen(.listenChoice))
        XCTAssertFalse(AnswerJudge.isOpen(.fillBlank))
        XCTAssertFalse(AnswerJudge.isOpen(.speak))
        XCTAssertFalse(AnswerJudge.isOpen(.match))
    }

    // MARK: - What the course itself already vouches for

    func testAWordingTheCourseTeachesElsewhereIsAccepted() {
        let ex = Exercise(kind: .type, pair: course[0],
                          prompt: "A domani!", promptLanguage: .it,
                          answer: "Ertaga ko'rishguncha!", answerLanguage: .uz)
        XCTAssertTrue(AnswerJudge.courseAgrees("Ertagacha!", with: ex),
                      "the course gives both wordings for the same goodbye")
        XCTAssertTrue(AnswerJudge.courseAgrees("ertagacha", with: ex),
                      "case and punctuation are not the point")
        XCTAssertFalse(AnswerJudge.courseAgrees("xayrli tun", with: ex),
                       "good night is not see you tomorrow")
    }

    func testAnUnrelatedAnswerIsNotTalkedIntoBeingRight() {
        let ex = translation(of: course[3], into: .uz)          // "Sto bene" → "Yaxshiman"
        XCTAssertFalse(AnswerJudge.courseAgrees("Qalaysan?", with: ex))
        XCTAssertFalse(AnswerJudge.courseAgrees("qwerty", with: ex))
        XCTAssertFalse(AnswerJudge.courseAgrees("   ", with: ex))
    }

    func testAWordByWordGuessIsNeverEnoughOnItsOwn() {
        // "yaxshiman xayrli" resolves only word by word, which is no basis for accepting
        let ex = translation(of: course[3], into: .uz)
        XCTAssertFalse(AnswerJudge.courseAgrees("yaxshiman xayrli", with: ex))
    }

    // MARK: - What she has had accepted before

    func testAnAcceptedWordingIsRememberedAndNeverArguedForTwice() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        state.rememberAlternative("Ertagacha!", for: "Ertaga ko'rishguncha!")

        let remembered = state.alternatives(for: "Ertaga ko'rishguncha!")
        XCTAssertTrue(AnswerJudge.alreadyAccepted("ertagacha", remembered: remembered),
                      "it is stored in the same normalised form the grader compares in")

        let ex = translation(of: course[2], into: .uz)          // an unrelated question
        XCTAssertFalse(AnswerJudge.alreadyAccepted("ertagacha",
                                                   remembered: state.alternatives(for: ex.answer)),
                       "an alternative belongs to the answer it was accepted for")
    }

    func testTheSameWordingIsStoredOnlyOnceAndTheListStaysSmall() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        state.rememberAlternative("va tutto ok", for: "Sto bene")
        state.rememberAlternative("VA TUTTO OK!", for: "Sto bene")
        XCTAssertEqual(state.alternatives(for: "Sto bene").count, 1)

        state.rememberAlternative("Sto bene", for: "Sto bene")
        XCTAssertEqual(state.alternatives(for: "Sto bene").count, 1,
                       "the expected answer is not an alternative to itself")

        for i in 0..<20 { state.rememberAlternative("forma \(i)", for: "Sto bene") }
        XCTAssertLessThanOrEqual(state.alternatives(for: "Sto bene").count, 8)
    }

    func testAnOlderSaveWithoutAlternativesStillLoads() throws {
        let legacy = #"{"xp":10,"onboarded":true}"#
        let saved = try JSONDecoder().decode(PersistedState.self, from: Data(legacy.utf8))
        XCTAssertTrue(saved.acceptedAlternatives.isEmpty)
        XCTAssertEqual(saved.xp, 10)
    }

    // MARK: - The offline decision as a whole

    func testTheOfflineRulingCoversBothSourcesAndNothingElse() {
        let ex = Exercise(kind: .type, pair: course[0],
                          prompt: "A domani!", promptLanguage: .it,
                          answer: "Ertaga ko'rishguncha!", answerLanguage: .uz)

        if case .alternative(let canonical, let note)? = AnswerJudge.offline("Ertagacha!", for: ex,
                                                                            remembered: []) {
            XCTAssertEqual(canonical, "Ertaga ko'rishguncha!")
            XCTAssertNil(note, "the course needs no explanation for its own vocabulary")
        } else {
            XCTFail("a wording the course teaches should be accepted without asking anyone")
        }

        XCTAssertNotNil(AnswerJudge.offline("boshqacha", for: ex, remembered: ["boshqacha"]))
        XCTAssertNil(AnswerJudge.offline("xayrli tun", for: ex, remembered: []))
        XCTAssertNil(AnswerJudge.offline("", for: ex, remembered: []))

        var dictation = ex
        dictation.kind = .listenType
        XCTAssertNil(AnswerJudge.offline("Ertagacha!", for: dictation, remembered: []),
                     "dictation is not a translation: there is one right answer")
    }

    func testWithoutAKeyNothingIsSentAnywhere() async {
        let ex = translation(of: course[3], into: .uz)
        let ruling = await AnswerJudge.secondOpinion("hammasi joyida", for: ex, level: .a1,
                                                     native: .it, provider: .none, apiKey: "")
        XCTAssertNil(ruling, "no key means the grader's own verdict stands")
    }

    // MARK: - What an accepted alternative does to the session

    func testAnAcceptedAlternativeCountsAsARightAnswer() {
        let ex = translation(of: course[3], into: .uz)
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "hammasi joyida"

        // the plain grader turns it down...
        guard case .wrong = engine.grade() else { return XCTFail("expected the grader to reject it") }
        XCTAssertNil(engine.verdict, "grading alone must record nothing")
        XCTAssertEqual(engine.mistakePairs.count, 0)

        // ...and the second opinion overrides it
        engine.commit(.alternative(canonical: ex.answer, note: "Modo colloquiale."))
        XCTAssertEqual(engine.accuracy, 1)
        XCTAssertTrue(engine.mistakePairs.isEmpty, "an accepted wording is not a mistake")
        XCTAssertEqual(engine.verdict, .alternative(canonical: ex.answer, note: "Modo colloquiale."))
    }

    func testARejectedAnswerStillCostsHerTheQuestion() {
        let ex = translation(of: course[3], into: .uz)
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "xayrli tun"
        engine.commit(engine.grade())
        XCTAssertEqual(engine.mistakePairs.count, 1)
        XCTAssertEqual(engine.accuracy, 0)
    }

    func testCheckingBlocksASecondTapWhileTheAnswerIsBeingReconsidered() {
        let ex = translation(of: course[3], into: .uz)
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "hammasi joyida"
        XCTAssertTrue(engine.canCheck)
        engine.checking = true
        XCTAssertFalse(engine.canCheck)
    }

    func testEveryVerdictKnowsWhetherItWasAccepted() {
        XCTAssertTrue(Verdict.correct.isAccepted)
        XCTAssertTrue(Verdict.almost("x").isAccepted)
        XCTAssertTrue(Verdict.alternative(canonical: "x", note: nil).isAccepted)
        XCTAssertFalse(Verdict.wrong("x").isAccepted)
    }
}

/// Which key the app actually uses, and what happens when there is none.
final class BuiltInKeyTests: XCTestCase {

    func testWithNoKeyAnywhereTheAppRunsOffline() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        guard Secrets.builtIn == nil else {
            // a key has been pasted into Secrets.swift: then it is the one in use
            XCTAssertEqual(state.aiProvider, Secrets.builtIn?.provider)
            XCTAssertEqual(state.aiKey, Secrets.builtIn?.key)
            XCTAssertTrue(state.aiIsBuiltIn)
            return
        }
        XCTAssertEqual(state.aiProvider, .none)
        XCTAssertTrue(state.aiKey.isEmpty)
        XCTAssertFalse(state.aiIsBuiltIn)
        XCTAssertFalse(AIClient.isConfigured(provider: state.aiProvider, key: state.aiKey))
    }

    func testAKeyTypedInTheAppWinsOverTheOneCompiledIn() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        state.settings.aiProvider = .gemini
        state.settings.aiKey = "AIzaTypedByHand"

        XCTAssertEqual(state.aiProvider, .gemini)
        XCTAssertEqual(state.aiKey, "AIzaTypedByHand")
        XCTAssertFalse(state.aiIsBuiltIn, "it is her key, not the app's")
    }

    func testAHalfFilledSettingNeverCountsAsAKey() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        state.settings.aiProvider = .gemini
        state.settings.aiKey = "   "                 // picked a provider, pasted nothing
        XCTAssertEqual(state.aiProvider, Secrets.builtIn?.provider ?? .none)
        XCTAssertEqual(state.aiKey, Secrets.builtIn?.key ?? "")
    }

    func testTheKeyShippedWithTheAppLooksLikeAKeyAndNotAPlaceholder() {
        guard let builtIn = Secrets.builtIn else { return }     // nothing pasted yet
        switch builtIn.provider {
        case .gemini:
            // Google issues both shapes: the older AIza… keys and, from late 2026, AQ.…
            XCTAssertTrue(builtIn.key.hasPrefix("AIza") || builtIn.key.hasPrefix("AQ."),
                          "a Gemini API key begins AIza or AQ.")
            XCTAssertGreaterThan(builtIn.key.count, 20)
        case .claude:
            XCTAssertTrue(builtIn.key.hasPrefix("sk-ant-"))
        case .none:
            XCTFail("builtIn should never report .none")
        }
    }

    func testTheModelsAskedForAreOnesGoogleStillServes() {
        // the 2.5 generation answers new keys with "no longer available to new users"
        XCTAssertFalse(AIClient.geminiModels.contains { $0.hasPrefix("gemini-2.") },
                       "a retired model would make every call fall through to offline")
        XCTAssertEqual(AIClient.geminiModels.first, "gemini-3.6-flash")
        XCTAssertGreaterThan(AIClient.geminiModels.count, 1, "there must be something to fall back to")
    }
}

/// The exact case from the screenshot: "A domani!" answered with `ertagacha`, which the
/// course does not list and which is perfectly good Uzbek.
final class MineIsRightTooTests: XCTestCase {

    private let aDomani = Pair(it: "A domani!", uz: "Ertaga ko'rishguncha!")

    private func question() -> Exercise {
        Exercise(kind: .type, pair: aDomani,
                 prompt: aDomani.it, promptLanguage: .it,
                 answer: aDomani.uz, answerLanguage: .uz)
    }

    override func setUp() {
        super.setUp()
        Glossary.prime(with: [aDomani])       // a course that has never met "ertagacha"
    }

    func testTheCourseAloneCannotAcceptAWordingItHasNeverSeen() {
        let ex = question()
        XCTAssertFalse(AnswerJudge.courseAgrees("ertagacha", with: ex))
        XCTAssertNil(AnswerJudge.offline("ertagacha", for: ex, remembered: []),
                     "nothing offline can vouch for it the first time round")
    }

    func testSayingItIsRightAcceptsIt_GivesTheHeartBackAndRemembersItForGood() {
        let state = AppState(persistent: false)
        state.chooseCourse(native: .it)
        state.settings.unlimitedResources = false          // so hearts actually move
        let before = state.hearts

        let ex = question()
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "ertagacha"

        // marked wrong, as it is today
        engine.commit(engine.grade())
        state.loseHeart()
        XCTAssertEqual(engine.verdict, .wrong(aDomani.uz))
        XCTAssertEqual(engine.mistakePairs.count, 1)
        XCTAssertEqual(state.hearts, before - 1)

        // she taps "anche la mia è giusta"
        state.rememberAlternative(engine.givenAnswer, for: ex.answer)
        state.gradePair(ex.pair, correct: true)
        state.regainHeart()
        engine.acceptAnswerAnyway()

        XCTAssertEqual(engine.verdict, .alternative(canonical: aDomani.uz, note: nil))
        XCTAssertTrue(engine.mistakePairs.isEmpty, "it is no longer a mistake")
        XCTAssertEqual(engine.accuracy, 1)
        XCTAssertEqual(state.hearts, before, "the heart comes back")

        // and from now on it is simply right, offline, with no one to ask
        let later = question()
        XCTAssertNotNil(AnswerJudge.offline("ertagacha", for: later,
                                            remembered: state.alternatives(for: later.answer)))
        XCTAssertNotNil(AnswerJudge.offline("ERTAGACHA!", for: later,
                                            remembered: state.alternatives(for: later.answer)),
                        "however she types it next time")
    }

    func testAnAcceptedAnswerIsNotAskedAgainLaterInTheSameLesson() {
        let ex = question()
        let engine = LessonEngine(exercises: [ex])
        engine.typed = "ertagacha"
        engine.commit(engine.grade())
        engine.acceptAnswerAnyway()
        engine.advance()
        XCTAssertTrue(engine.finished, "a wrong answer comes back later; an accepted one does not")
    }

    func testTheOfferIsOnlyMadeWhereMoreThanOneAnswerIsPossible() {
        // the button appears on a written translation…
        XCTAssertTrue(AnswerJudge.isOpen(.type))
        // …and never on dictation or on a question with buttons for answers
        XCTAssertFalse(AnswerJudge.isOpen(.listenType))
        XCTAssertFalse(AnswerJudge.isOpen(.choice))
    }

    func testSayingItIsRightDoesNothingWhenTheAnswerWasNotMarkedWrong() {
        let ex = question()
        let engine = LessonEngine(exercises: [ex])
        engine.typed = aDomani.uz
        engine.commit(engine.grade())
        XCTAssertEqual(engine.verdict, .correct)
        engine.acceptAnswerAnyway()
        XCTAssertEqual(engine.verdict, .correct, "there is nothing to take back")
        XCTAssertEqual(engine.accuracy, 1)
    }
}
