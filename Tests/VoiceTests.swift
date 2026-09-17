import XCTest
@testable import Uzbelia

/// The Uzbek voice and the Uzbek ears: what they do with a key, and — the case that
/// matters most — what they do without one.
final class UzbekVoiceTests: XCTestCase {

    func testUzbekHasARealVoiceEvenWithNoKeyAtAll() {
        // the free service needs no account, so this holds on a fresh install
        XCTAssertTrue(UzbekVoice.isAvailable)
        XCTAssertTrue(SpeechService.shared.hasRealVoice(for: .uz))
        XCTAssertFalse(SpeechService.shared.usesApproximateVoice(for: .uz))
        XCTAssertFalse(UzbekVoice.description.isEmpty)
    }

    func testWithNoAzureKeyTheFreeServiceIsTheOneNamed() {
        guard !AzureSpeech.isConfigured else { return }     // a key has been pasted in
        XCTAssertNil(AzureSpeech.credentials)
        XCTAssertTrue(UzbekVoice.description.hasSuffix("Edge"))
        // listening is the half that still needs a key
        XCTAssertFalse(RecognizerService.shared.usesAzure(for: .uz))
    }

    func testTheKeyOnlyEverChangesUzbek() {
        // Italian has real iOS voices and a real iOS recogniser: Azure is never asked
        XCTAssertFalse(SpeechService.shared.hasRealVoice(for: .it))
        XCTAssertFalse(RecognizerService.shared.usesAzure(for: .it))
        XCTAssertFalse(SpeechService.shared.usesApproximateVoice(for: .it))
        XCTAssertTrue(RecognizerService.shared.isExact(for: .it))
    }

    func testAPartlyFilledAzureSettingIsNotAKey() {
        // both halves are needed: a key without its region cannot be called
        let key = Secrets.azureSpeechKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = Secrets.azureSpeechRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(AzureSpeech.isConfigured, !key.isEmpty && !region.isEmpty)
    }

    func testTheUzbekVoicesAreTheOnesAzureActuallyPublishes() {
        XCTAssertEqual(AzureSpeech.Voice.madina.rawValue, "uz-UZ-MadinaNeural")
        XCTAssertEqual(AzureSpeech.Voice.sardor.rawValue, "uz-UZ-SardorNeural")
        for voice in AzureSpeech.Voice.allCases {
            XCTAssertTrue(voice.rawValue.hasPrefix("uz-UZ-"))
            XCTAssertFalse(voice.label.it.isEmpty || voice.label.uz.isEmpty)
        }
    }

    func testAskingForAudioWithoutAKeyFailsWithoutTouchingTheNetwork() async {
        guard !AzureSpeech.isConfigured else { return }
        do {
            _ = try await AzureSpeech.audio(for: "salom", rate: 0.44, slow: false)
            XCTFail("should have refused")
        } catch {
            XCTAssertTrue(error is AzureSpeech.Failure)
        }
        do {
            _ = try await AzureSpeech.transcribe(wav: Data([0, 1, 2]))
            XCTFail("should have refused")
        } catch {
            XCTAssertTrue(error is AzureSpeech.Failure)
        }
    }

    func testAzureErrorsComeOutReadable() {
        let refused = (AzureSpeech.Failure.http(401, "") as LocalizedError).errorDescription ?? ""
        XCTAssertTrue(refused.lowercased().contains("chiave"))
        let wrongRegion = (AzureSpeech.Failure.http(404, "") as LocalizedError).errorDescription ?? ""
        XCTAssertTrue(wrongRegion.lowercased().contains("regione"))
        let spent = (AzureSpeech.Failure.http(429, "") as LocalizedError).errorDescription ?? ""
        XCTAssertTrue(spent.lowercased().contains("quota"))
    }

    func testTheVoiceCacheIsCountedAndCanBeEmptied() {
        VoiceCache.empty()
        XCTAssertEqual(VoiceCache.size, 0)
    }

    func testTheCacheTellsTheTwoServicesApartAndTheSpeedsToo() {
        let voice = AzureSpeech.Voice.madina
        let azure = VoiceCache.key("salom", voice: voice, percent: 0, source: "azure")
        let edge = VoiceCache.key("salom", voice: voice, percent: 0, source: "edge")
        let slower = VoiceCache.key("salom", voice: voice, percent: -40, source: "edge")
        let other = VoiceCache.key("salom", voice: .sardor, percent: 0, source: "edge")
        XCTAssertEqual(Set([azure, edge, slower, other]).count, 4)
        XCTAssertEqual(edge, VoiceCache.key("salom", voice: voice, percent: 0, source: "edge"))
    }

    func testTheSpeedTranslatesIntoAPercentageBothServicesAccept() {
        XCTAssertEqual(VoiceCache.ratePercent(0.44, slow: false), 0)      // normal
        XCTAssertLessThan(VoiceCache.ratePercent(0.44, slow: true), 0)    // the tortoise
        XCTAssertGreaterThan(VoiceCache.ratePercent(0.70, slow: false), 0)
        // never outside what the services allow
        for rate in stride(from: 0.1, through: 1.0, by: 0.05) {
            for slow in [true, false] {
                let p = VoiceCache.ratePercent(rate, slow: slow)
                XCTAssertTrue((-50...50).contains(p), "\(rate) slow=\(slow) gave \(p)%")
            }
        }
    }

    func testTheFreeServiceTokenIsStableForFiveMinutesAndThenChanges() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = EdgeVoice.securityToken(now: now)
        XCTAssertEqual(token.count, 64, "a SHA-256 hex digest")
        XCTAssertEqual(token, token.uppercased())
        XCTAssertEqual(token, EdgeVoice.securityToken(now: now.addingTimeInterval(60)),
                       "it is rounded down to five minutes, so it holds steady")
        XCTAssertNotEqual(token, EdgeVoice.securityToken(now: now.addingTimeInterval(600)))
    }

    func testTheStandInVoiceIsStillThereAsAFallback() {
        // whatever happens to the network, Uzbek is still readable with a Turkic voice
        XCTAssertNotNil(SpeechService.shared.voice(for: .uz))
        XCTAssertFalse(SpeechService.shared.voiceDescription(for: .uz).isEmpty)
    }
}
