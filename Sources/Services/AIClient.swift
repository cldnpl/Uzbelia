import Foundation

/// Which assistant writes the video-call questions and the end-of-call correction.
/// `none` keeps the app completely offline, which is the default.
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case none, gemini, claude
    var id: String { rawValue }

    var label: Bilingual {
        switch self {
        case .none: return Bilingual("None")
        case .gemini: return Bilingual("Gemini (free)")
        case .claude: return Bilingual("Claude (paid)")
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
    ///
    /// Each model has its own free quota, so a "too many requests" from one is a reason
    /// to ask the next, not to give up: a call makes a request every few seconds.
    static let geminiModels = ["gemini-3.6-flash", "gemini-3.5-flash", "gemini-flash-latest"]
    static let claudeModel = "claude-sonnet-5"

    enum Failure: LocalizedError {
        case notConfigured
        case overBudget
        case http(Int, String)
        case decoding
        case empty

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "No key configured."
            case .overBudget: return "The assistant has used up today's free requests."
            case .http(let code, let body):
                let detail = AIClient.readableMessage(from: body)
                switch code {
                case 400, 401, 403:
                    return "Key refused (\(code)). \(detail.isEmpty ? "Check it was copied in full." : detail)"
                case 429:
                    return "Quota used up or too many requests (429). Try again later."
                case 404:
                    return "Model not available (404). \(detail)"
                default:
                    return "Service error (\(code)). \(detail)"
                }
            case .decoding: return "The model's reply couldn't be read."
            case .empty: return "The model didn't answer."
            }
        }
    }

    static func isConfigured(provider: AIProvider, key: String) -> Bool {
        provider != .none && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Configured, and with requests left today for this kind of use.
    static func isAvailable(provider: AIProvider, key: String, for use: AIBudget.Use) -> Bool {
        isConfigured(provider: provider, key: key) && AIBudget.canSpend(use)
    }

    // MARK: - A quick "does my key work?" check

    static func test(provider: AIProvider, key: String) async throws -> String {
        let reply = try await complete(provider: provider, key: key, use: .conversation,
                                       system: "You reply with a single short sentence.",
                                       prompt: "Say hello to a language learner in one short sentence.",
                                       maxTokens: 100, json: false)
        guard !reply.trimmingCharacters(in: .whitespaces).isEmpty else { throw Failure.empty }
        return reply
    }

    // MARK: - Who Anorcha is

    /// Anorcha's persona, shared by every live turn.
    private static func persona(targetName: String, nativeName: String, level: CEFR) -> String {
        """
        You are Anorcha, a warm, curious \(targetName) speaker on a video call with a friend \
        who is learning \(targetName) at CEFR level \(level.label) and whose own language is \
        \(nativeName). You are a person having a conversation, not a textbook.
        """
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
    /// This is what makes a call a conversation rather than a questionnaire. The model
    /// is made to write down first what it understood her to say and which subject it
    /// is on — two fields nobody shows — because a model that has just put "she has
    /// two brothers, one is a doctor" into words does not then ask about the weather.
    static func nextTurn(provider: AIProvider,
                         key: String,
                         context: CallContext,
                         transcript: [CallLine],
                         target: Language,
                         native: Language,
                         closing: Bool) async throws -> Turn {
        let targetName = target.name
        let nativeName = native.name
        let address = target.informalAddress
        let system = """
        \(persona(targetName: targetName, nativeName: nativeName, level: context.level))

        This is ONE conversation, never a questionnaire. Every question you ask grows out of \
        what she has just told you.

        1. First work out what she actually said in her last answer. It comes from speech \
        recognition, so it may be misspelt, unpunctuated or cut short: read it generously, \
        the way a friend would.
        2. React to it in one short sentence that picks up its concrete detail — a name, a \
        person, a place, a food, a number, a feeling — never a generic "interesting" or "good".
        3. Then ask ONE open question (never yes/no) about that same detail, or about the \
        subject she is on: who, what, where, when, why, how, what happened next. Stay on a \
        subject for at least two or three exchanges; when it is exhausted, move to something \
        right next to it, through a detail she gave you ("your brother is a doctor — and your \
        sister, what does she do?"), never to an unrelated topic.
        4. After the greeting, bring the talk round to the subject of her chapter, through \
        something she said if you can; from then on follow her.
        5. Never ask for something she has already told you, and bring back what she said \
        earlier when it fits.
        6. If nothing came through, or her answer is unclear or not in \(targetName), do not \
        move on: say kindly that you did not catch it and ask the same thing again, more \
        simply — you may offer two choices. If she skipped the question, say it is fine and \
        ask something easier on the same subject.
        7. Keep it short and simple enough for \(context.level.label): one reaction sentence, \
        one question, the words of her chapter where you can. \(address) Do not correct her \
        mistakes; that happens after the call.

        Reply with JSON only:
        {"understood": "<in English, a few words: what she told you>", \
        "thread": "<in English: the subject you are on now>", \
        "reaction": {"target": "<\(targetName)>", "native": "<the same in \(nativeName)>"}, \
        "question": {"target": "<\(targetName)>", "native": "<the same in \(nativeName)>"}}
        """
        let lines = transcript.map { line in
            (line.speaker == .anorcha ? "Anorcha: " : "She: ") + line.text
        }.joined(separator: "\n")
        let prompt = """
        \(context.briefing)

        The call so far, oldest first:
        \(lines)

        \(closing
           ? "This is the end of the call. React to her last answer, then put in \"question\" a warm goodbye (not a question) that mentions something she told you during the call."
           : "Write your next turn.")
        """
        let text = try await complete(provider: provider, key: key, use: .conversation,
                                      system: system, prompt: prompt, maxTokens: 600, json: true,
                                      temperature: 0.9, timeout: 15)
        guard let decoded = try? JSONDecoder().decode(GeneratedTurn.self,
                                                      from: Data(extractJSON(text).utf8)) else {
            throw Failure.decoding
        }
        func bilingual(_ line: GeneratedTurn.Line) -> Bilingual {
            Bilingual(en: line.native, tx: line.target)
        }
        let reaction = bilingual(decoded.reaction)
        guard !reaction.en.isEmpty, !reaction.tx.isEmpty else { throw Failure.empty }
        let question = decoded.question.map(bilingual)
        guard let question, !question.en.isEmpty, !question.tx.isEmpty else { throw Failure.empty }
        return Turn(reaction: reaction, question: question)
    }

    // MARK: - Messaging, not talking

    /// Anorcha's next message in a written chapter.
    ///
    /// Deliberately a different person from the one on the video call: messages are
    /// short, they run on, they are allowed a "haha" and an emoji, and above all they
    /// keep *asking* — a chat whose replies do not need answering is a chat the
    /// learner stops writing in. `history` empty means this is the opening message.
    static func chatMessage(provider: AIProvider,
                            key: String,
                            briefing: String,
                            history: [CallTurnRecord],
                            target: Language,
                            native: Language,
                            level: CEFR,
                            closing: Bool) async throws -> Turn {
        let targetName = target.name
        let nativeName = native.name
        let band = lengthBand(for: level)
        let opening = history.isEmpty

        let system = """
        You are Anorcha, texting a friend who is learning \(targetName) at CEFR level \
        \(level.label) and whose own language is \(nativeName). This is a chat, not a lesson \
        and not a phone call: write the way people actually text — one or two short \
        messages' worth, \(band.min) to \(band.max + 4) words, contractions, the odd emoji, \
        no greetings formula beyond the first message.

        Every message of yours ends in something she has to answer: a question, a choice \
        between two things, or a piece of news that begs for a reaction. Stay inside the \
        vocabulary of her chapter — if you need a word she has not met, choose a simpler \
        one. Pick up the detail she just gave you and go further into it rather than \
        changing the subject; you are allowed to disagree, to tease, to be surprised.

        Never correct her mistakes in the chat itself — that happens at the end, and a \
        correction mid-conversation is how someone stops writing. If her message is empty, \
        in the wrong language, or you genuinely cannot make it out, say so warmly and ask \
        the same thing in an easier way.

        Reply with JSON only: {"reaction": {"target": "<your message in \(targetName)>", \
        "native": "<the same message in \(nativeName)>"}\
        \(closing ? "" : ", \"question\": null")}.
        """

        let transcript = history.enumerated().map { i, turn in
            "\(i + 1). You wrote: \(turn.question[target])\n   She replied: "
            + (turn.answer.isEmpty ? "(nothing — she skipped it)" : turn.answer)
        }.joined(separator: "\n")

        let instruction: String
        if opening {
            instruction = "Send her the first message of the conversation. Open the situation "
                + "above in your own words — do not announce it, just start it — and end on "
                + "something she has to answer."
        } else if closing {
            instruction = "React to what she just wrote and then close the conversation warmly, "
                + "mentioning something she told you earlier. Ask nothing more."
        } else {
            instruction = "React to what she just wrote and keep the conversation going: one "
                + "more message, following the detail she gave you."
        }

        let prompt = """
        \(briefing)

        \(opening ? "Nothing has been said yet." : "The chat so far, oldest first:\n\(transcript)")

        \(instruction)
        """

        let text = try await complete(provider: provider, key: key, use: .conversation,
                                      system: system, prompt: prompt, maxTokens: 600, json: true,
                                      temperature: 1.15)
        guard let decoded = try? JSONDecoder().decode(GeneratedTurn.self,
                                                      from: Data(extractJSON(text).utf8)) else {
            throw Failure.decoding
        }
        let message = Bilingual(en: decoded.reaction.native, tx: decoded.reaction.target)
        guard !message.en.isEmpty, !message.tx.isEmpty else { throw Failure.empty }
        return Turn(reaction: message, question: nil)
    }

    // MARK: - What does this word mean?

    private struct GeneratedGloss: Decodable {
        let word: String
        let phrase: String?
        let phraseMeaning: String?
    }

    /// The meaning of one word, read inside the line it appears in — and, when that
    /// word is part of an idiom or a set expression in the line, that expression.
    ///
    /// Never the whole sentence: a tap on one word asks about that word. The course
    /// teaches barely a fifth of its words as standalone vocabulary — the rest only
    /// ever appear inside sentences — so without this a tap on most words would come
    /// back empty. Answers are kept for good, so a word is looked up once.
    static func wordMeaning(of word: String,
                            inside sentence: String,
                            language: Language,
                            native: Language,
                            provider: AIProvider,
                            key: String) async throws -> (word: String, phrase: String?, phraseMeaning: String?) {
        let languageName = language.name
        let nativeName = native.name
        let system = """
        You gloss single words for a language learner, the way a dictionary footnote does.
        Give the meaning of the one \(languageName) word asked about, as it is used in the \
        sentence given, written in \(nativeName). At most four words, no sentence, no \
        explanation, no repetition of the word itself. Give the sense it has here, and \
        mention the grammatical ending only if it changes the meaning.
        If — and only if — that word is part of an idiom or a set expression of two to four \
        words inside the sentence (such as a greeting, a fixed phrase, a phrasal verb) whose \
        meaning is not the sum of its words, give that expression exactly as it appears in \
        the sentence and its meaning in \(nativeName). Never give the meaning of the whole \
        sentence; for an ordinary word, leave the expression out.
        Reply with JSON only: {"word": "<meaning>", "phrase": "<the expression's words \
        copied from the sentence, or null>", "phraseMeaning": "<its meaning, or null>"}.
        """
        let prompt = """
        Sentence: "\(sentence)"
        Word to gloss: "\(word)"
        """
        let text = try await complete(provider: provider, key: key, use: .extra,
                                      system: system, prompt: prompt, maxTokens: 300, json: true,
                                      temperature: 0)
        guard let decoded = try? JSONDecoder().decode(GeneratedGloss.self,
                                                      from: Data(extractJSON(text).utf8)) else {
            throw Failure.decoding
        }
        let meaning = decoded.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !meaning.isEmpty else { throw Failure.empty }

        // an expression is only kept if it really is a short piece of this sentence
        // that contains the word — not the sentence itself, and not something invented
        var phrase = decoded.phrase?.trimmingCharacters(in: .whitespacesAndNewlines)
        let phraseMeaning = decoded.phraseMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate = phrase {
            let words = Grader.normalise(candidate).split(separator: " ")
            let whole = Grader.normalise(sentence)
            let fits = (2...4).contains(words.count)
                && whole.contains(Grader.normalise(candidate))
                && words.contains(Substring(Grader.normalise(word)))
                && (Grader.normalise(candidate) != whole || whole.split(separator: " ").count <= 3)
            if !fits { phrase = nil }
        }
        guard let phrase, let phraseMeaning, !phraseMeaning.isEmpty else { return (meaning, nil, nil) }
        return (meaning, phrase, phraseMeaning)
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
    /// the pronunciation exercises ears for a language the phone has none for.
    static func transcribe(wav: Data,
                           language: Language,
                           provider: AIProvider,
                           key: String) async throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider == .gemini, !trimmed.isEmpty else { throw Failure.notConfigured }
        guard AIBudget.canSpend(.extra) else { throw Failure.overBudget }
        let languageName = language.name

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text":
                "You transcribe short recordings of a language learner reading one sentence aloud. "
                + "Write down exactly the \(languageName) words you hear, in \(language.scriptName) script, with no "
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
                AIBudget.spend()
                let (data, response) = try await URLSession.shared.data(for: request)
                try check(response, data)
                guard let decoded = try? JSONDecoder().decode(Transcription.self, from: data) else {
                    throw Failure.decoding
                }
                let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch Failure.http(let code, let body) where [404, 429, 500, 503].contains(code) {
                if AIBudget.noteRefusal(code: code, body: body) { throw Failure.overBudget }
                lastError = Failure.http(code, body)     // retired or busy: try the next
                continue
            } catch {
                throw error
            }
        }
        throw lastError
    }

    // MARK: - Sentences the course has never said before

    private struct GeneratedPhrase: Decodable {
        let target: String
        let native: String
        let rom: String?
    }

    /// How long a sentence is allowed to be, by level. A1 that runs to twelve words is
    /// not A1 any more, and the single fastest way to make generated material useless
    /// is to let it drift above the chapter it belongs to.
    static func lengthBand(for level: CEFR) -> (min: Int, max: Int) {
        switch level {
        case .a1: return (3, 6)
        case .a2: return (4, 9)
        case .b1: return (6, 13)
        case .b2: return (8, 18)
        }
    }

    /// Writes new sentences for a chapter the learner is on.
    ///
    /// The course ships a fixed corpus, which means the fifth pass over a lesson asks
    /// the same fifteen sentences as the first. This is the way out: the same
    /// vocabulary and the same grammar, in sentences nobody has seen — bounded by the
    /// chapter's own words and by the length its CEFR level allows, so "new" never
    /// quietly means "harder".
    static func freshPhrases(provider: AIProvider,
                             key: String,
                             level: CEFR,
                             unitTitle: String,
                             lessonTitle: String,
                             grammar: [String],
                             vocabulary: [Pair],
                             avoid: [String],
                             target: Language,
                             native: Language,
                             count: Int) async throws -> [Pair] {
        let targetName = target.name
        let nativeName = native.name
        let band = lengthBand(for: level)

        let system = """
        You write practice sentences for a CEFR \(level.label) learner of \(targetName) whose \
        own language is \(nativeName). You are given the exact vocabulary a chapter teaches; \
        your sentences must be built from that vocabulary plus the ordinary function words \
        (articles, pronouns, prepositions, the commonest verbs) a learner at this level \
        already has. Introduce no new content words.

        Every sentence must:
        · be between \(band.min) and \(band.max) words long in \(targetName);
        · be something a person would actually say — a request, a remark, a question, a \
          plan, a complaint — never a grammar drill;
        · differ from all the others in subject AND in structure: do not write ten \
          sentences off the same template with one word swapped;
        · be natural, idiomatic \(targetName), correctly spelled and accented;
        · come with a faithful, equally natural \(nativeName) translation — not a \
          word-for-word gloss.

        \(target.scriptNote)
        Reply with JSON only: an array of objects \
        {"target": "<\(targetName)>", "native": "<\(nativeName)>"\
        \(target.isLatin ? "" : ", \"rom\": \"<romanisation of the \(targetName)>\"")}.
        """

        let vocabList = vocabulary.prefix(60).map { "· \($0[target])  =  \($0[native])" }
            .joined(separator: "\n")
        let avoidList = avoid.isEmpty ? "(nothing yet)"
            : avoid.suffix(45).map { "· \($0)" }.joined(separator: "\n")
        let grammarLine = grammar.isEmpty ? "(none listed)" : grammar.joined(separator: "; ")

        let prompt = """
        Chapter: \(unitTitle) — \(lessonTitle)
        Grammar this chapter teaches: \(grammarLine)

        The vocabulary it teaches:
        \(vocabList)

        Sentences she has already been given — write nothing like these, in wording or in \
        subject:
        \(avoidList)

        Write \(count) new sentences.
        """

        let text = try await complete(provider: provider, key: key, use: .extra,
                                      system: system, prompt: prompt, maxTokens: 2200, json: true,
                                      temperature: 1.2)
        guard let decoded = try? JSONDecoder().decode([GeneratedPhrase].self,
                                                      from: Data(extractJSON(text).utf8)) else {
            throw Failure.decoding
        }
        let pairs = decoded.map {
            Pair(en: $0.native, tx: $0.target, rom: $0.rom?.isEmpty == false ? $0.rom : nil)
        }
        guard !pairs.isEmpty else { throw Failure.empty }
        return pairs
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
        let answerName = answerLanguage.name
        let askedName = askedLanguage.name
        let nativeName = native.name
        let system = """
        You are a fair, experienced \(answerName) examiner marking one translation from a \
        CEFR \(level.label) learner whose own language is \(nativeName).
        Accept the answer whenever it is a natural way a native speaker could say the same \
        thing: colloquial, shortened, regional and more formal wordings all count, and so \
        does a different but equally correct construction. Word order, punctuation, \
        capitalisation and optional pronouns never matter.
        In particular, all of these are RIGHT and must be accepted:
        · a subject or possessive pronoun left out because the ending already carries it \
        (Uzbek "itim" for "mening itim", "Klaudiyaman" for "men Klaudiyaman"), or added \
        where the textbook left it out; English contractions ("I'm" / "I am");
        · a longer or shorter form of the same greeting, thanks, apology or goodbye \
        ("assalomu alaykum" / "salom", "hi" / "hello", "tashakkur" / "rahmat");
        · a different but correct construction for the same meaning ("Menda kitob bor" / \
        "Mening kitobim bor", "My name is" / "I'm called"), a synonym, a familiar or polite \
        "you" where the prompt does not make the register unmistakable;
        · the polite particle of either gender where the language has two (Thai ครับ / ค่ะ);
        · a name spelled the learner's way ("Claudia" / "Klaudiya"), digits for a number;
        · a single-letter typo or a missing apostrophe in an otherwise right answer.
        Reject it only when it means something different, leaves out or adds meaning, is \
        written in the wrong language, or is clearly not grammatical \(answerName).
        Never reject an answer merely because it is not the wording in the textbook. When \
        in doubt about a wording that a native speaker would understand as the same \
        sentence, accept it.
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
        let text = try await complete(provider: provider, key: key, use: .extra,
                                      system: system, prompt: prompt, maxTokens: 300, json: true,
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
        let targetName = target.name
        let nativeName = native.name
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

        let text = try await complete(provider: provider, key: key, use: .feedback,
                                      system: system, prompt: transcript, maxTokens: 2000, json: true,
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
                           note: Bilingual($0.note))
            }
            let question = i < turns.count ? turns[i].question
                                           : Bilingual(item.question)
            return TurnReview(question: question, said: item.said, status: status,
                              corrections: fixes, betterVersion: item.better)
        }

        return CallReview(turns: reviews, stats: stats,
                          headline: Bilingual(decoded.headline),
                          tips: decoded.tips.map { Bilingual($0) },
                          source: .ai)
    }

    // MARK: - A short text, corrected

    private struct GeneratedComposition: Decodable {
        struct Issue: Decodable {
            let fragment: String
            let kind: String
            let fix: String
            let hint: String
            let why: String?
        }
        let issues: [Issue]
        let corrected: String
    }

    /// Corrects a short text written to a brief.
    ///
    /// Strict about real mistakes and generous about wording: the brief comes with a
    /// model text, but she is not asked to reproduce it — anything natural that says
    /// the things she was asked to say is right. Clues come back first, fixes second,
    /// because the exercise is corrected over several rounds and the first round
    /// should make her look, not copy.
    static func correctComposition(provider: AIProvider,
                                   key: String,
                                   task: CompositionTask,
                                   text: String) async throws -> CompositionReport {
        let targetName = task.target.name
        let nativeName = task.native.name
        let system = """
        You are a kind, precise \(targetName) teacher correcting a short text by a CEFR \
        \(task.level.label) learner whose own language is \(nativeName). She was asked to \
        write a few sentences that say given things; a model version is provided, but she \
        does NOT have to match it: accept any natural, correct wording that says the same \
        things, in any order, with or without optional pronouns. Extra sentences of her own \
        are welcome — correct them, never call them extra.
        Report only real mistakes: misspellings (\(task.target == .uz ? "Uzbek apostrophes in o' and g' count" : "in its own script")), wrong \
        words, missing or superfluous words, wrong word order, grammar, a sentence in the \
        wrong language, or one of the required points not said at all. Never invent mistakes; \
        a correct text has an empty list.
        For every mistake: "fragment" is the exact substring of her text (empty string for a \
        missing point), "kind" is one of spelling|word|missingWord|extraWord|order|missingPart|\
        grammar|language, "fix" is the corrected fragment in \(targetName), "hint" is a short \
        nudge in \(nativeName) that says where to look WITHOUT giving the answer (at most 12 \
        words), and "why" explains the rule in \(nativeName) (at most 15 words).
        "corrected" is her whole text with only the necessary changes.
        Reply with JSON only: {"issues": [{"fragment": "...", "kind": "...", "fix": "...", \
        "hint": "...", "why": "..."}], "corrected": "..."}.
        """
        let points = task.outline.enumerated().map { i, pair in
            "\(i + 1). \(pair[task.native])   (model: \(pair[task.target]))"
        }.joined(separator: "\n")
        let prompt = """
        What she had to say:
        \(points)

        What she wrote:
        \(text)
        """
        let reply = try await complete(provider: provider, key: key, use: .feedback,
                                       system: system, prompt: prompt, maxTokens: 1200, json: true,
                                       temperature: 0)
        guard let decoded = try? JSONDecoder().decode(GeneratedComposition.self,
                                                      from: Data(extractJSON(reply).utf8)) else {
            throw Failure.decoding
        }
        let issues = decoded.issues.compactMap { item -> CompositionIssue? in
            let kind = CompositionIssue.Kind(rawValue: item.kind) ?? .grammar
            let fragment = item.fragment.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = fragment.isEmpty ? nil
                : text.range(of: fragment, options: [.caseInsensitive, .diacriticInsensitive])
            // a fix identical to what she wrote is not a mistake
            if !fragment.isEmpty, Grader.normalise(fragment) == Grader.normalise(item.fix) { return nil }
            let why = item.why.flatMap { $0.isEmpty ? nil : Bilingual($0) }
            return CompositionIssue(kind: kind, range: range, fragment: fragment, fix: item.fix,
                                    why: why, customHint: item.hint)
        }
        return CompositionReport(text: text, issues: issues,
                                 corrected: decoded.corrected.isEmpty ? task.model : decoded.corrected,
                                 source: .ai)
    }

    // MARK: - Transport

    /// `timeout` is per request: a live call cannot sit through a minute of silence
    /// waiting for one answer, so it asks for much less.
    static func complete(provider: AIProvider,
                         key: String,
                         use: AIBudget.Use = .extra,
                         system: String,
                         prompt: String,
                         maxTokens: Int,
                         json: Bool,
                         temperature: Double = 1,
                         timeout: TimeInterval = 60) async throws -> String {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider != .none, !key.isEmpty else { throw Failure.notConfigured }
        guard AIBudget.canSpend(use) else { throw Failure.overBudget }
        switch provider {
        case .claude: return try await callClaude(key: key, system: system, prompt: prompt,
                                                  maxTokens: maxTokens,
                                                  temperature: min(1, temperature),
                                                  timeout: timeout)
        case .gemini: return try await callGemini(key: key, system: system, prompt: prompt,
                                                  maxTokens: maxTokens, json: json,
                                                  temperature: min(2, temperature),
                                                  timeout: timeout)
        case .none: throw Failure.notConfigured
        }
    }

    // MARK: Claude

    private struct ClaudeResponse: Decodable {
        struct Block: Decodable { let text: String? }
        let content: [Block]
    }

    private static func callClaude(key: String, system: String, prompt: String,
                                   maxTokens: Int, temperature: Double,
                                   timeout: TimeInterval) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
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

        AIBudget.spend()
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
                                   maxTokens: Int, json: Bool, temperature: Double,
                                   timeout: TimeInterval) async throws -> String {
        var lastError: Error = Failure.empty
        for model in geminiModels {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = timeout
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
                AIBudget.spend()
                let (data, response) = try await URLSession.shared.data(for: request)
                try check(response, data)
                guard let decoded = try? JSONDecoder().decode(GeminiResponse.self, from: data),
                      let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).first else {
                    throw Failure.decoding
                }
                return text
            } catch Failure.http(let code, let body) where [404, 429, 500, 503].contains(code) {
                // out for the day: no other name will do better, and every further try
                // only keeps her waiting
                if AIBudget.noteRefusal(code: code, body: body) { throw Failure.overBudget }
                // retired, busy, or out of requests for this minute: the next name may work
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

// MARK: - How many requests are left today

/// The free Gemini tier allows twenty requests a day for the whole project — both
/// phones together — and Google answers the twenty-first with a refusal that holds
/// until the next day. Spent carelessly, that is gone before lunch: a tap on a word,
/// a node sheet opening, a lesson warming up new sentences.
///
/// So requests are rationed by what they are for. A conversation (the video call,
/// the writing chat) may always ask; corrections stop a little earlier, so there is
/// always room for a call's report; and the extras — glosses, fresh sentences,
/// second opinions — have a small share of their own and then quietly fall back to
/// what the app does offline. Once Google has said "no more today", nothing asks
/// again until the time it named, so the app never waits on an answer it cannot get.
enum AIBudget {
    enum Use { case conversation, feedback, extra }

    /// How many requests this phone may have made today before a use stops asking.
    static func ceiling(for use: Use) -> Int {
        switch use {
        case .conversation: return .max
        case .feedback: return 16
        case .extra: return 5
        }
    }

    private static let store = UserDefaults.standard
    private static let dayKey = "ai.budget.day"
    private static let countKey = "ai.budget.count"
    private static let pauseKey = "ai.budget.pausedUntil"
    private static let lock = NSLock()

    private static var today: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        // Google's day turns over at midnight in California, not here
        f.timeZone = TimeZone(identifier: "America/Los_Angeles")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    /// Requests made from this phone since Google's day began.
    static var spentToday: Int {
        lock.lock(); defer { lock.unlock() }
        return store.string(forKey: dayKey) == today ? store.integer(forKey: countKey) : 0
    }

    static var pausedUntil: Date? {
        guard let until = store.object(forKey: pauseKey) as? Date, until > .now else { return nil }
        return until
    }

    static func canSpend(_ use: Use) -> Bool {
        pausedUntil == nil && spentToday < ceiling(for: use)
    }

    static func spend() {
        lock.lock(); defer { lock.unlock() }
        if store.string(forKey: dayKey) != today {
            store.set(today, forKey: dayKey)
            store.set(0, forKey: countKey)
        }
        store.set(store.integer(forKey: countKey) + 1, forKey: countKey)
    }

    /// Reads a refusal. True when it is the daily one — in which case nothing asks
    /// again until the moment Google gave, or the next day if it gave none.
    @discardableResult
    static func noteRefusal(code: Int, body: String) -> Bool {
        guard code == 429, body.contains("PerDay") else { return false }
        var wait: TimeInterval = 6 * 3600
        if let range = body.range(of: #""retryDelay":\s*"(\d+)"#, options: .regularExpression) {
            let digits = body[range].filter(\.isNumber)
            if let seconds = TimeInterval(digits) { wait = seconds }
        }
        store.set(Date().addingTimeInterval(wait), forKey: pauseKey)
        return true
    }

    /// For the tests: forget today's spending and any pause.
    static func reset() {
        store.removeObject(forKey: dayKey)
        store.removeObject(forKey: countKey)
        store.removeObject(forKey: pauseKey)
    }
}

// MARK: - What the prompts need to know about a language

extension Language {
    /// How Anorcha addresses a friend in it.
    var informalAddress: String {
        switch self {
        case .uz: return "Talk to her informally (sen)."
        case .fa: return "Talk to her informally (to), in everyday spoken Persian."
        case .th: return "Talk to her as a friend, casually; use polite particles only where natural."
        case .tl: return "Talk to her as a friend, informally (no po/opo)."
        case .ms: return "Talk to her as a friend, informally (kamu/awak)."
        case .yue: return "Talk to her as a friend, in everyday spoken Hong Kong Cantonese."
        case .pa: return "Talk to her as a friend, informally (tū)."
        case .ta: return "Talk to her as a friend, informally (nī), in simple modern standard Tamil."
        case .te: return "Talk to her as a friend, informally (nuvvu)."
        case .ml: return "Talk to her as a friend, informally (nī)."
        case .kn: return "Talk to her as a friend, informally (nīnu)."
        case .kmr, .ckb: return "Talk to her as a friend, informally (tu/to)."
        case .mn: return "Talk to her as a friend, informally (chi)."
        case .km: return "Talk to her as a friend, casually."
        case .lo: return "Talk to her as a friend, casually."
        case .kk, .ky: return "Talk to her informally (sen)."
        case .az: return "Talk to her informally (sən)."
        case .ka: return "Talk to her informally (shen)."
        case .hy: return "Talk to her informally (du)."
        case .ur: return "Talk to her as a friend, informally (tum)."
        case .bn: return "Talk to her as a friend, informally (tumi)."
        case .en: return "Talk to her as a friend."
        }
    }

    /// The name of the script it is written in.
    var scriptName: String {
        switch self {
        case .th: return "Thai"
        case .fa: return "Persian (Arabic)"
        case .ckb: return "Kurdish (Arabic)"
        case .ur: return "Urdu (Perso-Arabic, Nastaliq)"
        case .yue: return "Traditional Chinese characters"
        case .pa: return "Gurmukhi"
        case .ta: return "Tamil"
        case .te: return "Telugu"
        case .ml: return "Malayalam"
        case .kn: return "Kannada"
        case .bn: return "Bengali"
        case .mn, .kk, .ky: return "Cyrillic"
        case .km: return "Khmer"
        case .lo: return "Lao"
        case .ka: return "Georgian"
        case .hy: return "Armenian"
        default: return "Latin"
        }
    }

    /// One line on spelling, for prompts that write in it.
    var scriptNote: String {
        switch self {
        case .uz: return "Uzbek is written in the Latin alphabet, with the apostrophes of o' and g' intact."
        case .th: return "Write Thai in Thai script, and give each sentence a learner-friendly romanisation with tone marks."
        case .fa: return "Write Persian in Persian script, and give each sentence a simple romanisation with the vowels written out."
        case .tl: return "Write standard Tagalog as spoken in Manila."
        case .ms: return "Write standard Malaysian Malay (Bahasa Melayu)."
        case .yue: return "Write colloquial Hong Kong Cantonese in Traditional characters (係, 喺, 嘅, 咗, 唔), not Mandarin, and give each sentence its Jyutping with tone numbers."
        case .kmr: return "Write Kurmanji Kurdish in the Latin (Hawar) alphabet, with ê, î, û, ç, ş."
        case .az: return "Write Azerbaijani in the Latin alphabet, with ə, ğ, ı, ö, ş, ü, ç."
        case .en: return ""
        default: return "Write \(name) in \(scriptName) script, and give each sentence a simple learner-friendly romanisation."
        }
    }
}
