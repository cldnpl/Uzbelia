import Foundation

enum Verdict: Equatable {
    case correct
    /// Not the wording the course expects, but it means the same thing. Carries the
    /// course's own version and, when there is one, a line saying why it is fine.
    case alternative(canonical: String, note: String?)
    case almost(String)     // accepted, but show the polished spelling
    case wrong(String)      // the expected answer

    var isAccepted: Bool {
        switch self {
        case .correct, .alternative, .almost: return true
        case .wrong: return false
        }
    }
}

enum Grader {

    /// Canonical form used for comparisons: lowercase, folded accents, unified
    /// Uzbek apostrophes (oʻ/o‘/oʼ → o'), no punctuation, single spaces.
    ///
    /// The script decides the rules, read off the text itself, so every caller gets
    /// the right ones without being told which course it is in:
    /// - **Thai** keeps its vowel and tone marks — they are letters, not accents, and
    ///   folding them away would accept the wrong word — and drops spaces, which Thai
    ///   uses for pauses rather than between words;
    /// - **Khmer, Lao and Cantonese** are treated the same way: no spaces, marks kept;
    /// - **Persian, Urdu and Sorani** lose their optional short-vowel marks, write
    ///   Arabic yeh and kaf the Persian way and treat the half-space as a space, the
    ///   way people type it;
    /// - **the Indic scripts, Georgian and Armenian** keep every mark — a vowel sign
    ///   is half the letter — and only lose punctuation;
    /// - Latin and Cyrillic are folded as before.
    static func normalise(_ raw: String) -> String {
        let raw = withoutAnnotations(raw)
        let script = Script.of(raw)
        if script.isUnspaced { return normaliseUnspaced(raw, script: script) }
        if script == .arabic { return normaliseArabicScript(raw) }
        if script.keepsMarks { return normaliseMarked(raw) }
        var s = raw
        for apo in ["\u{2018}", "\u{2019}", "\u{02BB}", "\u{02BC}", "\u{0060}", "\u{00B4}", "\u{2032}"] {
            s = s.replacingOccurrences(of: apo, with: "'")
        }
        s = s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                      locale: Locale(identifier: "en_US_POSIX"))
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "' "))
        s = String(String.UnicodeScalarView(s.unicodeScalars.map { allowed.contains($0) ? $0 : " " }))
        return s.split(separator: " ").joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    private static func normaliseUnspaced(_ raw: String, script: Script) -> String {
        let keep = CharacterSet.alphanumerics
        let scalars = raw.precomposedStringWithCanonicalMapping.unicodeScalars.filter { keep.contains($0) }
        var s = String(String.UnicodeScalarView(scalars)).lowercased()
        // the polite particle says who is speaking, not what is said: ครับ from a man,
        // ค่ะ / คะ from a woman, or none — all three are the same sentence
        if script == .thai {
            for particle in ["ครับ", "ค่ะ", "คะ"] { s = s.replacingOccurrences(of: particle, with: "") }
        }
        return s
    }

    private static func normaliseMarked(_ raw: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in raw.precomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.value {
            case 0x055B...0x055E, 0x200C, 0x200D: continue          // Armenian stress/question marks, joiners
            default:
                if CharacterSet.alphanumerics.contains(scalar) { out.append(scalar) }
                else { out.append(" ") }
            }
        }
        return String(out).lowercased().split(separator: " ").joined(separator: " ")
    }

    private static func normaliseArabicScript(_ raw: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            switch scalar.value {
            case 0x064A, 0x0649: out.append("\u{06CC}")          // Arabic yeh, alef maksura → Persian yeh
            case 0x0643: out.append("\u{06A9}")                  // Arabic kaf → Persian kaf
            case 0x06C1: out.append("\u{0647}")                  // Urdu heh goal → heh
            case 0x064B...0x065F, 0x0670, 0x0640: continue       // short vowels, tatweel
            case 0x200C, 0x200D: out.append(" ")                 // half-space
            case 0x06F0...0x06F9: out.append(Unicode.Scalar(scalar.value - 0x06F0 + 0x30)!)
            case 0x0660...0x0669: out.append(Unicode.Scalar(scalar.value - 0x0660 + 0x30)!)
            default:
                if CharacterSet.alphanumerics.contains(scalar) { out.append(scalar) }
                else { out.append(" ") }
            }
        }
        return String(out).lowercased().split(separator: " ").joined(separator: " ")
    }

    /// Alternatives inside the expected answer can be written as "a / b".
    static func alternatives(_ expected: String) -> [String] {
        expected.components(separatedBy: " / ").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func grade(_ given: String, expected: String, tolerant: Bool = true) -> Verdict {
        let g = normalise(given)
        guard !g.isEmpty else { return .wrong(expected) }
        for alt in alternatives(expected) {
            let e = normalise(alt)
            if g == e { return .correct }
        }
        guard tolerant else { return .wrong(expected) }
        for alt in alternatives(expected) {
            let e = normalise(alt)
            let budget = typoBudget(for: e)
            if budget > 0, levenshtein(g, e) <= budget { return .almost(alt) }
            // forgive a missing/extra apostrophe, a classic Uzbek typo
            if g.replacingOccurrences(of: "'", with: "") == e.replacingOccurrences(of: "'", with: "") {
                return .almost(alt)
            }
        }
        return .wrong(alternatives(expected).first ?? expected)
    }

    private static func typoBudget(for s: String) -> Int {
        switch s.count {
        case 0..<5: return 0
        case 5..<12: return 1
        default: return 2
        }
    }

    /// Ratio of expected words that appear in the transcript — used for speaking.
    static func pronunciationScore(transcript: String, expected: String) -> Double {
        if Script.of(expected).isUnspaced {
            // no words to count in a line without spaces: how close the letters are
            let t = normalise(transcript), e = normalise(expected)
            guard !e.isEmpty else { return 0 }
            return max(0, 1 - Double(levenshtein(t, e)) / Double(e.count))
        }
        let t = normalise(transcript).split(separator: " ").map(String.init)
        let e = normalise(expected).split(separator: " ").map(String.init)
        guard !e.isEmpty else { return 0 }
        var pool = t
        var hits = 0
        for word in e {
            if let idx = pool.firstIndex(where: { $0 == word || levenshtein($0, word) <= (word.count >= 5 ? 1 : 0) }) {
                pool.remove(at: idx); hits += 1
            }
        }
        return Double(hits) / Double(e.count)
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    /// "How are you? (formal)" → "How are you?". Brackets in the course hold notes for
    /// the reader — which "you", which sense of a word — never something to type.
    static func withoutAnnotations(_ text: String) -> String {
        guard text.contains("(") else { return text }
        let stripped = text.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "",
                                                 options: .regularExpression)
        return stripped.trimmingCharacters(in: .whitespaces).isEmpty ? text : stripped
    }

    /// Splits a sentence into chips for the word bank, keeping punctuation attached.
    static func tokenize(_ sentence: String) -> [String] {
        let sentence = withoutAnnotations(sentence)
        let script = Script.of(sentence)
        if script.isUnspaced { return WordSplitter.words(in: sentence, language: script.unspacedLanguage) }
        return sentence.split(separator: " ").map(String.init)
    }

    /// Puts chips back into a sentence, the way the script writes it.
    static func join(_ tokens: [String], like sentence: String) -> String {
        tokens.joined(separator: Script.of(sentence).isUnspaced ? "" : " ")
    }
}

/// Which alphabet a line is written in, judged from its letters.
enum Script: Equatable {
    case latin, cyrillic, thai, lao, khmer, han, arabic, indic, georgian, armenian

    static func of(_ text: String) -> Script {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0E00...0x0E7F: return .thai
            case 0x0E80...0x0EFF: return .lao
            case 0x1780...0x17FF, 0x19E0...0x19FF: return .khmer
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FFFF: return .han
            case 0x0600...0x06FF, 0x0750...0x077F, 0xFB50...0xFDFF, 0xFE70...0xFEFF: return .arabic
            case 0x0900...0x0DFF: return .indic
            case 0x10A0...0x10FF, 0x1C90...0x1CBF: return .georgian
            case 0x0530...0x058F, 0xFB13...0xFB17: return .armenian
            case 0x0400...0x04FF, 0x0500...0x052F: return .cyrillic
            default: continue
            }
        }
        return .latin
    }

    /// Written without spaces between words.
    var isUnspaced: Bool {
        switch self {
        case .thai, .lao, .khmer, .han: return true
        default: return false
        }
    }

    /// Scripts whose marks are letters, not accents: folding them away would accept
    /// a different word.
    var keepsMarks: Bool {
        switch self {
        case .indic, .georgian, .armenian: return true
        default: return false
        }
    }

    /// The course an unspaced line belongs to, for the tokenizer.
    var unspacedLanguage: Language {
        switch self {
        case .lao: return .lo
        case .khmer: return .km
        case .han: return .yue
        default: return .th
        }
    }
}
