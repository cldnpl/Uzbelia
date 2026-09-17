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
    }

    private nonisolated(unsafe) static var index = Index()
    private nonisolated(unsafe) static var loadedKey: String?

    /// Digests a curriculum the first time it is seen; a no-op on every later call.
    static func prime(with pairs: [Pair]) {
        let key = "\(pairs.count)|\(pairs.first?.id ?? "")|\(pairs.last?.id ?? "")"
        guard key != loadedKey else { return }
        var built = Index()
        for lang in Language.allCases {
            var phrases: [String: [String]] = [:]
            var words: [String: [String]] = [:]
            let other = lang.other
            for pair in pairs {
                let value = pair[other]
                let key = Grader.normalise(pair[lang])
                guard !value.isEmpty, !key.isEmpty else { continue }
                insert(value, at: key, into: &phrases)
                if !key.contains(" ") { insert(value, at: key, into: &words) }
            }
            built.phrases[lang] = phrases
            built.words[lang] = words
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
        case .speak:
            out.kind = .type
            out.promptLanguage = answerLanguage.other
            out.prompt = pair[answerLanguage.other]
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
