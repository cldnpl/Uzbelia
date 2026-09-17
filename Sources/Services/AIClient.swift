import Foundation

/// Which assistant writes the video-call questions and the end-of-call correction.
/// `none` keeps the app completely offline, which is the default.
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case none, gemini, claude
    var id: String { rawValue }

    var label: Bilingual {
        switch self {
        case .none: return Bilingual(it: "Nessuna", uz: "Yo'q")
        case .gemini: return Bilingual(it: "Gemini (gratis)", uz: "Gemini (bepul)")
        case .claude: return Bilingual(it: "Claude (a pagamento)", uz: "Claude (pullik)")
        }
    }

    /// Where to get a key, shown under the field.
    var console: String {
        switch self {
        case .none: return ""
        case .gemini: return "aistudio.google.com/apikey"
        case .claude: return "console.anthropic.com"
        }
    }

    /// Google has issued both shapes: the older `AIza…` keys and, since late 2026,
    /// keys beginning `AQ.`. Both are API keys and both work.
    var keyPrefixHint: String {
        switch self {
        case .none: return ""
        case .gemini: return "AIza… o AQ.…"
        case .claude: return "sk-ant-…"
        }
    }
}

/// One thin client for both providers: same prompts, same JSON contract.
enum AIClient {

    /// Tried in order, so the app survives a model being retired or being busy.
    /// The 2.5 generation is gone for keys issued from late 2026 onwards: Google answers
    /// them with "no longer available to new users", which is why the newest comes first.
    static let geminiModels = ["gemini-3.6-flash", "gemini-flash-latest", "gemini-3.5-flash"]
    static let claudeModel = "claude-sonnet-5"

    enum Failure: LocalizedError {
        case notConfigured
        case http(Int, String)
        case decoding
        case empty

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Nessuna chiave configurata."
            case .http(let code, let body):
                let detail = AIClient.readableMessage(from: body)
                switch code {
                case 400, 401, 403:
                    return "Chiave rifiutata (\(code)). \(detail.isEmpty ? "Controlla di averla copiata tutta." : detail)"
                case 429:
                    return "Quota esaurita o troppe richieste (429). Riprova più tardi."
                case 404:
                    return "Modello non disponibile (404). \(detail)"
                default:
                    return "Errore del servizio (\(code)). \(detail)"
                }
            case .decoding: return "Risposta del modello non leggibile."
            case .empty: return "Il modello non ha risposto."
            }
        }
    }

    static func isConfigured(provider: AIProvider, key: String) -> Bool {
        provider != .none && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - A quick "does my key work?" check

    static func test(provider: AIProvider, key: String) async throws -> String {
        let reply = try await complete(provider: provider, key: key,
                                       system: "You reply with a single short sentence.",
                                       prompt: "Say hello to a language learner in one short sentence.",
                                       maxTokens: 100, json: false)
        guard !reply.trimmingCharacters(in: .whitespaces).isEmpty else { throw Failure.empty }
        return reply
    }

    // MARK: - Questions for a call

    private struct GeneratedQuestion: Decodable { let target: String; let native: String }

    /// Anorcha's persona, shared by the opening plan and every live turn.
    private static func persona(targetName: String, nativeName: String, level: CEFR) -> String {
        """
        You are Anorcha, a warm, curious \(targetName) speaker on a video call with a friend \
        who is learning \(targetName) at CEFR level \(level.label) and whose own language is \
        \(nativeName). You are a person having a conversation, not a textbook: you ask open \
        questions (never yes/no), one at a time, short enough to answer out loud, and always \
        answerable with the vocabulary of the chapter she is on.
        """
    }

    /// The opening plan for a call: written from what this learner has actually studied,
    /// and deliberately steered away from everything Anorcha has already asked her.
    static func questions(provider: AIProvider,
                          key: String,
                          context: CallContext,
                          target: Language,
                          native: Language,
                          count: Int) async throws -> [Bilingual] {
        let targetName = target == .it ? "Italian" : "Uzbek"
        let nativeName = native == .it ? "Italian" : "Uzbek"
        let system = """
        \(persona(targetName: targetName, nativeName: nativeName, level: context.level))
        Reply with JSON only: an array of objects \
        {"target": "<line in \(targetName)>", "native": "<same line in \(nativeName)>"}.
        """
        let prompt = """
        \(context.briefing)

        Write \(count) lines for this call: a warm opener that fits the time of day, \
        \(max(1, count - 2)) questions about the chapter, and a closing line that ends the \
        call kindly. Follow the angle above — it is what makes this call different from the \
        last one. Reuse none of the wording from the list of earlier questions.
        """
        let text = try await complete(provider: provider, key: key, system: system,
                                      prompt: prompt, maxTokens: 1200, json: true,
                                      temperature: 1.15)
        guard let decoded = try? JSONDecoder().decode([GeneratedQuestion].self,
                                                      from: Data(extractJSON(text).utf8)) else {
            throw Failure.decoding
        }
        return decoded.map { Bilingual(it: native == .it ? $0.native : $0.target,
                                       uz: native == .it ? $0.target : $0.native) }
    }

    // MARK: - Answering back, mid-call

    /// What Anorcha says next: a reaction to what was just said, and the question that
    /// follows from it.
    struct Turn {
        var reaction: Bilingual
        var question: Bilingual?
    }

    private struct GeneratedTurn: Decodable {
        struct Line: Decodable { let target: String; let native: String }
        let reaction: Line
        let question: Line?
    }

    /// Reads the conversation so far and writes the next turn.
    ///
    /// This is what makes a call a conversation rather than a questionnaire: Anorcha
    /// picks up what the learner actually said and follows it.
    static func nextTurn(provider: AIProvider,
                         key: String,
                         context: CallContext,
                         history: [CallTurnRecord],
                         target: Language,
                         native: Language,
                         closing: Bool) async throws -> Turn {
        let targetName = target == .it ? "Italian" : "Uzbek"
        let nativeName = native == .it ? "Italian" : "Uzbek"
        let system = """
        \(persona(targetName: targetName, nativeName: nativeName, level: context.level))
        React to what she just said in one short, specific sentence — pick up a detail she \
        mentioned, never a generic "interesting". If her answer was empty or in the wrong \
        language, move on gently without scolding her. Do not correct her mistakes during \
        the call; that happens afterwards.
        Reply with JSON only: {"reaction": {"target": "...", "native": "..."}\
        \(closing ? "" : ", \"question\": {\"target\": \"...\", \"native\": \"...\"}")}.
        """
        let transcript = history.enumerated().map { i, turn in
            "\(i + 1). You asked: \(turn.question[target])\n   She answered: "
            + (turn.answer.isEmpty ? "(nothing — she skipped it)" : turn.answer)
        }.joined(separator: "\n")
        let prompt = """
        \(context.briefing)

        The call so far:
        \(transcript)

        \(closing
           ? "React to her last answer and then say goodbye warmly. Send no question."
           : "React to her last answer, then ask the one question that genuinely follows from it. Keep it inside what she has studied.")
        """
        let text = try await complete(provider: provider, key: key, system: system,
                                      prompt: prompt, maxTokens: 500, json: true,
                                      temperature: 1.1)
        guard let decoded = try? JSONDecoder().decode(GeneratedTurn.self,
                                                      from: Data(extractJSON(text).utf8)) else {
            throw Failure.decoding
        }
        func bilingual(_ line: GeneratedTurn.Line) -> Bilingual {
            Bilingual(it: native == .it ? line.native : line.target,
                      uz: native == .it ? line.target : line.native)
        }
        let reaction = bilingual(decoded.reaction)
        guard !reaction.it.isEmpty, !reaction.uz.isEmpty else { throw Failure.empty }
        return Turn(reaction: reaction, question: decoded.question.map(bilingual))
    }

    // MARK: - What does this word mean?

    private struct GeneratedGloss: Decodable {
        let word: String
        let expression: String?
    }

    /// The meaning of one word, read inside the line it appears in.
    ///
    /// The course teaches barely a fifth of its words as standalone vocabulary — the
    /// rest only ever appear inside sentences — so without this a tap on most words
    /// would come back empty. Answers are kept for good, so a word is looked up once
    /// in the life of the app.
    static func wordMeaning(of word: String,
                            inside sentence: String,
                            language: Language,
                            native: Language,
                            provider: AIProvider,
                            key: String) async throws -> (word: String, expression: String?) {
        let languageName = language == .it ? "Italian" : "Uzbek"
        let nativeName = native == .it ? "Italian" : "Uzbek"
        let system = """
        You gloss single words for a language learner, the way a dictionary footnote does.
        Give the meaning of the one \(languageName) word asked about, as it is used in the \
        sentence given, written in \(nativeName). At most four words, no sentence, no \
        explanation, no repetition of the word itself. Give the dictionary form's sense, \
        and mention the grammatical ending only if it changes the meaning.
        If — and only if — the whole sentence is an idiom or a set phrase whose meaning is \
        not the sum of its words, also give what the whole thing means in \(nativeName). \
        For an ordinary sentence, leave that out.
        Reply with JSON only: {"word": "<meaning>", "expression": "<meaning of the whole \
        phrase, or null>"}.
        """
        let prompt = """
        Sentence: "\(sentence)"
        Word to gloss: "\(word)"
        """
        let text = try await complete(provider: provider, key: key, system: system,
                                      prompt: prompt, maxTokens: 300, json: true,
                                      temperature: 0)
        guard let decoded = try? JSONDecoder().decode(GeneratedGloss.self,
                                                      from: Data(extractJSON(text).utf8)) else {
            throw Failure.decoding
        }
        let meaning = decoded.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !meaning.isEmpty else { throw Failure.empty }
        let whole = decoded.expression?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (meaning, (whole?.isEmpty ?? true) ? nil : whole)
    }

    // MARK: - Hearing Uzbek

    private struct Transcription: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    /// Writes down what was said, for a language iOS cannot hear.
    ///
    /// Gemini takes audio directly, so the key that writes the video calls also gives
    /// the pronunciation exercises real Uzbek ears — and an AI Studio key is free and
    /// asks for no card, which is the whole point.
    static func transcribe(wav: Data,
                           language: Language,
                           provider: AIProvider,
                           key: String) async throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider == .gemini, !trimmed.isEmpty else { throw Failure.notConfigured }
        let languageName = language == .it ? "Italian" : "Uzbek"

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text":
                "You transcribe short recordings of a language learner reading one sentence aloud. "
                + "Write down exactly the \(languageName) words you hear, in Latin script, with no "
                + "punctuation you did not hear and no commentary. If the recording has no speech, "
                + "reply with nothing at all. Never translate, never correct, never complete a "
                + "half-said word: the recording is being marked on pronunciation, so a tidied-up "
                + "transcript would hide the very mistakes it is meant to catch."]]],
            "contents": [["role": "user", "parts": [
                ["text": "Transcribe this \(languageName) recording."],
                ["inline_data": ["mime_type": "audio/wav", "data": wav.base64EncodedString()]],
            ]]],
            "generationConfig": ["maxOutputTokens": 2000, "temperature": 0,
                                 "thinkingConfig": ["thinkingBudget": 0]],
        ]

        var lastError: Error = Failure.empty
        for model in geminiModels {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 45
            request.setValue(trimmed, forHTTPHeaderField: "x-goog-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                try check(response, data)
                guard let decoded = try? JSONDecoder().decode(Transcription.self, from: data) else {
                    throw Failure.decoding
                }
                let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch Failure.http(let code, let body) where code == 404 || code == 503 {
                lastError = Failure.http(code, body)     // retired or busy: try the next
                continue
            } catch {
                throw error
            }
        }
        throw lastError
    }

    // MARK: - Is this another way of saying it?

    struct Judgement: Decodable {
        let acceptable: Bool
        let note: String
    }

    /// Decides whether a translation the course did not list is nevertheless right.
    ///
    /// Kept deliberately strict on meaning and deliberately generous on register: a
    /// colloquial, regional or shorter way of saying the same thing is a right answer,
    /// and being told otherwise is how a learner stops trusting the app.
    static func judge(provider: AIProvider,
                      key: String,
                      asked: String,
                      askedLanguage: Language,
                      expected: String,
                      given: String,
                      answerLanguage: Language,
                      native: Language,
                      level: CEFR) async throws -> Judgement {
        let answerName = answerLanguage == .it ? "Italian" : "Uzbek"
        let askedName = askedLanguage == .it ? "Italian" : "Uzbek"
        let nativeName = native == .it ? "Italian" : "Uzbek"
        let system = """
        You are a fair, experienced \(answerName) examiner marking one translation from a \
        CEFR \(level.label) learner whose own language is \(nativeName).
        Accept the answer whenever it is a natural way a native speaker could say the same \
        thing: colloquial, shortened, regional and more formal wordings all count, and so \
        does a different but equally correct construction. Word order, punctuation, \
        capitalisation and optional pronouns never matter.
        Reject it only when it means something different, leaves out or adds meaning, is \
        written in the wrong language, or is not grammatical \(answerName).
        Never reject an answer merely because it is not the wording in the textbook.
        Reply with JSON only: {"acceptable": true|false, "note": "<at most 12 words in \
        \(nativeName): if accepted, what her wording conveys or when it is used; if not, \
        what is wrong with it>"}.
        """
        let prompt = """
        Asked to translate from \(askedName): "\(asked)"
        The textbook wording in \(answerName): "\(expected)"
        What the learner wrote: "\(given)"
        Is what she wrote acceptable?
        """
        let text = try await complete(provider: provider, key: key, system: system,
                                      prompt: prompt, maxTokens: 300, json: true,
                                      temperature: 0)
        guard let decoded = try? JSONDecoder().decode(Judgement.self,
                                                      from: Data(extractJSON(text).utf8)) else {
            throw Failure.decoding
        }
        return decoded
    }

    // MARK: - End-of-call correction

    private struct GeneratedReview: Decodable {
        struct Fix: Decodable {
            let original: String
            let suggestion: String
            let note: String
            let kind: String
        }
        struct Item: Decodable {
            let question: String
            let said: String
            let status: String
            let corrections: [Fix]
            let better: String?
        }
        let headline: String
        let tips: [String]
        let items: [Item]
    }

    static func review(provider: AIProvider,
                       key: String,
                       turns: [CallTurnRecord],
                       target: Language,
                       native: Language,
                       level: CEFR) async throws -> CallReview {
        let targetName = target == .it ? "Italian" : "Uzbek"
        let nativeName = native == .it ? "Italian" : "Uzbek"
        let system = """
        You are a patient \(targetName) teacher reviewing a conversation with a CEFR \
        \(level.label) learner whose own language is \(nativeName). For every answer: say \
        whether it was fine, list only real mistakes (spelling, grammar, unnatural wording) \
        with a short explanation written in \(nativeName), and give a more natural way to say \
        the same thing in \(targetName). Be encouraging. Never invent mistakes: if an answer \
        is correct, return an empty corrections list.
        Reply with JSON only: {"headline": "<short verdict in \(nativeName)>", \
        "tips": ["<advice in \(nativeName)>"], "items": [{"question": "...", "said": "...", \
        "status": "good|short|language|skipped", "corrections": [{"original": "...", \
        "suggestion": "...", "note": "...", "kind": "spelling|grammar|wording"}], "better": "..."}]}
        """
        let transcript = turns.enumerated().map { i, t in
            "\(i + 1). Q: \(t.question[target])\n   A: \(t.answer.isEmpty ? "(no answer)" : t.answer)"
        }.joined(separator: "\n")

        let text = try await complete(provider: provider, key: key, system: system,
                                      prompt: transcript, maxTokens: 2000, json: true,
                                      temperature: 0.2)
        guard let decoded = try? JSONDecoder().decode(GeneratedReview.self,
                                                      from: Data(extractJSON(text).utf8)) else {
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
            let fixes = item.corrections.map {
                Correction(kind: Correction.Kind(rawValue: $0.kind) ?? .grammar,
                           original: $0.original, suggestion: $0.suggestion,
                           note: Bilingual(it: $0.note, uz: $0.note))
            }
            let question = i < turns.count ? turns[i].question
                                           : Bilingual(it: item.question, uz: item.question)
            return TurnReview(question: question, said: item.said, status: status,
                              corrections: fixes, betterVersion: item.better)
        }

        return CallReview(turns: reviews, stats: stats,
                          headline: Bilingual(it: decoded.headline, uz: decoded.headline),
                          tips: decoded.tips.map { Bilingual(it: $0, uz: $0) },
                          source: .ai)
    }

    // MARK: - Transport

    static func complete(provider: AIProvider,
                         key: String,
                         system: String,
                         prompt: String,
                         maxTokens: Int,
                         json: Bool,
                         temperature: Double = 1) async throws -> String {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider != .none, !key.isEmpty else { throw Failure.notConfigured }
        switch provider {
        case .claude: return try await callClaude(key: key, system: system, prompt: prompt,
                                                  maxTokens: maxTokens,
                                                  temperature: min(1, temperature))
        case .gemini: return try await callGemini(key: key, system: system, prompt: prompt,
                                                  maxTokens: maxTokens, json: json,
                                                  temperature: min(2, temperature))
        case .none: throw Failure.notConfigured
        }
    }

    // MARK: Claude

    private struct ClaudeResponse: Decodable {
        struct Block: Decodable { let text: String? }
        let content: [Block]
    }

    private static func callClaude(key: String, system: String, prompt: String,
                                   maxTokens: Int, temperature: Double) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": claudeModel,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "system": system,
            "messages": [["role": "user", "content": prompt]],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        guard let decoded = try? JSONDecoder().decode(ClaudeResponse.self, from: data),
              let text = decoded.content.compactMap(\.text).first else { throw Failure.decoding }
        return text
    }

    // MARK: Gemini

    private struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    private static func callGemini(key: String, system: String, prompt: String,
                                   maxTokens: Int, json: Bool, temperature: Double) async throws -> String {
        var lastError: Error = Failure.empty
        for model in geminiModels {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // The 3.x models think before answering, and the thinking is charged against
            // maxOutputTokens — so a tight budget silently returns half a sentence.
            // None of these tasks need deliberation, so it is turned off outright.
            var config: [String: Any] = [
                "maxOutputTokens": max(maxTokens, 1024),
                "temperature": temperature,
                "thinkingConfig": ["thinkingBudget": 0],
            ]
            if json { config["responseMimeType"] = "application/json" }
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "system_instruction": ["parts": [["text": system]]],
                "contents": [["role": "user", "parts": [["text": prompt]]]],
                "generationConfig": config,
            ])

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                try check(response, data)
                guard let decoded = try? JSONDecoder().decode(GeminiResponse.self, from: data),
                      let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).first else {
                    throw Failure.decoding
                }
                return text
            } catch Failure.http(let code, let body) where code == 404 || code == 503 {
                // retired, or busy right now: either way the next name may work
                lastError = Failure.http(code, body)
                continue
            } catch {
                throw error
            }
        }
        throw lastError
    }

    // MARK: Shared helpers

    /// Both providers answer errors as {"error": {"message": "..."}}; show just that.
    static func readableMessage(from body: String) -> String {
        guard let data = body.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(body.prefix(120))
        }
        if let error = root["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        if let message = root["message"] as? String { return message }
        return String(body.prefix(120))
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw Failure.decoding }
        guard (200..<300).contains(http.statusCode) else {
            throw Failure.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// Models sometimes wrap JSON in prose or a code fence. Take whichever of `[` or `{`
    /// comes first — an object full of arrays must not be mistaken for an array.
    static func extractJSON(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let bracket = trimmed.firstIndex(of: "[")
        let brace = trimmed.firstIndex(of: "{")
        let opener: (start: String.Index, close: Character)?
        switch (bracket, brace) {
        case let (b?, c?): opener = b < c ? (b, "]") : (c, "}")
        case let (b?, nil): opener = (b, "]")
        case let (nil, c?): opener = (c, "}")
        default: opener = nil
        }
        guard let opener,
              let end = trimmed.lastIndex(of: opener.close),
              opener.start < end else { return trimmed }
        return String(trimmed[opener.start...end])
    }
}
