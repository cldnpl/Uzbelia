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

    /// Plays the Uzbek voice fetched from Azure, when there is one.
    private var player: AVAudioPlayer?
    /// Bumped on every `speak` and `stop`, so a download that finishes late is dropped
    /// instead of talking over whatever is on screen by then.
    private var generation = 0

    override init() {
        super.init()
        synth.delegate = self
    }

    /// True when a real voice for this language is available over the network.
    /// Uzbek always has one now: the free service needs no key at all.
    func hasRealVoice(for language: Language) -> Bool {
        language == .uz && UzbekVoice.isAvailable
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
        if hasRealVoice(for: language) { return false }
        guard let v = voice(for: language) else { return true }
        return !v.language.lowercased().hasPrefix(String(language.rawValue.prefix(2)))
    }

    func voiceDescription(for language: Language) -> String {
        if hasRealVoice(for: language) { return UzbekVoice.description }
        guard let v = voice(for: language) else { return "—" }
        return "\(v.name) (\(v.language))"
    }

    // MARK: - Speaking

    func speak(_ text: String, language: Language, rate: Double = 0.44, slow: Bool = false, id: String? = nil) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        stop()
        generation += 1
        let mine = generation

        // A real Uzbek voice when one is configured; the cache usually answers at once,
        // and anything that goes wrong quietly becomes the stand-in voice instead.
        if hasRealVoice(for: language) {
            speakingID = id
            isSpeaking = true
            let clean = cleanForSpeech(text)
            Task { @MainActor in
                do {
                    let audio = try await UzbekVoice.audio(for: clean, rate: rate, slow: slow)
                    guard mine == self.generation else { return }
                    try self.play(audio)
                } catch {
                    guard mine == self.generation else { return }
                    self.speakLocally(clean, language: language, rate: rate, slow: slow, id: id)
                }
            }
            return
        }

        speakLocally(cleanForSpeech(text), language: language, rate: rate, slow: slow, id: id)
    }

    private func play(_ audio: Data) throws {
        configureSessionForPlayback()
        let p = try AVAudioPlayer(data: audio)
        p.delegate = self
        player = p
        isSpeaking = true
        p.play()
    }

    private func speakLocally(_ clean: String, language: Language, rate: Double, slow: Bool, id: String?) {
        configureSessionForPlayback()
        let u = AVSpeechUtterance(string: clean)
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
        generation += 1
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        player?.stop()
        player = nil
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

extension SpeechService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isSpeaking = false; speakingID = nil; self.player = nil
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
