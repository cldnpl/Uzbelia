import Foundation
import CryptoKit

/// The Uzbek voice, free and without an account.
///
/// Microsoft Edge has a *Read aloud* feature, and it is served by the same neural
/// voices Azure sells — `uz-UZ-MadinaNeural` and `uz-UZ-SardorNeural` among them.
/// The browser talks to it over a WebSocket with a token anyone can compute, so the
/// app can ask for the same audio with no key, no account and no card.
///
/// Two honest caveats. It is undocumented, so Microsoft could change or close it
/// without warning — which is why nothing here is load-bearing: every failure falls
/// back to the Turkish stand-in voice, exactly as before. And it needs the network,
/// though the cache means a chapter is only fetched once.
enum EdgeVoice {

    private static let endpoint = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1"
    private static let trustedToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    private static let chromium = "143.0.3650.75"

    enum Failure: LocalizedError {
        case noAudio
        case refused(String)

        var errorDescription: String? {
            switch self {
            case .noAudio: return "Il servizio non ha restituito audio."
            case .refused(let why): return "Voce non disponibile: \(why)"
            }
        }
    }

    /// MP3 of `text` read by an Uzbek voice. Answers from the cache when it can.
    static func audio(for text: String,
                      voice: AzureSpeech.Voice,
                      rate: Double,
                      slow: Bool) async throws -> Data {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw Failure.noAudio }

        let percent = VoiceCache.ratePercent(rate, slow: slow)
        let key = VoiceCache.key(clean, voice: voice, percent: percent, source: "edge")
        if let cached = VoiceCache.audio(key) { return cached }

        let data = try await fetch(clean, voice: voice, percent: percent)
        guard data.count > 512 else { throw Failure.noAudio }
        VoiceCache.store(data, at: key)
        return data
    }

    // MARK: - The conversation with the service

    private static func fetch(_ text: String,
                              voice: AzureSpeech.Voice,
                              percent: Int) async throws -> Data {
        var components = URLComponents(string: endpoint)!
        components.queryItems = [
            URLQueryItem(name: "TrustedClientToken", value: trustedToken),
            URLQueryItem(name: "ConnectionId", value: identifier()),
            URLQueryItem(name: "Sec-MS-GEC", value: securityToken()),
            URLQueryItem(name: "Sec-MS-GEC-Version", value: "1-\(chromium)"),
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        let major = chromium.split(separator: ".").first.map(String.init) ?? "143"
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                         + "(KHTML, like Gecko) Chrome/\(major).0.0.0 Safari/537.36 Edg/\(major).0.0.0",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("muid=\(identifier());", forHTTPHeaderField: "Cookie")

        let session = URLSession(configuration: .ephemeral)
        let socket = session.webSocketTask(with: request)
        socket.resume()
        defer { socket.cancel(with: .goingAway, reason: nil) }

        try await socket.send(.string(configMessage()))
        try await socket.send(.string(ssmlMessage(text, voice: voice, percent: percent)))

        var audio = Data()
        // a couple of seconds of speech arrives in a handful of frames; the cap is
        // only there so a service that never says "turn.end" cannot hang the app
        for _ in 0..<600 {
            let message = try await socket.receive()
            switch message {
            case .string(let text):
                if path(ofHeaders: text) == "turn.end" { return audio }
            case .data(let frame):
                if let chunk = audioChunk(frame) { audio.append(chunk) }
            @unknown default:
                break
            }
        }
        return audio
    }

    /// The service answers text frames as `Key:Value\r\n…\r\n\r\nbody`.
    private static func path(ofHeaders text: String) -> String? {
        guard let head = text.components(separatedBy: "\r\n\r\n").first else { return nil }
        for line in head.components(separatedBy: "\r\n") where line.hasPrefix("Path:") {
            return String(line.dropFirst("Path:".count))
        }
        return nil
    }

    /// A binary frame is two big-endian bytes of header length, the headers, then MP3.
    private static func audioChunk(_ frame: Data) -> Data? {
        guard frame.count > 2 else { return nil }
        let headerLength = Int(frame[frame.startIndex]) << 8 | Int(frame[frame.startIndex + 1])
        let start = frame.startIndex + headerLength + 2
        guard headerLength > 0, start < frame.endIndex else { return nil }
        let headers = String(decoding: frame[(frame.startIndex + 2)..<(frame.startIndex + headerLength)],
                             as: UTF8.self)
        guard headers.contains("Path:audio") else { return nil }
        return frame[start...]
    }

    private static func configMessage() -> String {
        """
        X-Timestamp:\(timestamp())\r
        Content-Type:application/json; charset=utf-8\r
        Path:speech.config\r
        \r
        {"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}
        """
    }

    private static func ssmlMessage(_ text: String, voice: AzureSpeech.Voice, percent: Int) -> String {
        let sign = percent >= 0 ? "+" : "-"
        let ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='uz-UZ'>"
                 + "<voice name='\(voice.rawValue)'>"
                 + "<prosody pitch='+0Hz' rate='\(sign)\(abs(percent))%' volume='+0%'>"
                 + VoiceCache.escapedForSSML(text)
                 + "</prosody></voice></speak>"
        return """
        X-RequestId:\(identifier())\r
        Content-Type:application/ssml+xml\r
        X-Timestamp:\(timestamp())Z\r
        Path:ssml\r
        \r
        \(ssml)
        """
    }

    // MARK: - The token the browser computes

    /// SHA-256 of the current time, rounded down to five minutes and expressed in
    /// Windows file-time ticks, concatenated with the token Edge ships with.
    static func securityToken(now: Date = .now) -> String {
        let windowsEpochOffset = 11_644_473_600.0
        var ticks = now.timeIntervalSince1970 + windowsEpochOffset
        ticks -= ticks.truncatingRemainder(dividingBy: 300)     // to the last 5 minutes
        ticks *= 10_000_000                                      // seconds → 100ns ticks
        let seed = String(format: "%.0f", ticks) + trustedToken
        return SHA256.hash(data: Data(seed.utf8))
            .map { String(format: "%02X", $0) }.joined()
    }

    private static func identifier() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func timestamp(now: Date = .now) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT+0000 (Coordinated Universal Time)'"
        return f.string(from: now)
    }
}
