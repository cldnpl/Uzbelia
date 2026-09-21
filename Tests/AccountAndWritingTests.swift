import XCTest
@testable import Uzbelia

// MARK: - Merging two copies of the same learner

/// The account exists for one reason: never to lose a lesson. These are the cases
/// that would lose one if the merge were "last write wins".
final class StateMergeTests: XCTestCase {

    private func learner(xp: Int = 0) -> PersistedState {
        var s = PersistedState()
        s.nativeLanguage = .it
        s.onboarded = true
        s.xp = xp
        return s
    }

    func testTheHigherScoreAlwaysWins() {
        var local = learner(xp: 300)
        var remote = learner(xp: 120)
        local.streak = 3
        remote.streak = 9
        remote.gems = 400

        let merged = local.merged(with: remote)
        XCTAssertEqual(merged.xp, 300)
        XCTAssertEqual(merged.streak, 9, "a streak kept on the other phone is still a streak")
        XCTAssertEqual(merged.gems, 400)
    }

    func testALessonFinishedOnlyOnTheOtherPhoneSurvives() {
        var local = learner()
        var remote = learner()
        local.records["a1u1l1"] = LessonRecord(completions: 5, bestAccuracy: 0.8, crowns: 3)
        remote.records["a1u1l2"] = LessonRecord(completions: 2, bestAccuracy: 1.0, crowns: 1)

        let merged = local.merged(with: remote)
        XCTAssertEqual(merged.records.count, 2)
        XCTAssertEqual(merged.records["a1u1l2"]?.completions, 2)
    }

    func testTheSameLessonKeepsTheBetterRun() {
        var local = learner()
        var remote = learner()
        local.records["a1u1l1"] = LessonRecord(completions: 5, bestAccuracy: 0.6, crowns: 2)
        remote.records["a1u1l1"] = LessonRecord(completions: 3, bestAccuracy: 0.95, crowns: 3)

        let merged = local.merged(with: remote)
        let r = merged.records["a1u1l1"]
        XCTAssertEqual(r?.completions, 5)
        XCTAssertEqual(r?.bestAccuracy ?? 0, 0.95, accuracy: 0.001)
        XCTAssertEqual(r?.crowns, 3)
    }

    func testAWordPractisedMoreOnTheOtherPhoneKeepsThatMemory() {
        var local = learner()
        var remote = learner()
        local.srs["ciao|salom"] = SRSItem(pairID: "ciao|salom", strength: 0.2, reps: 1)
        remote.srs["ciao|salom"] = SRSItem(pairID: "ciao|salom", strength: 0.9, reps: 6)

        let merged = local.merged(with: remote)
        XCTAssertEqual(merged.srs["ciao|salom"]?.reps, 6)
        XCTAssertEqual(merged.srs["ciao|salom"]?.strength ?? 0, 0.9, accuracy: 0.001)
    }

    func testUnlockedLevelsAreTheUnionOfBoth() {
        var local = learner()
        var remote = learner()
        local.unlockedLevels = ["a1", "a2"]
        remote.unlockedLevels = ["a1", "b1"]

        XCTAssertEqual(local.merged(with: remote).unlockedLevels, ["a1", "a2", "b1"])
    }

    func testTwoDaysOfHistoryBecomeOne() {
        var local = learner()
        var remote = learner()
        local.history = [DaySnapshot(day: "2026-01-02", xp: 50, minutes: 10)]
        remote.history = [DaySnapshot(day: "2026-01-02", xp: 70, minutes: 8),
                          DaySnapshot(day: "2026-01-01", xp: 30, minutes: 5)]

        let merged = local.merged(with: remote)
        XCTAssertEqual(merged.history.count, 2)
        let second = merged.history.first { $0.day == "2026-01-02" }
        XCTAssertEqual(second?.xp, 70)
        XCTAssertEqual(second?.minutes, 10, "neither figure is thrown away")
    }

    func testThisPhoneKeepsItsOwnSettingsAndItsOwnHold() {
        var local = learner()
        var remote = learner()
        local.settings.sounds = false
        local.skillSnoozes["speaking"] = Date().addingTimeInterval(600)
        remote.settings.sounds = true
        remote.skillSnoozes = [:]

        let merged = local.merged(with: remote)
        XCTAssertFalse(merged.settings.sounds)
        XCTAssertNotNil(merged.skillSnoozes["speaking"],
                        "a hold set here a minute ago is not undone by a sync")
    }

    func testMergingIsSafeWhenTheServerHasNothing() {
        var local = learner(xp: 250)
        local.records["a1u1l1"] = LessonRecord(completions: 4)
        let merged = local.merged(with: PersistedState())
        XCTAssertEqual(merged.xp, 250)
        XCTAssertEqual(merged.records.count, 1)
        XCTAssertEqual(merged.nativeLanguage, .it)
    }

    // MARK: - What leaves the phone

    func testTheAPIKeyNeverTravels() {
        var local = learner()
        local.settings.aiKey = "AIzaSy-super-secret"
        local.settings.aiProvider = .gemini
        local.skillSnoozes["listening"] = Date().addingTimeInterval(900)

        let leaving = local.uploadable
        XCTAssertTrue(leaving.settings.aiKey.isEmpty)
        XCTAssertEqual(leaving.settings.aiProvider, .none)
        XCTAssertTrue(leaving.skillSnoozes.isEmpty)
        XCTAssertEqual(local.settings.aiKey, "AIzaSy-super-secret", "the phone keeps its own copy")
    }

    func testItSurvivesTheRoundTripDownTheWire() throws {
        var local = learner(xp: 4321)
        local.streak = 12
        local.records["a1u1l1"] = LessonRecord(completions: 5, bestAccuracy: 0.9, crowns: 3)
        local.srs["ciao|salom"] = SRSItem(pairID: "ciao|salom", strength: 0.7, reps: 4)

        let packed = try local.packed()
        let back = try PersistedState.unpacked(packed)
        XCTAssertEqual(back.xp, 4321)
        XCTAssertEqual(back.streak, 12)
        XCTAssertEqual(back.records["a1u1l1"]?.crowns, 3)
        XCTAssertEqual(back.srs["ciao|salom"]?.reps, 4)
    }

    func testPackingIsWorthDoing() throws {
        var big = learner()
        for i in 0..<2000 {
            big.srs["word\(i)|so'z\(i)"] = SRSItem(pairID: "word\(i)|so'z\(i)", strength: 0.5, reps: 3)
        }
        let plain = try JSONEncoder().encode(big)
        let packed = try big.packed()
        XCTAssertLessThan(packed.count, plain.count / 2)
        XCTAssertLessThan(packed.count, 1_000_000, "a Firestore document is capped at 1 MB")
    }

    func testPlainJSONStillLoads() throws {
        // a document written before compression, or by a build that could not zip
        let plain = try JSONEncoder().encode(learner(xp: 77))
        XCTAssertEqual(try PersistedState.unpacked(plain).xp, 77)
    }
}

// MARK: - The writing chapter

final class WritingChapterTests: XCTestCase {

    private let curriculum = ContentStore.loadCurriculum()

    func testEveryUnitHasExactlyOne() {
        for pack in curriculum.levels {
            for unit in pack.units {
                let writing = unit.nodes(level: pack.level, index: 0).filter(\.isWriting)
                XCTAssertEqual(writing.count, 1, "\(unit.id) should have one writing chapter")
                XCTAssertEqual(writing.first?.id, "\(unit.id)-writing")
            }
        }
    }

    func testTheyAreSpreadRightAcrossTheCourse() {
        let all = curriculum.levels.flatMap { pack in
            pack.units.flatMap { $0.nodes(level: pack.level, index: 0) }
        }
        let writing = all.filter(\.isWriting)
        XCTAssertEqual(writing.count, curriculum.allUnits.count)
        for level in CEFR.allCases {
            XCTAssertGreaterThan(writing.filter { $0.level == level }.count, 0,
                                 "\(level.label) has no writing chapter")
        }
    }

    func testItIsOneSittingAndItAsksForWriting() {
        guard let unit = curriculum.allUnits.first,
              let node = unit.nodes(level: .a1, index: 0).first(where: \.isWriting) else {
            return XCTFail("no writing node")
        }
        XCTAssertEqual(node.requiredSessions, 1)
        XCTAssertEqual(node.focus(forSession: 0), .writing)
        XCTAssertGreaterThan(node.xpReward, 0)
    }

    func testTheSubjectOfAChapterNeverMoves() {
        guard let unit = curriculum.allUnits.first else { return XCTFail() }
        let first = WritingPlanner.chapter(for: unit, level: .a1)
        let again = WritingPlanner.chapter(for: unit, level: .a1)
        XCTAssertEqual(first.theme.id, again.theme.id)
    }

    func testDifferentUnitsGetDifferentSubjects() {
        let units = Array(curriculum.allUnits.prefix(8))
        let themes = Set(units.map { WritingPlanner.chapter(for: $0, level: .a1).theme.id })
        XCTAssertGreaterThan(themes.count, 3, "eight chapters should not all be the same subject")
    }

    func testWhatIsAskedGrowsWithTheLevel() {
        XCTAssertLessThan(WritingChapter.wordFloor(for: .a1), WritingChapter.wordFloor(for: .b2))
        XCTAssertLessThanOrEqual(WritingChapter.turnCount(for: .a1), WritingChapter.turnCount(for: .b2))
    }

    func testAChapterBuildsNoExercises() {
        guard let unit = curriculum.allUnits.first,
              let node = unit.nodes(level: .a1, index: 0).first(where: \.isWriting) else {
            return XCTFail("no writing node")
        }
        let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                              native: .it, settings: Settings())
        XCTAssertTrue(session.isEmpty)
    }

    func testTheBriefingCarriesTheChaptersOwnWords() {
        guard let unit = curriculum.allUnits.first else { return XCTFail() }
        let chapter = WritingPlanner.chapter(for: unit, level: .a1)
        let briefing = chapter.briefing(native: .it)
        XCTAssertTrue(briefing.contains("A1"))
        XCTAssertTrue(briefing.contains(unit.title.it))
        if let word = unit.allPairs.first?.uz {
            XCTAssertTrue(briefing.contains(word) || briefing.count > 200,
                          "the vocabulary should be in the briefing")
        }
    }

    // MARK: - The chat itself, with no assistant behind it

    @MainActor
    func testItRunsRightThroughOffline() async {
        guard let unit = curriculum.allUnits.first else { return XCTFail() }
        let chapter = WritingPlanner.chapter(for: unit, level: .a1)
        let engine = ChatEngine(chapter: chapter, native: .it)

        await engine.begin(provider: .none, apiKey: "")
        XCTAssertEqual(engine.messages.count, 1)
        XCTAssertEqual(engine.phase, .yourTurn)
        XCTAssertFalse(engine.canSend, "an empty box is not a message")

        for _ in 0..<chapter.turns {
            engine.draft = "men bugun juda yaxshi ishladim va charchadim"
            XCTAssertTrue(engine.canSend)
            await engine.send(provider: .none, apiKey: "")
        }
        XCTAssertEqual(engine.written, chapter.turns)
        XCTAssertEqual(engine.phase, .reviewing)
        XCTAssertEqual(engine.records.count, chapter.turns)
    }

    @MainActor
    func testATooShortReplyCannotBeSent() async {
        guard let unit = curriculum.allUnits.first else { return XCTFail() }
        let chapter = WritingPlanner.chapter(for: unit, level: .b2)
        let engine = ChatEngine(chapter: chapter, native: .it)
        await engine.begin(provider: .none, apiKey: "")

        engine.draft = "sì"
        XCTAssertFalse(engine.canSend)
        engine.draft = Array(repeating: "parola", count: chapter.minimumWords).joined(separator: " ")
        XCTAssertTrue(engine.canSend)
    }

    @MainActor
    func testAnorchaNeverRepeatsHerselfBackToBackOffline() async {
        guard let unit = curriculum.allUnits.first else { return XCTFail() }
        let chapter = WritingPlanner.chapter(for: unit, level: .a1)
        let engine = ChatEngine(chapter: chapter, native: .it)
        await engine.begin(provider: .none, apiKey: "")

        for _ in 0..<(chapter.turns - 1) {
            engine.draft = "bugun havo juda yaxshi edi"
            await engine.send(provider: .none, apiKey: "")
        }
        let hers = engine.messages.filter { $0.who == .anorcha }.map(\.text)
        XCTAssertEqual(Set(hers).count, hers.count, "the offline script should not stutter")
    }

    @MainActor
    func testLeavingEarlyStillCountsWhatWasWritten() async {
        guard let unit = curriculum.allUnits.first else { return XCTFail() }
        let chapter = WritingPlanner.chapter(for: unit, level: .a1)
        let engine = ChatEngine(chapter: chapter, native: .it)
        await engine.begin(provider: .none, apiKey: "")
        engine.draft = "men bugun charchadim lekin xursandman"
        await engine.send(provider: .none, apiKey: "")

        engine.finishEarly()
        XCTAssertEqual(engine.phase, .reviewing)

        await engine.buildReview(curriculum: curriculum, provider: .none, apiKey: "")
        XCTAssertEqual(engine.phase, .done)
        XCTAssertNotNil(engine.review)
        XCTAssertGreaterThan(engine.xpEarned, 0)
    }

    @MainActor
    func testWalkingAwayWithoutWritingAnythingIsNotACompletion() async {
        guard let unit = curriculum.allUnits.first else { return XCTFail() }
        let engine = ChatEngine(chapter: WritingPlanner.chapter(for: unit, level: .a1), native: .it)
        await engine.begin(provider: .none, apiKey: "")
        engine.finishEarly()
        XCTAssertEqual(engine.phase, .done)
        XCTAssertNil(engine.review)
        XCTAssertTrue(engine.records.isEmpty)
    }
}

// MARK: - Sentences written for a chapter

final class PhraseForgeTests: XCTestCase {

    func testABlendKeepsBothSides() {
        let taught = (0..<10).map { Pair(it: "vecchio \($0)", uz: "eski \($0)") }
        let fresh = (0..<10).map { Pair(it: "nuovo \($0)", uz: "yangi \($0)") }
        let mixed = ExerciseFactory.blend(taught: taught, fresh: fresh, want: 12)

        XCTAssertEqual(mixed.count, 12)
        XCTAssertTrue(mixed.contains { $0.it.hasPrefix("vecchio") }, "the chapter is still taught")
        XCTAssertTrue(mixed.contains { $0.it.hasPrefix("nuovo") }, "and something is new")
    }

    func testWithNothingNewTheLessonIsExactlyWhatItAlwaysWas() {
        let taught = (0..<10).map { Pair(it: "a\($0)", uz: "b\($0)") }
        XCTAssertEqual(ExerciseFactory.blend(taught: taught, fresh: [], want: 12), taught)
    }

    func testTheFirstPassOverANodeIsNeverGenerated() {
        let curriculum = ContentStore.loadCurriculum()
        guard let unit = curriculum.allUnits.first,
              let node = unit.nodes(level: .a1, index: 0).first else { return XCTFail() }
        let invented = [Pair(it: "frase inventata dal modello", uz: "model o'ylab topgan jumla")]

        let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                              native: .it, settings: Settings(),
                                              focus: .discover, fresh: invented)
        XCTAssertFalse(session.contains { $0.pair.it == invented[0].it },
                       "new words are met in the course's own sentences, not invented ones")
    }

    func testALaterPassDoesUseThem() {
        let curriculum = ContentStore.loadCurriculum()
        guard let unit = curriculum.allUnits.first,
              let node = unit.nodes(level: .a1, index: 0).first else { return XCTFail() }
        let invented = (0..<20).map { Pair(it: "frase nuova numero \($0)",
                                           uz: "yangi jumla raqam \($0)") }

        var seen = false
        for _ in 0..<5 where !seen {
            let session = ExerciseFactory.session(for: node, unit: unit, curriculum: curriculum,
                                                  native: .it, settings: Settings(),
                                                  focus: .review, fresh: invented)
            seen = session.contains { $0.pair.it.hasPrefix("frase nuova") }
        }
        XCTAssertTrue(seen, "the review pass should be drawing on new material")
    }

    func testTheLengthAllowedGrowsWithTheLevel() {
        let a1 = AIClient.lengthBand(for: .a1)
        let b2 = AIClient.lengthBand(for: .b2)
        XCTAssertLessThan(a1.max, b2.max)
        XCTAssertLessThanOrEqual(a1.min, b2.min)
        XCTAssertLessThan(a1.min, a1.max)
    }

    func testAChapterWithNoKeyAsksForNothing() async {
        let brief = PhraseForge.Brief(lessonID: "test-lesson", level: .a1,
                                      unitTitle: "Saluti", lessonTitle: "Ciao",
                                      grammar: [], vocabulary: [Pair(it: "ciao", uz: "salom")],
                                      native: .it, provider: .none, key: "")
        XCTAssertFalse(brief.isPossible)
        let back = await PhraseForge.shared.replenish(brief)
        XCTAssertTrue(back.isEmpty)
    }

    func testAChapterWithNoWordsAsksForNothingEither() {
        let brief = PhraseForge.Brief(lessonID: "empty", level: .a1,
                                      unitTitle: "", lessonTitle: "",
                                      grammar: [], vocabulary: [],
                                      native: .it, provider: .gemini, key: "AIzaSyFake")
        XCTAssertFalse(brief.isPossible)
    }
}

// MARK: - I due pulsanti che non passano per una password

/// Apple e Google sono due strade diverse verso la stessa sessione, e quel che le
/// rompe non è quasi mai il codice che si vede nel foglio: è una stringa composta
/// male, o un errore letto per un altro. Queste sono le parti che si possono
/// guardare senza aprire una finestra di sistema.
final class SignInTests: XCTestCase {

    /// Il redirect di Google è il client id letto all'incontrario. Se questa riga
    /// sbaglia, il browser si apre, l'utente accede davvero, e poi non torna più:
    /// nessun errore, nessun log, solo un foglio che resta lì.
    func testTheGoogleRedirectSchemeIsTheClientIDBackwards() {
        let id = "1234567890-abcdefg.apps.googleusercontent.com"
        XCTAssertEqual(SocialSignIn.redirectScheme(for: id),
                       "com.googleusercontent.apps.1234567890-abcdefg")
    }

    /// La stessa cosa deve valere due volte di seguito, altrimenti il redirect che
    /// l'app ascolta e quello che Google richiama non sono lo stesso.
    func testTheSchemeSurvivesBeingReversedTwice() {
        let id = "1234567890-abcdefg.apps.googleusercontent.com"
        let back = SocialSignIn.redirectScheme(for: SocialSignIn.redirectScheme(for: id))
        XCTAssertEqual(back, id)
    }

    func testSpacesPastedAroundTheClientIDDoNotEndUpInTheScheme() {
        let scheme = SocialSignIn.redirectScheme(for: "  1-a.apps.googleusercontent.com\n")
        XCTAssertEqual(scheme, "com.googleusercontent.apps.1-a")
        XCTAssertFalse(scheme.contains(" "))
    }

    /// Senza client id il pulsante non compare: è `AccountForm` a chiederlo, e la
    /// risposta deve seguire `Secrets`, non un valore scritto a parte.
    func testGoogleIsOfferedOnlyWhenItHasAClientID() {
        XCTAssertEqual(SocialSignIn.isGoogleConfigured, !SocialSignIn.googleClientID.isEmpty)
        XCTAssertEqual(SocialSignIn.googleClientID,
                       Secrets.googleOAuthClientID.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// I due provider viaggiano nel `postBody` di `signInWithIdp`: sono gli stessi
    /// nomi che Firebase usa nella console, e non possono essere abbreviati.
    func testTheProviderNamesAreTheOnesFirebaseKnows() {
        XCTAssertEqual(FirebaseClient.Federated.apple.rawValue, "apple.com")
        XCTAssertEqual(FirebaseClient.Federated.google.rawValue, "google.com")
    }

    /// Annullare non è fallire: chi chiude il foglio non deve vedere un errore
    /// rosso, e il messaggio di "annullato" non deve somigliare a un guasto.
    func testCancellingSaysSomethingCalmInBothLanguages() {
        let cancelled = SocialSignIn.Failure.cancelled.message
        XCTAssertFalse(cancelled.it.isEmpty)
        XCTAssertFalse(cancelled.uz.isEmpty)
        XCTAssertNotEqual(cancelled.it, cancelled.uz)
    }

    /// Il codice che Apple restituisce va mostrato: e' l'unica cosa che distingue
    /// un dispositivo senza ID Apple da un'app firmata senza la capability, e
    /// sceglierne una a caso manda a cercare nel posto sbagliato.
    func testTheAppleErrorCarriesItsCode() {
        let message = SocialSignIn.Failure.apple(1000).message
        XCTAssertTrue(message.it.contains("1000"))
        XCTAssertTrue(message.uz.contains("1000"))
        XCTAssertFalse(message.it.lowercased().contains("nessun id apple"),
                       "non e' l'unica causa, e affermarla sarebbe una bugia")
    }

    /// "Non abilitato" senza dire cosa manda a cercare nel posto sbagliato.
    func testAProviderThatIsOffNamesItself() {
        let off = FirebaseClient.Failure.auth("OPERATION_NOT_ALLOWED").message
        XCTAssertFalse(off.it.contains("Email e password"),
                       "il codice arriva uguale per tutti e tre i pulsanti")
        XCTAssertFalse(off.it.isEmpty)
    }

    /// Un nonce mancante e una risposta che il server non accetta sono due cose
    /// diverse, e prima finivano tutte e due nel messaggio generico col codice.
    func testTheIdentityErrorsApplePeopleActuallyHitAreSpelledOut() {
        for code in ["MISSING_OR_INVALID_NONCE", "INVALID_IDP_RESPONSE",
                     "FEDERATED_USER_ID_ALREADY_LINKED"] {
            let message = FirebaseClient.Failure.auth(code).message
            XCTAssertFalse(message.it.contains(code),
                           "\(code) non è ancora tradotto in una frase")
        }
    }

    /// Senza le due stringhe di `Secrets` ogni chiamata deve fermarsi prima di
    /// partire: un URL con `key=` vuoto torna 400 con un codice che non dice niente.
    func testNothingIsSentWhenTheProjectIsNotConfiguredYet() async {
        guard !FirebaseClient.isConfigured else { return }   // build già configurata
        do {
            _ = try await FirebaseClient.signIn(idToken: "x", provider: .google)
            XCTFail("avrebbe dovuto fermarsi prima della rete")
        } catch FirebaseClient.Failure.notConfigured {
            // giusto così
        } catch {
            XCTFail("errore sbagliato: \(error)")
        }
    }
}
