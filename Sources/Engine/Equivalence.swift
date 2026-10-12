import Foundation

/// Decides, offline and at once, whether a translation she wrote in her own words
/// says the same thing as the course's.
///
/// A course lists one wording per sentence; a language allows several, and most of
/// the difference is predictable:
///
/// - Uzbek marks the person on the verb and on the noun, so `mening itim` and `itim`
///   are the same "my dog", and `men Klaudiyaman` does not need its `men`. Italian
///   drops its subject pronouns the same way: *sono Claudia* = *io sono Claudia*.
/// - A greeting has a short and a long form (`salom` / `assalomu alaykum`), and
///   so do thanks, apologies and "please".
/// - A name comes spelled the way she spells it at home: *Claudia* for `Klaudiya`.
/// - A time word can open the sentence or sit before the verb.
/// - A number can be written in figures.
///
/// None of that is a mistake, and none of it should need a network call — or a tap
/// on "mine is right too" — to be accepted. Every rule only ever sets aside
/// something that carries no meaning of its own in that position, and anything it
/// cannot vouch for is left to the assistant.
enum Equivalence {

    enum Match: Equatable {
        /// Says the same thing as `canonical`, in a different but correct way.
        case same(canonical: String)
        /// Says the same thing, with a slip of spelling in it.
        case nearly(canonical: String)
    }

    /// Compares what she wrote with every wording the course accepts (`a / b`).
    ///
    /// `prompt` is what she was asked to translate: a few rules depend on it — "ciao"
    /// is a greeting when she was translating `salom` and a goodbye after `xayr`.
    static func compare(_ given: String, with expected: String,
                        in language: Language, prompt: String = "") -> Match? {
        guard !Grader.normalise(given).isEmpty else { return nil }
        let context = Set(Grader.normalise(prompt).split(separator: " ").map(String.init))
        let mine = form(given, language: language, context: context)
        guard !mine.tokens.isEmpty else { return nil }

        var nearly: String?
        for wording in Grader.alternatives(expected) {
            let theirs = form(wording, language: language, context: context)
            guard !theirs.tokens.isEmpty else { continue }
            let names = self.names(in: wording, language: language)
            if same(mine.tokens, theirs.tokens, names: names),
               pronounsAgree(mine, theirs, language: language) {
                return .same(canonical: wording)
            }
            if nearly == nil, pronounsAgree(mine, theirs, language: language),
               close(mine.tokens, theirs.tokens) {
                nearly = wording
            }
        }
        return nearly.map { .nearly(canonical: $0) }
    }

    // MARK: - A sentence, reduced to what carries its meaning

    struct Form {
        var tokens: [String] = []
        /// Subject and possessive pronouns set aside, and whether each one agrees
        /// with the verb or noun it stands for.
        var dropped: [(word: String, agrees: Bool)] = []
    }

    static func form(_ raw: String, language: Language, context: Set<String>) -> Form {
        var out = Form()
        var adverbs: [String] = []
        let movable = language == .uz ? uzMovable : language == .en ? enMovable : []

        for clause in clauses(of: raw) {
            var text = Grader.normalise(clause)
            guard !text.isEmpty else { continue }
            text = spellNumbers(text, language: language)
            if language == .en { text = englishContractions(text) }
            text = applyRules(text, language: language, context: context)
            var tokens = text.split(separator: " ").map(String.init)
            if language == .uz, let last = tokens.last, last.count > 5, last.hasSuffix("dir") {
                // the bookish copula: `bu kitobdir` is `bu kitob`
                tokens[tokens.count - 1] = String(last.dropLast(3))
            }
            // English never leaves its pronouns out, and the other courses' rules are
            // still to be written: their tokens are compared as they are
            let (kept, dropped) = language == .uz
                ? dropUzbekPronouns(tokens, context: context)
                : (tokens, [])
            out.dropped += dropped
            for token in kept {
                if movable.contains(token) { adverbs.append(token) } else { out.tokens.append(token) }
            }
        }
        // a time word may go anywhere before the verb; keep which ones, not where
        if !adverbs.isEmpty { out.tokens += ["·"] + adverbs.sorted() }
        return out
    }

    /// Splits at punctuation, so "Salom, men…" starts a fresh clause after the comma.
    static func clauses(of raw: String) -> [String] {
        raw.components(separatedBy: CharacterSet(charactersIn: ",;:.!?¡¿…—–()\"«»"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Comparing

    private static func same(_ a: [String], _ b: [String], names: Set<String>) -> Bool {
        guard a.count == b.count else { return false }
        for (mine, theirs) in zip(a, b) where mine != theirs {
            guard names.contains(where: { theirs.hasPrefix($0) }),
                  nameFold(mine) == nameFold(theirs) else { return false }
        }
        return true
    }

    /// Every pronoun she added has to fit: `sening itim` is not "my dog".
    private static func pronounsAgree(_ mine: Form, _ theirs: Form, language: Language) -> Bool {
        let theirWords = Set(theirs.dropped.map(\.word))
        return mine.dropped.allSatisfy { theirWords.contains($0.word) || $0.agrees }
    }

    /// A slip of spelling on top of an otherwise right wording.
    private static func close(_ a: [String], _ b: [String]) -> Bool {
        let x = a.joined(separator: " "), y = b.joined(separator: " ")
        let budget: Int
        switch y.count {
        case 0..<5: budget = 0
        case 5..<12: budget = 1
        default: budget = 2
        }
        if budget > 0, Grader.levenshtein(x, y) <= budget { return true }
        if skeleton(x) == skeleton(y) { return true }
        return x.replacingOccurrences(of: " ", with: "") == y.replacingOccurrences(of: " ", with: "")
    }

    /// The letters learners of these two languages trade for one another: h and x,
    /// q and k, a missing apostrophe, a single consonant for a double one.
    static func skeleton(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "'", with: "")
        t = t.replacingOccurrences(of: "h", with: "x").replacingOccurrences(of: "q", with: "k")
        var out = ""
        for ch in t where ch != out.last { out.append(ch) }
        return out
    }

    // MARK: - Names

    /// Words the course capitalises in mid-sentence: names of people and places.
    static func names(in raw: String, language: Language) -> Set<String> {
        var out = Set<String>()
        var sentenceStart = true
        for piece in raw.split(whereSeparator: { $0 == " " }) {
            let word = String(piece)
            let letters = word.trimmingCharacters(in: CharacterSet.letters.inverted)
            if !sentenceStart, let first = letters.first, first.isUppercase {
                let n = Grader.normalise(letters).split(separator: " ").first.map(String.init) ?? ""
                if n.count > 1, !notNames.contains(n) { out.insert(n) }
            }
            sentenceStart = word.last.map { ".!?".contains($0) } ?? false
        }
        return out
    }

    /// Capitalised out of courtesy, not because they are names.
    private static let notNames: Set<String> = [
        "lei", "la", "le", "lo", "gli", "sua", "suo", "suoi", "sue", "voi", "vostro", "vostra",
        "siz", "sizning", "sizga", "sizni", "sizda", "sizdan", "sizlar",
    ]

    /// Two spellings of the same name look alike here: Claudia / Klaudiya, Marco / Marko.
    static func nameFold(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "'", with: "")
        for (a, b) in [("ph", "f"), ("qu", "k"), ("c", "k"), ("q", "k"), ("y", "i"), ("w", "v")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        var out = ""
        for ch in t where ch != out.last { out.append(ch) }
        return out
    }

    // MARK: - Pronouns

    enum Person { case s1, s2, s3, p1, p2, p3 }

    private static let uzSubject: [String: Person] = [
        "men": .s1, "sen": .s2, "u": .s3, "biz": .p1, "bizlar": .p1,
        "siz": .p2, "sizlar": .p2, "ular": .p3,
    ]
    private static let uzPossessor: [String: Person] = [
        "mening": .s1, "sening": .s2, "uning": .s3, "bizning": .p1,
        "sizning": .p2, "sizlarning": .p2, "ularning": .p3,
    ]
    /// After these a pronoun is the point of the sentence: `men ham`, `sen-chi`,
    /// `u bilan`. It stays.
    private static let uzKeepBefore: Set<String> = [
        "chi", "ham", "esa", "emas", "bilan", "uchun", "kabi", "singari", "haqida",
        "sababli", "tufayli", "orqali", "bo'yicha", "tomonidan", "qadar", "dek",
    ]
    /// `u` is also "that": `u yerda`, `u kuni`.
    private static let uzThatBefore: Set<String> = [
        "yer", "yerda", "yerga", "yerdan", "yoqda", "yoqqa", "yoqdan", "kuni", "kun",
        "paytda", "vaqtda", "vaqt", "payt", "joy", "joyda",
    ]

    private static func dropUzbekPronouns(_ tokens: [String], context: Set<String>)
        -> ([String], [(word: String, agrees: Bool)]) {
        guard tokens.count > 1 else { return (tokens, []) }
        // the prompt said "quel/quella…", so `u` is "that" and not "he"
        let demonstrative = context.contains { $0.hasPrefix("quel") }
        var kept: [String] = []
        var dropped: [(String, Person, Bool)] = []
        for (i, token) in tokens.enumerated() {
            let next = i + 1 < tokens.count ? tokens[i + 1] : nil
            let subject = uzSubject[token], possessor = uzPossessor[token]
            guard let person = subject ?? possessor, let next, !uzKeepBefore.contains(next) else {
                kept.append(token); continue
            }
            if token == "u", i > 0 || demonstrative || uzThatBefore.contains(next) {
                kept.append(token); continue
            }
            dropped.append((token, person, possessor != nil))
        }
        guard !kept.isEmpty else { return (tokens, []) }
        return (kept, dropped.map { ($0.0, uzAgrees($0.1, possessive: $0.2, in: kept)) })
    }

    /// Is there a verb or a noun in the sentence carrying this person's ending?
    private static func uzAgrees(_ person: Person, possessive: Bool, in tokens: [String]) -> Bool {
        let pattern: String
        switch (person, possessive) {
        case (.s3, _), (.p3, _): return true                // no ending to check
        case (.s1, false): pattern = "(man|dim|sam)(mi)?$"
        case (.s2, false): pattern = "(san|ding|sang)(mi)?$"
        case (.p1, false): pattern = "(miz|dik|sak)(mi)?$"
        case (.p2, false): pattern = "(siz|dingiz|sangiz)(lar)?(mi)?$"
        case (.s1, true): pattern = "m(ni|ga|da|dan|ning|dek)?(mi)?$"
        case (.s2, true): pattern = "ng(ni|ga|da|dan|ning|dek)?(mi)?$"
        case (.p1, true): pattern = "miz(ni|ga|da|dan|ning|dek)?(mi)?$"
        case (.p2, true): pattern = "ngiz(ni|ga|da|dan|ning|dek)?(mi)?$"
        }
        return tokens.contains { $0.range(of: pattern, options: .regularExpression) != nil }
    }

    // MARK: - Words that may move

    private static let uzMovable: Set<String> = [
        "bugun", "ertaga", "kecha", "hozir", "endi", "indinga", "doim", "hamisha",
        "ertalab", "kechqurun", "kunduzi", "kechasi",
    ]
    private static let enMovable: Set<String> = [
        "today", "tomorrow", "yesterday", "now", "tonight",
    ]

    // MARK: - Same thing, other words

    private struct Rule {
        let pattern: String
        let template: String
        /// Only when the sentence being translated contains one of these words.
        var when: ((Set<String>) -> Bool)?
    }

    private static let uzRules: [Rule] = [
        // greetings, short and long, however the long one is spelled
        Rule(pattern: #"\bva ?a?l[ae]y?k[ui]m ?(as{1,2}alomu?|salom)\b"#, template: "vaalaykum"),
        Rule(pattern: #"\b(as{1,2}alomu?|as{1,2}alamu?|salom) ?a?l[ae]y?k[ui]m\b"#, template: "salom"),
        Rule(pattern: #"\bhayr\b"#, template: "xayr"),
        // "ciao" is hello and goodbye both, so either answers it
        Rule(pattern: #"\bxayr\b"#, template: "salom", when: { $0.contains("ciao") }),
        Rule(pattern: #"\b(tashakkur|raxmat)\b"#, template: "rahmat"),
        Rule(pattern: #"\b(meni kechiring|meni kechir|kechirasan|kechiring|uzr)\b"#, template: "kechirasiz"),
        // "my name is Claudia" and "I am Claudia" are one introduction
        Rule(pattern: #"\bmening ismim (\S+)$"#, template: "men $1man"),
        Rule(pattern: #"\bismim (\S+)$"#, template: "$1man"),
        // a counted noun takes -ta or not: ikkita kitob = ikki kitob
        Rule(pattern: #"\bbitta\b"#, template: "bir"),
        Rule(pattern: #"\bnechta\b"#, template: "necha"),
        Rule(pattern: #"\b(ikki|uch|to'rt|besh|olti|yetti|sakkiz|to'qqiz|o'n|yigirma|o'ttiz|qirq|ellik|oltmish|yetmish|sakson|to'qson|yuz|ming)ta\b"#, template: "$1"),
        Rule(pattern: #"\bbir (yuz|ming)\b"#, template: "$1"),
    ]

    private static let enRules: [Rule] = [
        // "my name is Claudia" and "I am Claudia" are one introduction
        Rule(pattern: #"\bmy name is\b"#, template: "i am"),
        Rule(pattern: #"\bi am called\b"#, template: "i am"),
        Rule(pattern: #"\bwhat is your name\b"#, template: "what are you called"),
        Rule(pattern: #"\b(hi|hey|hiya)\b"#, template: "hello"),
        Rule(pattern: #"\b(bye|bye bye|see you)\b"#, template: "goodbye"),
        Rule(pattern: #"\b(thank you very much|thanks a lot|many thanks|thanks very much)\b"#,
             template: "thank you very much"),
        Rule(pattern: #"\bthanks\b"#, template: "thank you"),
        Rule(pattern: #"\b(ok|alright|all right)\b"#, template: "okay"),
        Rule(pattern: #"\b(excuse me|pardon me|pardon)\b"#, template: "sorry",
             when: { $0.contains { $0.hasPrefix("kechir") || $0 == "uzr" } }),
        Rule(pattern: #"\bcan not\b"#, template: "cannot"),
    ]

    private static func applyRules(_ text: String, language: Language, context: Set<String>) -> String {
        var s = text
        for rule in language == .uz ? uzRules : language == .en ? enRules : [] {
            if let when = rule.when, !when(context) { continue }
            s = s.replacingOccurrences(of: rule.pattern, with: rule.template, options: .regularExpression)
        }
        return s.split(separator: " ").joined(separator: " ")
    }

    /// I'm → i am, don't → do not — with or without the apostrophe she may have skipped.
    private static func englishContractions(_ text: String) -> String {
        let table: [String: String] = [
            "i'm": "i am", "im": "i am", "you're": "you are", "youre": "you are",
            "he's": "he is", "she's": "she is", "it's": "it is", "its": "it is",
            "we're": "we are", "they're": "they are", "theyre": "they are",
            "i've": "i have", "ive": "i have", "you've": "you have", "we've": "we have",
            "they've": "they have", "i'll": "i will", "you'll": "you will", "he'll": "he will",
            "she'll": "she will", "we'll": "we will", "they'll": "they will", "it'll": "it will",
            "i'd": "i would", "you'd": "you would", "we'd": "we would", "they'd": "they would",
            "don't": "do not", "dont": "do not", "doesn't": "does not", "doesnt": "does not",
            "didn't": "did not", "didnt": "did not", "isn't": "is not", "isnt": "is not",
            "aren't": "are not", "arent": "are not", "wasn't": "was not", "wasnt": "was not",
            "weren't": "were not", "can't": "cannot", "cant": "cannot", "won't": "will not",
            "haven't": "have not", "havent": "have not", "hasn't": "has not", "hadn't": "had not",
            "couldn't": "could not", "shouldn't": "should not", "wouldn't": "would not",
            "mustn't": "must not", "that's": "that is", "thats": "that is", "what's": "what is",
            "whats": "what is", "where's": "where is", "there's": "there is", "here's": "here is",
            "who's": "who is", "how's": "how is", "let's": "let us", "lets": "let us",
        ]
        return text.split(separator: " ")
            .map { table[String($0)] ?? String($0) }
            .joined(separator: " ")
    }

    // MARK: - Numbers in figures

    private static func spellNumbers(_ text: String, language: Language) -> String {
        text.split(separator: " ").map { piece -> String in
            let token = String(piece)
            let digits = token.prefix { $0.isASCII && $0.isNumber }
            guard !digits.isEmpty, let n = Int(digits),
                  let words = language == .uz ? uzbekNumber(n) : language == .en ? englishNumber(n) : nil
            else { return token }
            return words + token.dropFirst(digits.count)
        }.joined(separator: " ")
    }

    private static let uzOnes = ["nol", "bir", "ikki", "uch", "to'rt", "besh", "olti", "yetti", "sakkiz", "to'qqiz"]
    private static let uzTens = ["", "o'n", "yigirma", "o'ttiz", "qirq", "ellik", "oltmish", "yetmish", "sakson", "to'qson"]

    static func uzbekNumber(_ n: Int) -> String? {
        switch n {
        case 0..<10: return uzOnes[n]
        case 10..<100:
            let rest = n % 10
            return uzTens[n / 10] + (rest > 0 ? " " + uzOnes[rest] : "")
        case 100..<1000:
            let head = n / 100 == 1 ? "yuz" : uzOnes[n / 100] + " yuz"
            return n % 100 == 0 ? head : head + " " + (uzbekNumber(n % 100) ?? "")
        case 1000..<10000:
            let head = n / 1000 == 1 ? "ming" : uzOnes[n / 1000] + " ming"
            return n % 1000 == 0 ? head : head + " " + (uzbekNumber(n % 1000) ?? "")
        default: return nil
        }
    }

    private static let enUnder20 = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
                                    "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
                                    "sixteen", "seventeen", "eighteen", "nineteen"]
    private static let enTens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

    static func englishNumber(_ n: Int) -> String? {
        switch n {
        case 0..<20: return enUnder20[n]
        case 20..<100:
            let rest = n % 10
            return enTens[n / 10] + (rest == 0 ? "" : " " + enUnder20[rest])
        case 100..<1000:
            let head = enUnder20[n / 100] + " hundred"
            return n % 100 == 0 ? head : head + " " + (englishNumber(n % 100) ?? "")
        case 1000..<10000:
            let head = enUnder20[n / 1000] + " thousand"
            return n % 1000 == 0 ? head : head + " " + (englishNumber(n % 1000) ?? "")
        default: return nil
        }
    }
}
