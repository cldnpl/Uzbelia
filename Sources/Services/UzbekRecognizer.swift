import Foundation

#if canImport(whisper)
import whisper
#endif

/// Uzbek speech recognition that runs on the phone.
///
/// Apple has no Uzbek recogniser and falls back to Turkish, which is why saying
/// `xayrli kech` came back as `Selam gece`. This runs `navai-uz/whisper-small-uzbek`
/// — a Whisper small fine-tuned on Common Voice, FLEURS and FeruzaSpeech — through
/// whisper.cpp, on the device: no key, no account, no network, and actually Uzbek.
///
/// The model file is large, so it is not in the repository. When it is missing
/// everything here reports itself unavailable and the app falls back exactly as
/// before — Azure if configured, then Gemini, then Apple's Turkish approximation.
actor UzbekRecognizer {
    static let shared = UzbekRecognizer()

    /// The quantised model, bundled with the app when it has been built.
    nonisolated static var modelURL: URL? {
        Bundle.main.url(forResource: "ggml-uzbek-small", withExtension: "bin")
    }

    /// Whether the phone can hear Uzbek by itself.
    nonisolated static var isAvailable: Bool {
        #if canImport(whisper)
        return modelURL != nil
        #else
        return false
        #endif
    }

    enum Failure: LocalizedError {
        case unavailable
        case couldNotLoad
        case failed

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Il modello uzbeko non è incluso in questa build."
            case .couldNotLoad: return "Il modello uzbeko non si è caricato."
            case .failed: return "La trascrizione non è riuscita."
            }
        }
    }

    #if canImport(whisper)
    private var context: OpaquePointer?

    /// Loads the model once and keeps it: it takes a moment and several hundred
    /// megabytes, and a lesson asks for it many times in a row.
    private func loaded() throws -> OpaquePointer {
        if let context { return context }
        guard let url = Self.modelURL else { throw Failure.unavailable }
        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = true
        guard let fresh = whisper_init_from_file_with_params(url.path(percentEncoded: false), params) else {
            throw Failure.couldNotLoad
        }
        context = fresh
        return fresh
    }

    /// Gives the model back its memory. Called when a lesson ends.
    func unload() {
        if let context { whisper_free(context) }
        context = nil
    }

    /// What was said, as Uzbek. `samples` is mono 16 kHz in -1…1.
    ///
    /// `quick` is for the running read-back while she is still speaking: it trades a
    /// little accuracy for speed, because those words are replaced a second later
    /// anyway. The final pass is always a full one.
    func transcribe(samples: [Float], quick: Bool = false) throws -> String {
        guard samples.count > 16_000 / 8 else { return "" }        // under an eighth of a second
        let ctx = try loaded()

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_timestamps = true
        params.single_segment = false
        params.suppress_blank = true
        params.n_threads = Int32(max(1, min(6, ProcessInfo.processInfo.activeProcessorCount - 2)))
        if quick {
            params.single_segment = true
            params.temperature_inc = 0          // no retries: a late guess is a useless guess
        }

        let ok = "uz".withCString { language -> Bool in
            params.language = language
            return samples.withUnsafeBufferPointer { audio in
                whisper_full(ctx, params, audio.baseAddress, Int32(audio.count)) == 0
            }
        }
        guard ok else { throw Failure.failed }

        var out = ""
        for index in 0..<whisper_full_n_segments(ctx) {
            if let piece = whisper_full_get_segment_text(ctx, index) {
                out += String(cString: piece)
            }
        }
        return Self.tidy(out)
    }
    #else
    func unload() {}
    func transcribe(samples: [Float], quick: Bool = false) throws -> String { throw Failure.unavailable }
    #endif

    /// Whisper likes to open with a space and to punctuate generously; the grader
    /// ignores punctuation anyway, and the learner should see what she said.
    static func tidy(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\u{00A0}", with: " ")
           .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 16-bit samples as the floats whisper wants.
    static func floats(fromPCM16 data: Data) -> [Float] {
        data.withUnsafeBytes { raw -> [Float] in
            let samples = raw.bindMemory(to: Int16.self)
            return samples.map { Float($0) / 32768.0 }
        }
    }
}
