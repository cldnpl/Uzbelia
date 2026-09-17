import Foundation

enum Verdict: Equatable {
    case correct
    case almost(String)     // accepted, but show the polished spelling
    case wrong(String)      // the expected answer
}

enum Grader {

    /// Canonical form used for comparisons: lowercase, folded accents, unified
    /// Uzbek apostrophes (oʻ/o‘/oʼ → o'), no punctuation, single spaces.
    static func normalise(_ raw: String) -> String {
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

    /// Splits a sentence into chips for the word bank, keeping punctuation attached.
    static func tokenize(_ sentence: String) -> [String] {
        sentence.split(separator: " ").map(String.init)
    }
}
