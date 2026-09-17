import Foundation
import Speech
import AVFoundation
import Observation

/// Microphone + on-device speech recognition for the speaking exercises.
///
/// Apple has no Uzbek recogniser; when the exact locale is unavailable we fall
/// back to the nearest Turkic locale so the exercise still gives useful signal,
/// and the UI tells the learner that scoring is approximate.
@Observable
final class RecognizerService: NSObject {
    static let shared = RecognizerService()

    enum Status: Equatable {
        case idle, listening, denied, unavailable, finished
    }

    private(set) var status: Status = .idle
    private(set) var transcript: String = ""
    private(set) var level: Double = 0            // 0...1 mic level, for the waveform

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    // MARK: - Availability

    func resolvedLocale(for language: Language) -> String? {
        let supported = SFSpeechRecognizer.supportedLocales().map { $0.identifier.replacingOccurrences(of: "_", with: "-") }
        for code in language.speechFallbacks {
            if let hit = supported.first(where: { $0.lowercased() == code.lowercased() }) { return hit }
            if let hit = supported.first(where: { $0.lowercased().hasPrefix(String(code.prefix(2)).lowercased()) }) { return hit }
        }
        return nil
    }

    func isExact(for language: Language) -> Bool {
        guard let r = resolvedLocale(for: language) else { return false }
        return r.lowercased().hasPrefix(language.rawValue)
    }

    func isAvailable(for language: Language) -> Bool { resolvedLocale(for: language) != nil }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let speechOK: Bool = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { st in c.resume(returning: st == .authorized) }
        }
        let micOK: Bool = await withCheckedContinuation { c in
            AVAudioApplication.requestRecordPermission { ok in c.resume(returning: ok) }
        }
        if !(speechOK && micOK) { status = .denied }
        return speechOK && micOK
    }

    // MARK: - Recording

    func start(language: Language) async {
        guard await requestPermissions() else { status = .denied; return }
        guard let code = resolvedLocale(for: language),
              let rec = SFSpeechRecognizer(locale: Locale(identifier: code)), rec.isAvailable else {
            status = .unavailable; return
        }
        stop()
        recognizer = rec
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { status = .unavailable; return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if rec.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.updateLevel(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch { status = .unavailable; return }
        status = .listening

        task = rec.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self.finish()
            }
        }
    }

    private func updateLevel(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))
        let scaled = min(1, Double(rms) * 14)
        Task { @MainActor in self.level = self.level * 0.6 + scaled * 0.4 }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finish() {
        stop()
        status = .finished
    }

    func reset() {
        stop()
        transcript = ""
        status = .idle
    }
}
