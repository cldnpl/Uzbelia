import XCTest
@testable import Uzbelia

/// Uzbek heard by the phone itself.
final class UzbekRecognizerTests: XCTestCase {

    func testTheModelIsShippedWithThisBuild() {
        // it is a build artefact, not a source file: if this fails, run
        // ./scripts/build-uzbek-recognizer.sh
        guard let url = UzbekRecognizer.modelURL else {
            return XCTFail("ggml-uzbek-small.bin is not in the bundle")
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        XCTAssertGreaterThan(size ?? 0, 100_000_000, "a quantised whisper-small is around 180 MB")
        XCTAssertTrue(UzbekRecognizer.isAvailable)
    }

    func testUzbekIsHeardOnTheDeviceAndItalianIsLeftToApple() {
        let recognizer = RecognizerService.shared
        XCTAssertEqual(recognizer.usesOnDevice(for: .uz), UzbekRecognizer.isAvailable)
        XCTAssertFalse(recognizer.usesOnDevice(for: .it), "iOS hears Italian perfectly well")
    }

    func testWithTheModelPresentUzbekNoLongerCountsAsApproximated() {
        guard UzbekRecognizer.isAvailable else { return }
        XCTAssertTrue(RecognizerService.shared.isExact(for: .uz))
        XCTAssertTrue(RecognizerService.shared.usesRemote(for: .uz))
    }

    func testSixteenBitSamplesBecomeTheFloatsWhisperWants() {
        var pcm = Data()
        for sample in [Int16(0), 16384, -16384, 32767, -32768] {
            pcm.append(contentsOf: withUnsafeBytes(of: sample.littleEndian, Array.init))
        }
        let floats = UzbekRecognizer.floats(fromPCM16: pcm)
        XCTAssertEqual(floats.count, 5)
        XCTAssertEqual(floats[0], 0, accuracy: 0.0001)
        XCTAssertEqual(floats[1], 0.5, accuracy: 0.0001)
        XCTAssertEqual(floats[2], -0.5, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(floats[3], 1)
        XCTAssertGreaterThanOrEqual(floats[4], -1)
    }

    func testSilenceIsNotSentThroughTheModel() async throws {
        guard UzbekRecognizer.isAvailable else { return }
        // a hundredth of a second: there is nothing there to transcribe
        let heard = try await UzbekRecognizer.shared.transcribe(samples: [Float](repeating: 0, count: 160))
        XCTAssertEqual(heard, "")
    }

    func testWhisperPaddingAndStrayWhitespaceAreTrimmed() {
        XCTAssertEqual(UzbekRecognizer.tidy("  salom  "), "salom")
        XCTAssertEqual(UzbekRecognizer.tidy("\u{00A0}rahmat"), "rahmat")
        XCTAssertEqual(UzbekRecognizer.tidy(""), "")
    }
}

/// The words appearing as she speaks, rather than all at once when she stops.
final class LiveTranscriptionTests: XCTestCase {

    func testNothingIsProvisionalBeforeSheStarts() {
        let recognizer = RecognizerService.shared
        recognizer.reset()
        XCTAssertFalse(recognizer.isPartial)
        XCTAssertTrue(recognizer.transcript.isEmpty)
        XCTAssertEqual(recognizer.status, .idle)
    }

    func testResettingClearsAProvisionalRead() {
        let recognizer = RecognizerService.shared
        recognizer.reset()
        XCTAssertFalse(recognizer.isPartial)
        XCTAssertFalse(recognizer.isTranscribing)
    }

    func testTheRunningReadIsOnlyPossibleWhereTheModelLives() {
        // it re-reads the audio every second, which is only sane on the device:
        // a second of audio a second, sent to a server, would be neither fast nor kind
        XCTAssertEqual(RecognizerService.shared.usesOnDevice(for: .uz), UzbekRecognizer.isAvailable)
        XCTAssertFalse(RecognizerService.shared.usesOnDevice(for: .it))
    }

    func testAQuickPassAndAFullPassBothReadTheSameSilence() async throws {
        guard UzbekRecognizer.isAvailable else { return }
        let nothing = [Float](repeating: 0, count: 100)
        let quick = try await UzbekRecognizer.shared.transcribe(samples: nothing, quick: true)
        let full = try await UzbekRecognizer.shared.transcribe(samples: nothing)
        XCTAssertEqual(quick, "")
        XCTAssertEqual(full, "")
    }
}
