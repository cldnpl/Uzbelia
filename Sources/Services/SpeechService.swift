import Foundation
import AVFoundation
import Observation

/// Text-to-speech for both course languages.
///
/// iOS ships Italian voices out of the box. It does **not** ship an Uzbek voice,
/// so we fall back to the closest available Turkic voice (Turkish, then Azeri)
/// which reads Latin-script Uzbek with a recognisable, usable pronunciation.
/// `usesApproximateVoice(for:)` lets the UI say so honestly.
@Observable
final class SpeechService: NSObject {
    static let shared = SpeechService()

    private let synth = AVSpeechSynthesizer()
    private(set) var isSpeaking = false
    private(set) var speakingID: String?

    override init() {
        super.init()
        synth.delegate = self
    }

    // MARK: - Voice resolution

    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    func voice(for language: Language) -> AVSpeechSynthesisVoice? {
        if let cached = voiceCache[language.rawValue] { return cached }
        let all = AVSpeechSynthesisVoice.speechVoices()
        for code in language.speechFallbacks {
            let prefix = String(code.prefix(2))
            let matching = all.filter { $0.language.lowercased().hasPrefix(prefix) }
            if let best = matching.sorted(by: { rank($0) > rank($1) }).first {
                voiceCache[language.rawValue] = best
                return best
            }
        }
        return AVSpeechSynthesisVoice(language: language.speechLocale)
    }

    private func rank(_ v: AVSpeechSynthesisVoice) -> Int {
        switch v.quality {
        case .premium: return 3
        case .enhanced: return 2
        default: return 1
        }
    }

    /// True when we are reading the language with a stand-in voice.
    func usesApproximateVoice(for language: Language) -> Bool {
        guard let v = voice(for: language) else { return true }
        return !v.language.lowercased().hasPrefix(String(language.rawValue.prefix(2)))
    }

    func voiceDescription(for language: Language) -> String {
        guard let v = voice(for: language) else { return "—" }
        return "\(v.name) (\(v.language))"
    }

    // MARK: - Speaking

    func speak(_ text: String, language: Language, rate: Double = 0.44, slow: Bool = false, id: String? = nil) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        stop()
        configureSessionForPlayback()
        let u = AVSpeechUtterance(string: cleanForSpeech(text))
        u.voice = voice(for: language)
        u.rate = Float(slow ? max(0.22, rate * 0.6) : rate)
        u.pitchMultiplier = 1.03
        u.postUtteranceDelay = 0.05
        u.preUtteranceDelay = 0
        speakingID = id
        isSpeaking = true
        synth.speak(u)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
        speakingID = nil
    }

    private func cleanForSpeech(_ s: String) -> String {
        s.replacingOccurrences(of: "____", with: "…")
         .replacingOccurrences(of: "  ", with: " ")
    }

    private func configureSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false; speakingID = nil
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false; speakingID = nil
    }
}
