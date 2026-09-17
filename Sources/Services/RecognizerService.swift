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
    /// True between the tap on stop and the transcript coming back from Azure.
    private(set) var isTranscribing = false

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    /// 16 kHz mono samples collected for whoever is going to transcribe them.
    private var recorded = Data()
    private var converter: AVAudioConverter?
    private var listeningRemotely = false
    private var remoteLanguage: Language = .uz

    /// True while the words on screen are a running guess rather than the final read.
    private(set) var isPartial = false
    /// Guards against two passes over the same audio at once — the model takes about
    /// a second, and a second pass queued behind it would only ever show stale words.
    private var partialRunning = false
    private var lastPartialAt: Date = .distantPast

    // MARK: - Availability

    func resolvedLocale(for language: Language) -> String? {
        let supported = SFSpeechRecognizer.supportedLocales().map { $0.identifier.replacingOccurrences(of: "_", with: "-") }
        for code in language.speechFallbacks {
            if let hit = supported.first(where: { $0.lowercased() == code.lowercased() }) { return hit }
            if let hit = supported.first(where: { $0.lowercased().hasPrefix(String(code.prefix(2)).lowercased()) }) { return hit }
        }
        return nil
    }

    /// True when the language is heard by a recogniser that actually knows it.
    func isExact(for language: Language) -> Bool {
        if usesRemote(for: language) { return true }
        guard let r = resolvedLocale(for: language) else { return false }
        return r.lowercased().hasPrefix(language.rawValue)
    }

    func isAvailable(for language: Language) -> Bool {
        usesRemote(for: language) || resolvedLocale(for: language) != nil
    }

    /// Apple has no Uzbek recogniser at all. The phone's own Whisper model is the
    /// best answer when it is there; failing that a key — Azure's, or the Gemini one
    /// the video calls already use — has somebody else do the listening.
    func usesRemote(for language: Language) -> Bool {
        language == .uz && (UzbekRecognizer.isAvailable
                            || AzureSpeech.isConfigured
                            || Secrets.builtIn?.provider == .gemini)
    }

    /// True when Uzbek is heard by the phone itself, with no network at all.
    func usesOnDevice(for language: Language) -> Bool {
        language == .uz && UzbekRecognizer.isAvailable
    }

    /// Kept for the places that ask specifically about Azure.
    func usesAzure(for language: Language) -> Bool {
        language == .uz && AzureSpeech.isConfigured
    }

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
        stop()
        transcript = ""
        recorded = Data()
        listeningRemotely = usesRemote(for: language)
        remoteLanguage = language

        var appleRecognizer: SFSpeechRecognizer?
        if !listeningRemotely {
            guard let code = resolvedLocale(for: language),
                  let rec = SFSpeechRecognizer(locale: Locale(identifier: code)), rec.isAvailable else {
                status = .unavailable; return
            }
            appleRecognizer = rec
            recognizer = rec
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { status = .unavailable; return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        if listeningRemotely {
            // a remote recogniser wants one 16 kHz mono WAV at the end, not a stream
            converter = Self.converter(from: format)
        } else if let rec = appleRecognizer {
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if rec.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            request = req
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            if self.listeningRemotely { self.collect(buffer) } else { self.request?.append(buffer) }
            self.updateLevel(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch { status = .unavailable; return }
        status = .listening

        if let rec = appleRecognizer, let req = request {
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
    }

    // MARK: - Recording for Azure

    private static func converter(from format: AVAudioFormat) -> AVAudioConverter? {
        guard let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
                                         channels: 1, interleaved: true) else { return nil }
        return AVAudioConverter(from: format, to: target)
    }

    private func collect(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 512
        guard let out = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else { return }

        var supplied = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, outStatus in
            if supplied { outStatus.pointee = .noDataNow; return nil }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0, let channel = out.int16ChannelData?[0] else { return }
        recorded.append(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
        // 60 seconds is the ceiling for a single request; an exercise is seconds long
        if recorded.count > 16_000 * 2 * 55 { engine.pause() }
        runPartialIfDue()
    }

    /// Reads back what has been said so far, every second or so, so the words appear
    /// as she speaks instead of all at once when she stops.
    ///
    /// Only the model on the phone can do this: sending a second of audio to a server
    /// every second would be both slow and rude to her data plan.
    private func runPartialIfDue() {
        guard UzbekRecognizer.isAvailable, remoteLanguage == .uz,
              !partialRunning, status == .listening else { return }
        guard recorded.count > 16_000 * 2 / 2 else { return }          // at least half a second
        guard Date().timeIntervalSince(lastPartialAt) > 0.9 else { return }

        partialRunning = true
        lastPartialAt = .now
        let soFar = recorded
        Task { [weak self] in
            let heard = try? await UzbekRecognizer.shared.transcribe(
                samples: UzbekRecognizer.floats(fromPCM16: soFar), quick: true)
            await MainActor.run {
                guard let self, self.status == .listening else {
                    self?.partialRunning = false
                    return
                }
                if let heard, !heard.isEmpty {
                    self.transcript = heard
                    self.isPartial = true
                }
                self.partialRunning = false
            }
        }
    }

    /// Minimal 16-bit PCM WAV header around the samples.
    private static func wav(_ samples: Data, sampleRate: Int = 16_000) -> Data {
        var out = Data()
        func ascii(_ s: String) { out.append(contentsOf: Array(s.utf8)) }
        func u32(_ v: Int) { out.append(contentsOf: withUnsafeBytes(of: UInt32(v).littleEndian, Array.init)) }
        func u16(_ v: Int) { out.append(contentsOf: withUnsafeBytes(of: UInt16(v).littleEndian, Array.init)) }
        ascii("RIFF"); u32(36 + samples.count); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(1)
        u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
        ascii("data"); u32(samples.count)
        out.append(samples)
        return out
    }

    /// Stops recording and, when someone else is listening, waits for the transcript.
    /// Returns only once `transcript` is final, so the exercise can score it.
    func stopAndTranscribe() async {
        guard listeningRemotely else {
            stop()
            // the on-device recogniser often delivers its last words just after the tap
            try? await Task.sleep(for: .milliseconds(600))
            return
        }
        let samples = recorded
        stop()
        guard samples.count > 16_000 / 4 else { status = .finished; return }   // under 0.25s: silence
        isTranscribing = true
        defer { isTranscribing = false; isPartial = false; status = .finished }
        let audio = Self.wav(samples)

        // The model on the phone first: it was trained on Uzbek, it needs no network
        // and no key, and it is the only one of the three that is actually a Uzbek
        // recogniser rather than something standing in for one.
        if UzbekRecognizer.isAvailable, remoteLanguage == .uz {
            let floats = UzbekRecognizer.floats(fromPCM16: samples)
            if let heard = try? await UzbekRecognizer.shared.transcribe(samples: floats),
               !heard.isEmpty {
                transcript = heard
                return
            }
        }
        if AzureSpeech.isConfigured,
           let heard = try? await AzureSpeech.transcribe(wav: audio, locale: remoteLanguage.recognitionLocale) {
            transcript = heard
            return
        }
        if let built = Secrets.builtIn, built.provider == .gemini,
           let heard = try? await AIClient.transcribe(wav: audio, language: remoteLanguage,
                                                      provider: built.provider, key: built.key) {
            transcript = heard
            return
        }
        transcript = ""
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
        converter = nil
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
        recorded = Data()
        listeningRemotely = false
        isTranscribing = false
        isPartial = false
        partialRunning = false
        lastPartialAt = .distantPast
        status = .idle
    }
}
