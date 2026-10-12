import Foundation
import CryptoKit

/// A real Uzbek voice, and real Uzbek ears.
///
/// iOS ships no Uzbek voice and no Uzbek recogniser, so the app reads Uzbek with a
/// Turkish stand-in and scores pronunciation against a Turkish transcription — which
/// is roughly as good as it sounds. Azure has both `uz-UZ-MadinaNeural` /
/// `uz-UZ-SardorNeural` and `uz-UZ` speech-to-text, on a free tier that is far larger
/// than two people can use.
///
/// Everything here is optional. With no key the app behaves exactly as before.
enum AzureSpeech {

    /// A neural voice by its service name, "uz-UZ-MadinaNeural". Every course has two
    /// (see `Language.neuralVoices`); these are the Uzbek ones, named for `Secrets`.
    struct Voice: RawRepresentable, Hashable, Codable {
        let rawValue: String
        init(rawValue: String) { self.rawValue = rawValue }

        static let madina = Voice(rawValue: "uz-UZ-MadinaNeural")      // female
        static let sardor = Voice(rawValue: "uz-UZ-SardorNeural")      // male

        /// "uz-UZ" out of "uz-UZ-MadinaNeural": what the SSML says it is reading.
        var locale: String { rawValue.split(separator: "-").prefix(2).joined(separator: "-") }
    }

    enum Failure: LocalizedError {
        case notConfigured
        case http(Int, String)
        case empty

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "No Azure key configured."
            case .http(let code, let body):
                switch code {
                case 401, 403: return "Azure key refused (\(code)). Check the key and region."
                case 429: return "Azure quota used up for this month (429)."
                case 404: return "Wrong Azure region (404)."
                default: return "Azure error (\(code)). \(body.prefix(100))"
                }
            case .empty: return "Azure returned no audio."
            }
        }
    }

    static var isConfigured: Bool { credentials != nil }

    /// Key and region, from the key compiled into the app.
    static var credentials: (key: String, region: String)? {
        let key = Secrets.azureSpeechKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = Secrets.azureSpeechRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !region.isEmpty else { return nil }
        return (key, region)
    }

    // MARK: - Speaking

    /// MP3 for `text`, read by an Uzbek voice.
    ///
    /// Answers from the cache whenever it can: a course repeats its words constantly,
    /// so after a first pass through a chapter almost nothing leaves the phone.
    static func audio(for text: String,
                      voice: Voice = .madina,
                      rate: Double,
                      slow: Bool) async throws -> Data {
        guard let credentials else { throw Failure.notConfigured }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw Failure.empty }

        let percent = VoiceCache.ratePercent(rate, slow: slow)
        let key = VoiceCache.key(clean, voice: voice, percent: percent, source: "azure")
        if let cached = VoiceCache.audio(key) { return cached }

        var request = URLRequest(url: URL(string: "https://\(credentials.region).tts.speech.microsoft.com/cognitiveservices/v1")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(credentials.key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("audio-24khz-48kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.setValue("Lingora", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data(ssml(clean, voice: voice, percent: percent).utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        guard data.count > 512 else { throw Failure.empty }
        VoiceCache.store(data, at: key)
        return data
    }

    private static func ssml(_ text: String, voice: Voice, percent: Int) -> String {
        let sign = percent >= 0 ? "+" : "-"
        return """
        <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='\(voice.locale)'>\
        <voice name='\(voice.rawValue)'>\
        <prosody rate='\(sign)\(abs(percent))%'>\(VoiceCache.escapedForSSML(text))</prosody>\
        </voice></speak>
        """
    }

    // MARK: - Listening

    private struct Recognition: Decodable {
        let RecognitionStatus: String
        let DisplayText: String?
    }

    /// What the microphone heard, transcribed as Uzbek.
    ///
    /// Silence comes back as an empty string rather than an error: saying nothing is
    /// an answer too, and the exercise scores it as one.
    static func transcribe(wav: Data, locale: String = "uz-UZ") async throws -> String {
        guard let credentials else { throw Failure.notConfigured }
        var components = URLComponents(string: "https://\(credentials.region).stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1")!
        components.queryItems = [URLQueryItem(name: "language", value: locale),
                                 URLQueryItem(name: "format", value: "simple")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue(credentials.key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("audio/wav; codecs=audio/pcm; samplerate=16000", forHTTPHeaderField: "Content-Type")
        request.setValue("Lingora", forHTTPHeaderField: "User-Agent")
        request.httpBody = wav

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        guard let decoded = try? JSONDecoder().decode(Recognition.self, from: data) else {
            throw Failure.empty
        }
        switch decoded.RecognitionStatus {
        case "Success": return decoded.DisplayText ?? ""
        case "NoMatch", "InitialSilenceTimeout", "BabbleTimeout": return ""
        default: throw Failure.empty
        }
    }

    // MARK: -

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw Failure.empty }
        guard (200..<300).contains(http.statusCode) else {
            throw Failure.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
