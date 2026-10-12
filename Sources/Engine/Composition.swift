import Foundation

// MARK: - The brief

/// A short piece of writing: two to four sentences she puts together herself.
///
/// Every other writing exercise asks for one sentence that already exists. This one
/// asks for a text — a few things to say, in her own order and her own words — and
/// then corrects it the way a teacher would, a little at a time: first it only points
/// at what is wrong, then it gives a clue, and only at the end does it show the fix.
///
/// The things to say are the course's own sentences, so the text can always be
/// written with words she has already studied, and the checker always has a model
/// to measure it against — offline too.
struct CompositionTask: Hashable {
    /// One line per thing to say: her own language, and the course's way of saying it.
    var outline: [Pair]
    /// The opening words, already in the box: the "input" she carries on from.
    var starter: String
    /// Studied words the text needs, offered as taps.
    var wordBank: [String]
    /// Below this the text is not a text yet, and the check stays off.
    var minimumWords: Int
    /// From A2 on, one more sentence of her own is welcome; it is checked for
    /// spelling and grammar, never marked as "extra".
    var invitesOwnSentence: Bool
    var level: CEFR
    var native: Language

    var target: Language { native.other }
    /// The whole model text, in the language she is learning.
    var model: String { outline.map { $0[target] }.joined(separator: " ") }
}

enum CompositionPlanner {

    /// How many things to say, by level: enough to be a text, few enough that the
    /// exercise is still a couple of minutes and not a homework.
    static func pointCount(for level: CEFR) -> Int {
        switch level {
        case .a1, .a2: return 2
        case .b1, .b2: return 3
        }
    }

    /// Builds a brief from a lesson's sentences. Returns nil when there are not
    /// enough real sentences to make a text of.
    ///
    /// `familiarity` steers it towards the sentences she has met least, so two
    /// writing passes over the same lesson rarely ask for the same text.
    static func task(sentences: [Pair],
                     native: Language,
                     level: CEFR,
                     familiarity: (Pair) -> Int = { _ in 0 }) -> CompositionTask? {
        let target = native.other
        let band = AIClient.lengthBand(for: level)
        var seen = Set<String>()
        let usable = sentences.filter { pair in
            let words = pair.wordCount(target)
            guard words >= 3, words <= band.max + 3,
                  !pair[native].isEmpty, !pair[target].contains(" / ") else { return false }
            return seen.insert(Grader.normalise(pair[target])).inserted
        }
        let wanted = pointCount(for: level)
        guard usable.count >= wanted else { return nil }

        let outline = Array(usable
            .map { ($0, familiarity($0), Int.random(in: 0..<1_000_000)) }
            .sorted { ($0.1, $0.2) < ($1.1, $1.2) }
            .prefix(wanted)
            .map(\.0))

        // the opening third of the first sentence, at most two words: a start, not
        // half the answer
        let first = Grader.tokenize(outline[0][target])
        let starterCount = min(2, max(1, first.count / 3))
        let starter = first.prefix(starterCount).joined(separator: " ")
        let starterKeys = Set(first.prefix(starterCount).map(Grader.normalise))

        var bankSeen = Set<String>()
        let bank = outline.flatMap { Grader.tokenize($0[target]) }
            .map(trimPunctuation)
            .filter { word in
                let key = Grader.normalise(word)
                guard key.count > 1, !starterKeys.contains(key) else { return false }
                return bankSeen.insert(key).inserted
            }
            .shuffled()

        let total = outline.reduce(0) { $0 + $1.wordCount(target) }
        return CompositionTask(outline: outline,
                               starter: starter,
                               wordBank: Array(bank.prefix(10)),
                               minimumWords: max(3, Int(Double(total) * 0.6)),
                               invitesOwnSentence: level >= .a2,
                               level: level,
                               native: native)
    }

    /// "Salom," → "Salom": a chip is a word, not a word and its comma.
    static func trimPunctuation(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet.punctuationCharacters
            .subtracting(CharacterSet(charactersIn: "'\u{2019}\u{02BB}\u{02BC}")))
    }
}

// MARK: - What the checker found

struct CompositionIssue: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case spelling       // the right word, misspelt
        case word           // a different word from the one that belongs there
        case missingWord    // a word left out
        case extraWord      // a word that does not belong
        case order          // the right words in the wrong order
        case missingPart    // one of the things to say is not there at all
        case grammar        // a known grammar slip, in a sentence of her own
        case language       // written in her own language instead

        var icon: String {
            switch self {
            case .spelling: return "textformat.abc"
            case .word: return "arrow.left.arrow.right"
            case .missingWord: return "plus.circle"
            case .extraWord: return "minus.circle"
            case .order: return "arrow.up.arrow.down"
            case .missingPart: return "text.badge.plus"
            case .grammar: return "text.badge.checkmark"
            case .language: return "globe"
            }
        }
    }

    let id = UUID()
    var kind: Kind
    /// Where it sits in the text that was checked. Nil for something missing.
    var range: Range<String.Index>?
    /// Where a missing word belongs, for the caret drawn into the text.
    var insertAt: String.Index?
    /// What she wrote there ("" when something is missing).
    var fragment: String
    /// What it should be.
    var fix: String
    /// The word a missing one goes after, so the clue can say where.
    var anchor: String?
    /// The thing she was asked to say, in her own language, for a missing part.
    var point: String?
    /// A line of explanation, when the checker has one.
    var why: Bilingual?
    /// A first clue written by the assistant, which knows better than a template.
    var customHint: String?

    /// The clue for this round. The first only says where to look, the second gives
    /// the opening letters, and from the third on — or once she asks — the fix itself.
    func hint(round: Int, native: Language, revealed: Bool = false) -> String {
        if revealed || round >= 3 { return solution(native: native) }
        let start = Self.opening(of: fix)
        if round >= 2 {
            switch kind {
            case .spelling, .word:
                return "The word here starts with “\(start)…”."
            case .missingWord:
                let place = anchor.map { "After “\($0)”" } ?? "At the start"
                return "\(place) a word is missing: it starts with “\(start)…”."
            case .extraWord:
                return "Take out “\(fragment)”: the sentence works without it."
            case .order:
                let head = Grader.tokenize(fix).prefix(2).joined(separator: " ")
                return "Try starting like this: “\(head)…”."
            case .missingPart:
                let head = Grader.tokenize(fix).prefix(1).joined(separator: " ")
                if let point { return "You still haven't said “\(point)”. Start with “\(head)…”." }
                return "Add the missing part: start with “\(head)…”."
            case .grammar, .language:
                return firstHint(native: native)
            }
        }
        return firstHint(native: native)
    }

    private func firstHint(native: Language) -> String {
        if let customHint, !customHint.isEmpty { return customHint }
        switch kind {
        case .spelling: return "Check how “\(fragment)” is spelled."
        case .word: return "“\(fragment)” isn't the right word here."
        case .missingWord:
            if let anchor { return "A word is missing after “\(anchor)”." }
            return "A word is missing at the start of the sentence."
        case .extraWord: return "“\(fragment)” is one word too many here."
        case .order: return "The words are there, but the order is off."
        case .missingPart:
            guard let point else { return "One of the things to say is missing." }
            return "You haven't said yet: “\(point)”."
        case .grammar: return why?[native] ?? "There's a grammar mistake here."
        case .language: return "This sentence is in English: try writing it in \(Language.current.name)."
        }
    }

    /// The fix, said plainly.
    func solution(native: Language) -> String {
        switch kind {
        case .missingWord:
            if let anchor { return "After “\(anchor)”, write “\(fix)”." }
            return "At the start, write “\(fix)”."
        case .extraWord: return "Take out “\(fragment)”."
        case .missingPart: return "Add: “\(fix)”."
        default: return "“\(fragment)” → “\(fix)”"
        }
    }

    /// The first letter or two of a word, enough to jog the memory and no more.
    static func opening(of word: String) -> String {
        let clean = CompositionPlanner.trimPunctuation(Grader.tokenize(word).first ?? word)
        let count = clean.count >= 6 ? 2 : 1
        return String(clean.prefix(count))
    }
}

struct CompositionReport: Hashable {
    enum Source: Hashable { case local, ai }
    /// The text this report is about: every range points into it.
    var text: String
    var issues: [CompositionIssue]
    /// The text with everything fixed, for the moment she asks to see it.
    var corrected: String
    var source: Source = .local

    var isClean: Bool { issues.isEmpty }
}

// MARK: - The offline checker

/// Measures what she wrote against the model text, a word at a time, and reports
/// only what it can point at: a misspelt word, a wrong one, a missing one, one too
/// many, the right words in the wrong order, or a whole thing left unsaid.
///
/// Her own wording is not a mistake. Every sentence is first compared as a whole with
/// `Equivalence`, the same rules that accept "itim" for "mening itim" in a translation,
/// and a sentence that says the same thing is left alone. A sentence of her own that
/// matches nothing in the brief is welcome too: it is read for spelling and grammar
/// and otherwise taken as it is.
enum CompositionChecker {

    struct Token {
        let raw: String
        let norm: String
        let range: Range<String.Index>
        let sentence: Int
    }

    static func check(_ text: String, task: CompositionTask, curriculum: Curriculum?) -> CompositionReport {
        let target = task.target
        let mine = tokens(in: text)
        let refs = task.outline.map { normalisedWords($0[target]) }

        // the model as one stream, each word tagged with the sentence it belongs to
        var model: [(norm: String, ref: Int, index: Int)] = []
        for (r, words) in refs.enumerated() {
            for (i, w) in words.enumerated() { model.append((w, r, i)) }
        }
        let ops = align(mine.map(\.norm), model.map(\.norm))

        // which user words each model sentence ended up with
        var spanOfRef: [Int: [Int]] = [:]          // ref -> user token indices
        var lastRef = 0
        var lastSentence: Int?                      // the sentence of her last placed word
        var pending: [Int] = []                     // extra words waiting for a home
        var issuesByRef: [Int: [CompositionIssue]] = [:]
        var missingByRef: [Int: [Int]] = [:]        // ref -> model indices missing
        var extras: [Int] = []

        func adopt(_ u: Int, into ref: Int) { spanOfRef[ref, default: []].append(u) }
        // an extra word belongs with the words of its own sentence: the one before it
        // when they share a sentence, the one after it otherwise
        func flush(next ref: Int) {
            for p in pending {
                adopt(p, into: mine[p].sentence == lastSentence ? lastRef : ref)
                extras.append(p)
            }
            pending = []
        }

        for op in ops {
            switch op {
            case .equal(let u, let m):
                let ref = model[m].ref
                flush(next: ref)
                adopt(u, into: ref)
                lastRef = ref
                lastSentence = mine[u].sentence
            case .substitute(let u, let m):
                let ref = model[m].ref
                flush(next: ref)
                adopt(u, into: ref)
                lastRef = ref
                lastSentence = mine[u].sentence
                let given = mine[u], wanted = task.outline[ref][target]
                let fix = rawWord(model[m].index, of: wanted)
                let close = Grader.levenshtein(given.norm, model[m].norm)
                    <= max(1, model[m].norm.count / 4)
                issuesByRef[ref, default: []].append(CompositionIssue(
                    kind: close ? .spelling : .word,
                    range: given.range, fragment: given.raw, fix: fix))
            case .extra(let u):
                pending.append(u)
            case .missing(let m):
                flush(next: model[m].ref)
                missingByRef[model[m].ref, default: []].append(m)
            }
        }
        flush(next: lastRef)

        // a run of extra words that is a whole sentence of hers is her own sentence
        let sentenceIDs = Set(mine.map(\.sentence))
        var ownSentences = Set<Int>()
        for s in sentenceIDs {
            let members = mine.indices.filter { mine[$0].sentence == s }
            if members.count >= 2, members.allSatisfy({ extras.contains($0) }) { ownSentences.insert(s) }
        }
        let extraSet = Set(extras)
        for u in extras where !ownSentences.contains(mine[u].sentence) {
            let ref = spanOfRef.first { $0.value.contains(u) }?.key ?? lastRef
            issuesByRef[ref, default: []].append(CompositionIssue(
                kind: .extraWord, range: mine[u].range, fragment: mine[u].raw, fix: ""))
        }
        for (ref, members) in spanOfRef {
            spanOfRef[ref] = members.filter { !(extraSet.contains($0) && ownSentences.contains(mine[$0].sentence)) }
        }

        var issues: [CompositionIssue] = []
        var cleanRenderings: [Int: String] = [:]

        for (r, pair) in task.outline.enumerated() {
            let wanted = pair[target]
            let members = (spanOfRef[r] ?? []).sorted()
            let missing = missingByRef[r] ?? []

            // nothing of it there at all: one issue for the whole sentence
            if members.isEmpty || (missing.count == refs[r].count) {
                issues.append(CompositionIssue(kind: .missingPart, fragment: "", fix: wanted,
                                               point: pair[task.native]))
                continue
            }

            // her sentence as she wrote it, its closing punctuation included
            var end = mine[members.last!].range.upperBound
            while end < text.endIndex, ".!?,;:".contains(text[end]) { end = text.index(after: end) }
            let rendering = String(text[mine[members.first!].range.lowerBound..<end])

            // said in her own way, or right as it is
            switch Grader.grade(rendering, expected: wanted, tolerant: false) {
            case .correct:
                cleanRenderings[r] = rendering
                continue
            default: break
            }
            if case .same? = Equivalence.compare(rendering, with: wanted, in: target, prompt: pair[task.native]) {
                cleanRenderings[r] = rendering
                continue
            }

            // the right words, shuffled
            let mineSorted = members.map { mine[$0].norm }.sorted()
            if mineSorted == refs[r].sorted(), members.map({ mine[$0].norm }) != refs[r] {
                issues.append(CompositionIssue(
                    kind: .order,
                    range: mine[members.first!].range.lowerBound..<mine[members.last!].range.upperBound,
                    fragment: rendering, fix: wanted))
                continue
            }

            var found = issuesByRef[r] ?? []
            for m in missing {
                let index = model[m].index
                // the word it goes after: the nearest earlier model word she did write
                let before = members.last { u in
                    guard let pos = refs[r].firstIndex(of: mine[u].norm) else { return false }
                    return pos < index
                }
                found.append(CompositionIssue(
                    kind: .missingWord,
                    insertAt: before.map { mine[$0].range.upperBound } ?? mine[members.first!].range.lowerBound,
                    fragment: "", fix: rawWord(index, of: wanted),
                    anchor: before.map { CompositionPlanner.trimPunctuation(mine[$0].raw) }))
            }
            // a dropped pronoun or a short greeting is not worth a note: if the
            // sentence is still "nearly" the model, keep only the spelling slips
            if case .nearly? = Equivalence.compare(rendering, with: wanted, in: target, prompt: pair[task.native]) {
                found = found.filter { $0.kind == .spelling }
            }
            if found.isEmpty { cleanRenderings[r] = rendering }
            issues += found
        }

        // her own sentences: spelling and the grammar rules, nothing else
        let lexicon = curriculum.map(cachedLexicon)
        for s in ownSentences.sorted() {
            let members = mine.filter { $0.sentence == s }
            guard let first = members.first, let last = members.last else { continue }
            let sentence = String(text[first.range.lowerBound..<last.range.upperBound])
            if let lexicon {
                let inNative = members.filter { lexicon.knows($0.norm, language: task.native)
                                                && !lexicon.knows($0.norm, language: target) }.count
                if inNative * 2 > members.count {
                    issues.append(CompositionIssue(kind: .language,
                                                   range: first.range.lowerBound..<last.range.upperBound,
                                                   fragment: sentence, fix: ""))
                    continue
                }
                for token in members where token.norm.count >= 4 && !lexicon.knows(token.norm, language: target) {
                    if let near = lexicon.nearest(token.norm, language: target) {
                        issues.append(CompositionIssue(kind: .spelling, range: token.range,
                                                       fragment: token.raw, fix: near))
                    }
                }
            }
            for rule in CallReviewer.grammarChecks(Grader.normalise(sentence), target: target) {
                let range = text.range(of: rule.original, options: [.caseInsensitive, .diacriticInsensitive],
                                       range: first.range.lowerBound..<last.range.upperBound)
                issues.append(CompositionIssue(kind: .grammar, range: range,
                                               fragment: rule.original, fix: rule.suggestion, why: rule.note))
            }
        }

        // the text with everything fixed, for when she asks to see it
        var corrected: [String] = []
        for (r, pair) in task.outline.enumerated() {
            corrected.append(cleanRenderings[r] ?? pair[target])
        }
        for s in ownSentences.sorted() {
            let members = mine.filter { $0.sentence == s }
            var words = members.map(\.raw)
            for issue in issues where issue.kind == .spelling {
                if let i = members.firstIndex(where: { $0.range == issue.range }) { words[i] = issue.fix }
            }
            corrected.append(words.joined(separator: " "))
        }

        // in reading order: the order of the text, and what is missing last
        issues.sort { a, b in
            let pa = a.range?.lowerBound ?? a.insertAt ?? text.endIndex
            let pb = b.range?.lowerBound ?? b.insertAt ?? text.endIndex
            return pa < pb
        }
        return CompositionReport(text: text, issues: issues,
                                 corrected: punctuate(corrected).joined(separator: " "))
    }

    /// Ends every sentence with a full stop when it has nothing of its own.
    private static func punctuate(_ sentences: [String]) -> [String] {
        sentences.map { s in
            let t = s.trimmingCharacters(in: .whitespaces)
            guard let last = t.last else { return t }
            return ".!?".contains(last) ? t : t + "."
        }
    }

    // MARK: - Words and sentences

    static func tokens(in text: String) -> [Token] {
        var out: [Token] = []
        var sentence = 0
        var start: String.Index?
        var i = text.startIndex
        // the word itself, without the punctuation stuck to it: «baquvat», not «baquvat.»
        let keep = CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "'\u{2019}\u{02BB}\u{02BC}"))
        func isPunctuation(_ c: Character) -> Bool {
            c.unicodeScalars.allSatisfy { keep.contains($0) }
        }
        func close(_ end: String.Index) {
            guard let s = start else { return }
            let raw = String(text[s..<end])
            var lo = s, hi = end
            while lo < hi, isPunctuation(text[lo]) { lo = text.index(after: lo) }
            while hi > lo, isPunctuation(text[text.index(before: hi)]) { hi = text.index(before: hi) }
            let word = String(text[lo..<hi])
            let norm = Grader.normalise(word)
            if !norm.isEmpty { out.append(Token(raw: word, norm: norm, range: lo..<hi, sentence: sentence)) }
            if let last = raw.last, ".!?;\n".contains(last) { sentence += 1 }
            start = nil
        }
        while i < text.endIndex {
            let c = text[i]
            if c == " " || c == "\n" || c == "\t" {
                close(i)
                if c == "\n" { sentence += 1 }
            } else if start == nil {
                start = i
            }
            i = text.index(after: i)
        }
        close(text.endIndex)
        return out
    }

    static func normalisedWords(_ sentence: String) -> [String] {
        Grader.tokenize(sentence).map(Grader.normalise).filter { !$0.isEmpty }
    }

    /// The model's own spelling of its n-th (meaningful) word, punctuation trimmed.
    private static func rawWord(_ index: Int, of sentence: String) -> String {
        let words = Grader.tokenize(sentence).filter { !Grader.normalise($0).isEmpty }
        guard words.indices.contains(index) else { return "" }
        return CompositionPlanner.trimPunctuation(words[index])
    }

    // MARK: - Alignment

    enum Op: Equatable {
        case equal(Int, Int)
        case substitute(Int, Int)
        case extra(Int)        // in her text, not in the model
        case missing(Int)      // in the model, not in her text
    }

    /// A word-level edit script between her text and the model: the longest run of
    /// words they share, with whatever sits between paired up as substitutions when
    /// there is one of each, and left as extra or missing otherwise.
    static func align(_ a: [String], _ b: [String]) -> [Op] {
        let n = a.count, m = b.count
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
                }
            }
        }
        var raw: [Op] = []
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] { raw.append(.equal(i, j)); i += 1; j += 1 }
            else if lcs[i + 1][j] >= lcs[i][j + 1] { raw.append(.extra(i)); i += 1 }
            else { raw.append(.missing(j)); j += 1 }
        }
        while i < n { raw.append(.extra(i)); i += 1 }
        while j < m { raw.append(.missing(j)); j += 1 }

        // pair up the extras and the missing words found between two matches
        var out: [Op] = []
        var k = 0
        while k < raw.count {
            if case .equal = raw[k] { out.append(raw[k]); k += 1; continue }
            var extras: [Int] = [], missing: [Int] = []
            while k < raw.count {
                if case .extra(let x) = raw[k] { extras.append(x) }
                else if case .missing(let y) = raw[k] { missing.append(y) }
                else { break }
                k += 1
            }
            let pairs = min(extras.count, missing.count)
            for p in 0..<pairs { out.append(.substitute(extras[p], missing[p])) }
            for x in extras.dropFirst(pairs) { out.append(.extra(x)) }
            for y in missing.dropFirst(pairs) { out.append(.missing(y)) }
        }
        return out
    }

    // MARK: - The lexicon, built once

    private nonisolated(unsafe) static var lexiconCache: (count: Int, lexicon: Lexicon)?

    private static func cachedLexicon(_ curriculum: Curriculum) -> Lexicon {
        let count = curriculum.allPairs.count
        if let cached = lexiconCache, cached.count == count { return cached.lexicon }
        let built = Lexicon(curriculum: curriculum)
        lexiconCache = (count, built)
        return built
    }
}
