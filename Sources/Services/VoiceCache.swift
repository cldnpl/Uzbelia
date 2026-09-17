import Foundation
import CryptoKit

/// Audio kept on disk, so a word is fetched once and then belongs to the phone.
///
/// A course repeats itself relentlessly — the same fifty words across five sessions
/// of a chapter — so after a first pass almost nothing leaves the device, the audio
/// starts instantly, and a flaky connection stops mattering.
enum VoiceCache {

    private static let folder: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UzbekVoice", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static func key(_ text: String, voice: AzureSpeech.Voice, percent: Int, source: String) -> String {
        let seed = "\(source)|\(voice.rawValue)|\(percent)|\(text)"
        return SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func audio(_ key: String) -> Data? {
        try? Data(contentsOf: folder.appendingPathComponent("\(key).mp3"))
    }

    static func store(_ data: Data, at key: String) {
        try? data.write(to: folder.appendingPathComponent("\(key).mp3"), options: .atomic)
    }

    /// Both services take the speed as a percentage off the natural pace, while the
    /// app carries it as an AVSpeechUtterance rate where 0.44 is normal.
    static func ratePercent(_ rate: Double, slow: Bool) -> Int {
        let normalised = (rate - 0.44) / 0.44
        let percent = Int((normalised * 60).rounded())
        return max(-50, min(50, slow ? percent - 40 : percent))
    }

    static func escapedForSSML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// How much of the voice is already on the phone, for the settings screen.
    static var size: Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder,
                                                                  includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    static func empty() {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files { try? FileManager.default.removeItem(at: file) }
    }
}

/// Where the Uzbek voice comes from, in order of preference.
enum UzbekVoice {

    /// Azure when a key is configured — it is the supported, contractual route.
    /// Otherwise Edge's read-aloud service, which costs nothing and needs no account.
    static func audio(for text: String, rate: Double, slow: Bool) async throws -> Data {
        if AzureSpeech.isConfigured {
            do {
                return try await AzureSpeech.audio(for: text, voice: Secrets.uzbekVoice,
                                                   rate: rate, slow: slow)
            } catch {
                // a spent quota or a wrong region should not cost her the voice
                return try await EdgeVoice.audio(for: text, voice: Secrets.uzbekVoice,
                                                 rate: rate, slow: slow)
            }
        }
        return try await EdgeVoice.audio(for: text, voice: Secrets.uzbekVoice, rate: rate, slow: slow)
    }

    /// There is always a real Uzbek voice to try: the free one needs nothing at all.
    static var isAvailable: Bool { true }

    static var description: String {
        AzureSpeech.isConfigured ? "\(Secrets.uzbekVoice.rawValue) · Azure"
                                 : "\(Secrets.uzbekVoice.rawValue) · Edge"
    }
}
