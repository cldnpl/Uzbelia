import Foundation

/// Offline dictionary over the whole course, so feedback can always say what the
/// learner just chose, typed or said — not only whether it was right.
///
/// Every option, chip and answer an exercise puts on screen is drawn from the
/// curriculum, so a single index built from the pairs covers all of them. Free text
/// the learner wrote is glossed word by word as a last resort, and flagged as such.
enum Glossary {

    /// A translation, and how much to trust it.
    struct Gloss: Equatable {
        var text: String
        /// True when the phrase itself was unknown and the words were looked up one
        /// by one, so the reading is literal rather than idiomatic.
        var literal: Bool = false
    }

    private struct Index {
        /// norm(phrase) in a language → the translations the course gives it
        var phrases: [Language: [String: [String]]] = [:]
        /// the same for single words, so one word lifted out of a sentence resolves
        var words: [Language: [String: [String]]] = [:]
        /// set expressions of two to four words taught as vocabulary — `xayrli tong`,
        /// `ertaga ko'rishguncha` — which mean something their words do not add up to
        var expressions: [Language: [String: [String]]] = [:]
    }

    private nonisolated(unsafe) static var index = Index()
    private nonisolated(unsafe) static var loadedKey: String?

    /// Digests a curriculum the first time it is seen; a no-op on every later call.
    ///
    /// `vocabulary` is the lessons' word lists: the multi-word entries in it are the
    /// set expressions a tap on one of their words should explain as a whole.
    static func prime(with pairs: [Pair], vocabulary: [Pair] = []) {
        let key = "\(pairs.count)|\(vocabulary.count)|\(pairs.first?.id ?? "")|\(pairs.last?.id ?? "")"
        guard key != loadedKey else { return }
        var built = Index()
        for lang in Language.allCases {
            var phrases: [String: [String]] = [:]
            var words: [String: [String]] = [:]
            var expressions: [String: [String]] = [:]
            let other = lang.other
            for pair in pairs {
                let value = pair[other]
                let key = Grader.normalise(pair[lang])
                guard !value.isEmpty, !key.isEmpty else { continue }
                insert(value, at: key, into: &phrases)
                if !key.contains(" ") { insert(value, at: key, into: &words) }
            }
            for pair in vocabulary {
                let value = pair[other]
                let key = Grader.normalise(pair[lang])
                let count = key.split(separator: " ").count
                guard !value.isEmpty, (2...4).contains(count) else { continue }
                insert(value, at: key, into: &expressions)
            }
            built.phrases[lang] = phrases
            built.words[lang] = words
            built.expressions[lang] = expressions
        }
        index = built
        loadedKey = key
    }

    /// Adds a pair the curriculum files do not hold — story dialogue lines, say.
    static func learn(_ pairs: [Pair]) {
        for lang in Language.allCases {
            let other = lang.other
            var phrases = index.phrases[lang] ?? [:]
            var words = index.words[lang] ?? [:]
            for pair in pairs {
                let value = pair[other]
                let key = Grader.normalise(pair[lang])
                guard !value.isEmpty, !key.isEmpty else { continue }
                insert(value, at: key, into: &phrases)
                if !key.contains(" ") { insert(value, at: key, into: &words) }
            }
            index.phrases[lang] = phrases
            index.words[lang] = words
        }
    }

    private static func insert(_ value: String, at key: String,
                               into table: inout [String: [String]]) {
        var list = table[key] ?? []
        guard !list.contains(value) else { return }
        list.append(value)
        table[key] = list
    }

    /// What `text`, read in `lang`, means. Nil when the course cannot vouch for it.
    static func look(up text: String, from lang: Language) -> Gloss? {
        let key = Grader.normalise(text)
        guard !key.isEmpty else { return nil }
        if let hit = best(key, in: index.phrases[lang]) { return Gloss(text: hit) }
        if let hit = best(key, in: index.words[lang]) { return Gloss(text: hit) }
        return wordByWord(key, from: lang)
    }

    // MARK: - One word, tapped

    /// What a single word means on its own, when the course teaches it.
    static func word(_ text: String, from lang: Language) -> String? {
        let key = Grader.normalise(text)
        guard !key.isEmpty, !key.contains(" ") else { return nil }
        return best(key, in: index.words[lang]) ?? best(key, in: index.phrases[lang])
    }

    /// The set expression a tapped word belongs to, when it belongs to one: the longest
    /// run of two to four words around it that the course teaches as a unit. Never the
    /// sentence it sits in — only the expression.
    static func expression(in words: [String], containing position: Int,
                           from lang: Language) -> (span: ClosedRange<Int>, meaning: String)? {
        guard words.indices.contains(position), let table = index.expressions[lang] else { return nil }
        for length in stride(from: min(4, words.count), through: 2, by: -1) {
            let firstStart = max(0, position - length + 1)
            let lastStart = min(position, words.count - length)
            guard firstStart <= lastStart else { continue }
            for start in firstStart...lastStart {
                let span = start...(start + length - 1)
                let key = Grader.normalise(words[span].joined(separator: " "))
                if let hit = best(key, in: table) { return (span, hit) }
            }
        }
        return nil
    }

    /// The dictionary form of an inflected word the course does not list on its own,
    /// with what that form means: `bordim` → `bormoq`, «andare»; `kitoblarim` → `kitob`;
    /// `parliamo` → `parlare`. Only a reading the endings fully account for is offered,
    /// so a guess never passes for a fact — and the screen says it is the base form.
    static func base(of text: String, from lang: Language) -> (base: String, meaning: String)? {
        let key = Grader.normalise(text)
        guard key.count >= 4, !key.contains(" "), let words = index.words[lang] else { return nil }
        switch lang {
        case .uz:
            // the longest root whose remainder is nothing but known endings
            for cut in stride(from: key.count - 1, through: 2, by: -1) {
                let root = String(key.prefix(cut))
                let rest = String(key.dropFirst(cut))
                // a two-letter root (`uy`, `ot`) only with a real ending after it:
                // `uyda` is "a casa", but `ota` is not "cavallo" plus an `a`
                guard uzbekEndings(rest), root.count >= 3 || rest.count >= 2 else { continue }
                // a verb ending reads the root as a verb first: `bordim` is "andai"
                // from `bormoq`, not "c'è" from `bor`
                let verbal = uzbekVerbEndings.contains { rest.hasPrefix($0) }
                let forms = verbal ? [root + "moq", root + "mak", root] : [root, root + "moq", root + "mak"]
                for form in forms {
                    if let hit = words[form]?.first { return (form, hit) }
                }
            }
            return nil
        case .en:
            // plurals, past tenses, -ing, the possessive 's
            for ending in ["'s", "ies", "es", "s", "ied", "ed", "ing", "d"] where key.hasSuffix(ending)
                && key.count - ending.count >= 3 {
                let root = String(key.dropLast(ending.count))
                for form in [root, root + "e", root + "y"] {
                    if let hit = words[form]?.first, form != key { return (form, hit) }
                }
            }
            return nil
        default:
            // the other courses' endings are still to be taught to the glossary
            return nil
        }
    }

    /// The endings an Uzbek word can carry after its root: plural, possessive, case,
    /// person, tense. Enough to read most inflected forms back to the word the course
    /// teaches, and strict enough that a random tail is not mistaken for one.
    private static let uzbekSuffixes: [String] = [
        "lar", "imiz", "ingiz", "miz", "ngiz", "im", "ing", "ning", "si", "i", "m", "ng",
        "dagi", "gacha", "dan", "da", "ga", "ka", "qa", "ni", "cha", "dek", "day", "li", "lik", "siz",
        "moq", "dim", "ding", "dik", "dingiz", "dilar", "di", "yapman", "yapsan", "yapti", "yapmiz",
        "yapsiz", "yap", "aman", "asan", "adi", "amiz", "asiz", "yman", "ysan", "ydi", "ymiz", "ysiz",
        "man", "san", "gan", "ib", "ish", "ma", "may", "mas", "sa", "gin", "ay", "a", "y", "u", "chi"
    ]

    private static let uzbekVerbEndings: [String] = [
        "moq", "dim", "ding", "dik", "dingiz", "dilar", "di", "yap", "aman", "asan", "adi", "amiz",
        "asiz", "yman", "ysan", "ydi", "ymiz", "ysiz", "gan", "ib", "ish", "may", "mas", "sa", "gin"
    ]

    private static func uzbekEndings(_ rest: String) -> Bool {
        if rest.isEmpty { return true }
        return uzbekSuffixes.contains { rest.hasPrefix($0) && uzbekEndings(String(rest.dropFirst($0.count))) }
    }

    /// At most two readings: a third turns the banner into a dictionary entry.
    private static func best(_ key: String, in table: [String: [String]]?) -> String? {
        guard let list = table?[key], !list.isEmpty else { return nil }
        return list.prefix(2).joined(separator: " / ")
    }

    /// Only when every single word is known: half a translation is worse than none.
    private static func wordByWord(_ key: String, from lang: Language) -> Gloss? {
        let parts = key.split(separator: " ").map(String.init)
        guard parts.count > 1, parts.count <= 8 else { return nil }
        var out: [String] = []
        for word in parts {
            guard let hit = index.words[lang]?[word]?.first
                        ?? index.phrases[lang]?[word]?.first else { return nil }
            out.append(hit)
        }
        return Gloss(text: out.joined(separator: " "), literal: true)
    }
}

// MARK: - Reading an exercise back

extension Exercise {

    /// The solution as it deserves to be read back: a fill-in-the-blank only makes
    /// sense as the finished sentence, everything else as its own answer.
    var solution: String {
        kind == .fillBlank ? pair[answerLanguage] : answer
    }

    /// The same item asked without the skill she has just put on hold.
    ///
    /// A queued question is not thrown away — a pronunciation becomes a written
    /// translation, a dictation becomes a translation from her own language — so a
    /// lesson keeps its length and still teaches the word.
    func withoutAudio(native: Language) -> Exercise {
        var out = self
        switch kind {
        case .speak, .speakRepeat:
            out.kind = .type
            out.promptLanguage = answerLanguage.other
            out.prompt = pair[answerLanguage.other]
        case .listenMeaning:
            // the same question with the sentence written instead of spoken
            out.kind = .choice
            out.promptLanguage = native.other
            out.prompt = pair[native.other]
        case .listenBuild:
            out.kind = .wordBank
            out.promptLanguage = native
            out.prompt = pair[native]
        case .listenType:
            out.kind = .type
            out.promptLanguage = native
            out.prompt = pair[native]
        case .listenChoice:
            out.kind = .choice
            out.promptLanguage = native
            out.prompt = pair[native]
        default:
            return out
        }
        out.audioText = nil
        out.audioLanguage = nil
        return out
    }

    /// What `text` means, read in the language this question is answered in.
    ///
    /// The exercise's own pair is consulted first, so a story line the curriculum
    /// files never list still gets a translation.
    func meaning(of text: String) -> Glossary.Gloss? {
        let lang = answerLanguage
        let key = Grader.normalise(text)
        guard !key.isEmpty else { return nil }
        let mine = Grader.alternatives(pair[lang]).map(Grader.normalise)
        if mine.contains(key), !pair[lang.other].isEmpty {
            return Glossary.Gloss(text: pair[lang.other])
        }
        return Glossary.look(up: text, from: lang)
    }
}
