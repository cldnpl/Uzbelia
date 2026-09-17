import Foundation

/// Optional: when an Anthropic API key is set in Settings, the video call asks Claude
/// for the questions and for the end-of-call correction instead of using the offline
/// generator. Without a key nothing here ever runs and the app stays fully offline.
enum ClaudeClient {

    static let model = "claude-sonnet-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static func isConfigured(_ key: String) -> Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum Failure: Error { case notConfigured, badResponse, decoding }

    // MARK: - Questions

    struct GeneratedQuestion: Decodable {
        let target: String
        let native: String
    }

    static func questions(key: String,
                          level: CEFR,
                          unitTitle: String,
                          topics: [String],
                          vocabulary: [String],
                          target: Language,
                          native: Language,
                          count: Int) async throws -> [Bilingual] {
        let system = """
        You are Anorcha, a warm language-exchange partner in a video call. \
        You ask open questions (never yes/no) to a learner of \(target == .it ? "Italian" : "Uzbek") \
        at CEFR level \(level.label). The learner's own language is \(native == .it ? "Italian" : "Uzbek"). \
        Questions must be answerable with the vocabulary of the chapter they are studying, \
        must sound like real conversation, and must be different from any obvious textbook list.
        Reply with JSON only: an array of objects {"target": "<question in \(target == .it ? "Italian" : "Uzbek")>", \
        "native": "<same question in \(native == .it ? "Italian" : "Uzbek")>"}.
        """
        let prompt = """
        Chapter: \(unitTitle)
        Themes: \(topics.joined(separator: ", "))
        Vocabulary they have just studied: \(vocabulary.prefix(60).joined(separator: ", "))
        Write \(count) questions: one warm opener, \(count - 2) about the chapter, one closing line.
        """
        let text = try await send(key: key, system: system, prompt: prompt, maxTokens: 1200)
        let data = Data(extractJSON(text).utf8)
        guard let decoded = try? JSONDecoder().decode([GeneratedQuestion].self, from: data) else {
            throw Failure.decoding
        }
        return decoded.map { Bilingual(it: native == .it ? $0.native : $0.target,
                                       uz: native == .it ? $0.target : $0.native) }
    }

    // MARK: - Review

    struct GeneratedReview: Decodable {
        struct Item: Decodable {
            let question: String
            let said: String
            let status: String            // good | short | language | skipped
            let corrections: [Fix]
            let better: String?
        }
        struct Fix: Decodable {
            let original: String
            let suggestion: String
            let note: String
            let kind: String              // spelling | grammar | wording
        }
        let headline: String
        let tips: [String]
        let items: [Item]
    }

    static func review(key: String,
                       turns: [CallTurnRecord],
                       target: Language,
                       native: Language,
                       level: CEFR) async throws -> CallReview {
        let system = """
        You are a patient \(target == .it ? "Italian" : "Uzbek") teacher reviewing a \
        conversation with a CEFR \(level.label) learner whose own language is \
        \(native == .it ? "Italian" : "Uzbek"). For every answer: say whether it was fine, \
        list only real mistakes (spelling, grammar, unnatural wording) with a short \
        explanation written in \(native == .it ? "Italian" : "Uzbek"), and give a more \
        natural way to say the same thing in \(target == .it ? "Italian" : "Uzbek"). \
        Be encouraging and never invent mistakes.
        Reply with JSON only: {"headline": "...", "tips": ["..."], "items": [{"question": "...", \
        "said": "...", "status": "good|short|language|skipped", "corrections": [{"original": "...", \
        "suggestion": "...", "note": "...", "kind": "spelling|grammar|wording"}], "better": "..."}]}
        """
        let transcript = turns.enumerated().map { i, t in
            "\(i + 1). Q: \(t.question[target])\n   A: \(t.answer.isEmpty ? "(no answer)" : t.answer)"
        }.joined(separator: "\n")
        let text = try await send(key: key, system: system, prompt: transcript, maxTokens: 2000)
        let data = Data(extractJSON(text).utf8)
        guard let decoded = try? JSONDecoder().decode(GeneratedReview.self, from: data) else {
            throw Failure.decoding
        }

        var stats = CallStats()
        stats.total = turns.count
        var allWords: [String] = []
        for t in turns {
            stats.seconds += t.seconds
            let words = Grader.normalise(t.answer).split(separator: " ").map(String.init)
            if !words.isEmpty { stats.answered += 1; allWords += words }
        }
        stats.words = allWords.count
        stats.distinctWords = Set(allWords).count
        stats.averageWords = stats.answered == 0 ? 0 : Double(stats.words) / Double(stats.answered)

        let reviews: [TurnReview] = decoded.items.enumerated().map { i, item in
            let status: TurnReview.Status
            switch item.status {
            case "skipped": status = .skipped
            case "language": status = .wrongLanguage
            case "short": status = .tooShort
            default: status = .good
            }
            let fixes = item.corrections.map { fix in
                Correction(kind: Correction.Kind(rawValue: fix.kind) ?? .grammar,
                           original: fix.original,
                           suggestion: fix.suggestion,
                           note: Bilingual(it: fix.note, uz: fix.note))
            }
            let question = i < turns.count ? turns[i].question
                                           : Bilingual(it: item.question, uz: item.question)
            return TurnReview(question: question, said: item.said, status: status,
                              corrections: fixes, betterVersion: item.better)
        }

        return CallReview(turns: reviews,
                          stats: stats,
                          headline: Bilingual(it: decoded.headline, uz: decoded.headline),
                          tips: decoded.tips.map { Bilingual(it: $0, uz: $0) },
                          source: .claude)
    }

    // MARK: - Transport

    private struct Response: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    private static func send(key: String, system: String, prompt: String, maxTokens: Int) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(key.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw Failure.badResponse
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let text = decoded.content.compactMap(\.text).first else {
            throw Failure.decoding
        }
        return text
    }

    /// Models sometimes wrap JSON in prose or a fence; take the outermost array/object.
    private static func extractJSON(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for (open, close) in [("[", "]"), ("{", "}")] {
            if let start = trimmed.firstIndex(of: Character(open)),
               let end = trimmed.lastIndex(of: Character(close)), start < end {
                return String(trimmed[start...end])
            }
        }
        return trimmed
    }
}
