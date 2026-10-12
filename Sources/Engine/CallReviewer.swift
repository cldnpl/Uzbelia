import Foundation

// MARK: - What the learner actually said

struct CallTurnRecord: Hashable {
    var question: Bilingual
    var answer: String
    var seconds: Int
    var typed: Bool
}

// MARK: - The report

struct Correction: Hashable, Identifiable {
    enum Kind: String, Hashable {
        case spelling, grammar, wording, language
        var icon: String {
            switch self {
            case .spelling: return "textformat.abc"
            case .grammar: return "text.badge.checkmark"
            case .wording: return "wand.and.stars"
            case .language: return "globe"
            }
        }
        var label: Bilingual {
            switch self {
            case .spelling: return Bilingual("Spelling")
            case .grammar: return Bilingual("Grammar")
            case .wording: return Bilingual("More natural")
            case .language: return Bilingual("Language")
            }
        }
    }
    var id: String { "\(kind.rawValue)|\(original)|\(suggestion)" }
    var kind: Kind
    var original: String
    var suggestion: String
    var note: Bilingual
}

struct TurnReview: Identifiable, Hashable {
    enum Status: String, Hashable { case skipped, wrongLanguage, tooShort, good }
    let id = UUID()
    var question: Bilingual
    var said: String
    var status: Status
    var corrections: [Correction]
    /// A fuller, more idiomatic way to say the same thing, taken from the course.
    var betterVersion: String?
}

struct CallStats: Hashable {
    var answered = 0
    var total = 0
    var words = 0
    var distinctWords = 0
    var averageWords = 0.0
    var targetLanguageRatio = 1.0
    var seconds = 0
}

struct CallReview {
    enum Source: String { case local, ai }
    var turns: [TurnReview]
    var stats: CallStats
    var headline: Bilingual
    var tips: [Bilingual]
    var source: Source = .local

    var corrections: [Correction] { turns.flatMap(\.corrections) }
    var goodAnswers: Int { turns.filter { $0.status == .good }.count }
}

// MARK: - The offline reviewer

/// Reads back everything the learner said and produces the end-of-call report:
/// spelling slips, the handful of grammar mistakes that really matter for this
/// language pair, and a more natural way to say the same thing.
///
/// It is a corpus + rules checker, not a parser: it only reports what it can
/// actually justify, and stays silent when unsure.
enum CallReviewer {

    static func review(turns: [CallTurnRecord],
                       target: Language,
                       curriculum: Curriculum,
                       level: CEFR) -> CallReview {
        let native = Language.en
        let lexicon = Lexicon(curriculum: curriculum)
        var reviews: [TurnReview] = []
        var stats = CallStats()
        stats.total = turns.count

        var allWords: [String] = []
        var targetHits = 0, nativeHits = 0

        for turn in turns {
            stats.seconds += turn.seconds
            let said = Grader.normalise(turn.answer)
            let words = WordSplitter.words(in: turn.answer, language: target)
                .map(Grader.normalise).filter { !$0.isEmpty }

            guard !words.isEmpty else {
                reviews.append(TurnReview(question: turn.question, said: "",
                                          status: .skipped, corrections: []))
                continue
            }

            stats.answered += 1
            allWords += words

            let inTarget = words.filter { lexicon.knows($0, language: target) }.count
            let inNative = words.filter {
                lexicon.knows($0, language: native) && !lexicon.knows($0, language: target)
            }.count
            targetHits += inTarget
            nativeHits += inNative

            var corrections: [Correction] = []
            var status: TurnReview.Status = .good

            // 1. Did they answer in the wrong language?
            if inNative > inTarget, inNative >= 2 {
                status = .wrongLanguage
                corrections.append(Correction(
                    kind: .language,
                    original: turn.answer,
                    suggestion: "",
                    note: Bilingual("You answered in English: try saying it in \(target.name), even with mistakes.")))
            } else {
                // 2. Spelling: words that are one or two letters away from a real one.
                corrections += spellingChecks(words: words, lexicon: lexicon, language: target)
                // 3. The grammar mistakes that matter for this direction.
                corrections += grammarChecks(said, target: target)
                // 4. Too short to count as a real answer?
                let minimum = level <= .a2 ? 3 : 5
                if words.count < minimum { status = .tooShort }
            }

            let better = naturalVersion(for: said, words: words,
                                        lexicon: lexicon, language: target)
            if let better, status == .good || status == .tooShort {
                corrections.append(Correction(
                    kind: .wording,
                    original: turn.answer,
                    suggestion: better,
                    note: Bilingual("From the course, a more natural way to say it.")))
            }

            reviews.append(TurnReview(question: turn.question,
                                      said: turn.answer,
                                      status: status,
                                      corrections: corrections,
                                      betterVersion: better))
        }

        stats.words = allWords.count
        stats.distinctWords = Set(allWords).count
        stats.averageWords = stats.answered == 0 ? 0 : Double(stats.words) / Double(stats.answered)
        let recognised = targetHits + nativeHits
        stats.targetLanguageRatio = recognised == 0 ? 1 : Double(targetHits) / Double(recognised)

        return CallReview(turns: reviews,
                          stats: stats,
                          headline: headline(for: reviews, stats: stats),
                          tips: tips(for: reviews, stats: stats, target: target, level: level))
    }

    // MARK: - Spelling

    private static func spellingChecks(words: [String],
                                       lexicon: Lexicon,
                                       language: Language) -> [Correction] {
        var out: [Correction] = []
        for word in words where word.count >= 4 && !lexicon.knows(word, language: language) {
            guard out.count < 3 else { break }
            guard let near = lexicon.nearest(word, language: language) else { continue }
            out.append(Correction(
                kind: .spelling,
                original: word,
                suggestion: near,
                note: Bilingual("Did you mean “\(near)”?")))
        }
        return out
    }

    // MARK: - Grammar

    private struct Rule {
        let pattern: String
        let replacement: String
        let note: Bilingual
    }

    /// Also read by the composition checker, for the sentences she adds of her own.
    static func grammarChecks(_ text: String, target: Language) -> [Correction] {
        let rules = target == .uz ? uzbekRules : []
        var out: [Correction] = []
        for rule in rules {
            guard out.count < 4 else { break }
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: []) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  let matched = Range(match.range, in: text) else { continue }
            let original = String(text[matched])
            let suggestion = regex.stringByReplacingMatches(
                in: original,
                options: [],
                range: NSRange(original.startIndex..., in: original),
                withTemplate: rule.replacement)
            guard suggestion != original else { continue }
            out.append(Correction(kind: .grammar, original: original,
                                  suggestion: suggestion, note: rule.note))
        }
        return out
    }

    /// Mistakes learners of Uzbek reliably make.
    private static let uzbekRules: [Rule] = [
        Rule(pattern: "\\b((?:bir|ikki|uch|to'rt|besh|olti|yetti|sakkiz|to'qqiz|o'n|nechta|necha|ko'p)(?:ta)?)\\s+(\\w+?)lar\\b",
             replacement: "$1 $2",
             note: Bilingual("After a number or a quantity the noun stays singular: no -lar.")),
        Rule(pattern: "\\b(\\w+)\\s+(man|san|miz|siz)\\b",
             replacement: "$1$2",
             note: Bilingual("The personal ending is written together with the word, not separately.")),
        Rule(pattern: "\\bmen\\s+([a-z'’]+)\\s+emas\\b",
             replacement: "men $1 emasman",
             note: Bilingual("With “men”, the negative becomes “emasman”.")),
        Rule(pattern: "\\bmen\\s+men\\b", replacement: "men",
             note: Bilingual("“men” said twice.")),
        Rule(pattern: "\\bjuda\\s+juda\\b", replacement: "juda",
             note: Bilingual("“juda” said twice.")),
        Rule(pattern: "\\bmen\\s+(\\w+)dan\\s+kelaman\\b", replacement: "men $1danman",
             note: Bilingual("To say where you're from, “-danman” is enough.")),
    ]

    // MARK: - A more natural version, taken from the course

    private static func naturalVersion(for said: String,
                                       words: [String],
                                       lexicon: Lexicon,
                                       language: Language) -> String? {
        let content = Set(words.filter { $0.count >= 3 })
        guard content.count >= 2 else { return nil }
        var best: (phrase: String, score: Double)?
        for phrase in lexicon.phrases(language) {
            let phraseWords = Set(phrase.normalised.split(separator: " ").map(String.init))
            guard phraseWords.count >= 3 else { continue }
            let shared = content.intersection(phraseWords).count
            guard shared >= 2 else { continue }
            let score = Double(shared) / Double(max(content.count, phraseWords.count))
            if score > (best?.score ?? 0.34), phrase.normalised != said {
                best = (phrase.raw, score)
            }
        }
        return best?.phrase
    }

    // MARK: - Headline and tips

    private static func headline(for turns: [TurnReview], stats: CallStats) -> Bilingual {
        let good = turns.filter { $0.status == .good }.count
        let ratio = stats.total == 0 ? 0 : Double(good) / Double(stats.total)
        switch ratio {
        case 0.85...:
            return Bilingual("A fluent conversation!")
        case 0.6..<0.85:
            return Bilingual("A nice chat")
        case 0.3..<0.6:
            return Bilingual("Almost there")
        default:
            return Bilingual("Let's try again, calmly")
        }
    }

    private static func tips(for turns: [TurnReview],
                             stats: CallStats,
                             target: Language,
                             level: CEFR) -> [Bilingual] {
        var out: [Bilingual] = []
        let short = turns.filter { $0.status == .tooShort }.count
        let skipped = turns.filter { $0.status == .skipped }.count
        let wrongLang = turns.filter { $0.status == .wrongLanguage }.count
        let spelling = turns.flatMap(\.corrections).filter { $0.kind == .spelling }.count
        let grammar = turns.flatMap(\.corrections).filter { $0.kind == .grammar }.count

        if wrongLang > 0 {
            out.append(Bilingual("Stay in the language you're learning, even with mistakes: that's where the learning happens."))
        }
        if skipped >= 2 {
            out.append(Bilingual("You skipped \(skipped) questions: next time try saying even just one sentence."))
        }
        if short >= 2 {
            out.append(Bilingual("Many answers were short: try adding a “because” or an example."))
        }
        if spelling >= 3 {
            out.append(target == .uz
                       ? Bilingual("Watch the Uzbek apostrophes: o‘ and g‘ change the word.")
                       : Bilingual("Watch the spelling: the corrections below show the words you mixed up."))
        }
        if grammar >= 2 {
            out.append(Bilingual("Read the corrections below again: they're the mistakes you repeat most."))
        }
        if stats.averageWords >= Double(level <= .a2 ? 6 : 10) {
            out.append(Bilingual("Long, well-built answers: keep it up."))
        }
        if out.isEmpty {
            out.append(Bilingual("A good conversation: try again with another subject."))
        }
        return out
    }
}

// MARK: - The words and phrases the checker knows

struct Lexicon {
    struct Phrase { let raw: String; let normalised: String }

    /// Two sides only: English, and the course's language.
    private var words: [Bool: Set<String>] = [:]
    private var phraseList: [Bool: [Phrase]] = [:]

    init(curriculum: Curriculum) {
        let target = Language.current
        for english in [true, false] {
            var set = Set<String>()
            var phrases: [Phrase] = []
            for pair in curriculum.allPairs {
                let raw = english ? pair.en : pair.tx
                let norm = Grader.normalise(raw)
                let split = WordSplitter.words(in: raw, language: english ? .en : target)
                    .map(Grader.normalise).filter { !$0.isEmpty }
                for word in split { set.insert(word) }
                if split.count >= 3 {
                    phrases.append(Phrase(raw: raw, normalised: norm))
                }
            }
            words[english] = set
            phraseList[english] = phrases
        }
    }

    func knows(_ word: String, language: Language) -> Bool {
        words[language == .en]?.contains(word) ?? false
    }

    func phrases(_ language: Language) -> [Phrase] { phraseList[language == .en] ?? [] }

    /// The closest known word, when it is close enough to be a typo rather than a
    /// different word.
    ///
    /// Two guards keep it honest on an agglutinative language where the course can
    /// never contain every inflected form: the first letter has to match (a changed
    /// initial is almost never a slip — *deyman* is not a misspelt *yeyman*), and a
    /// two-letter distance is only accepted on long words.
    func nearest(_ word: String, language: Language) -> String? {
        guard let set = words[language == .en], let initial = word.first else { return nil }
        let budget = word.count >= 7 ? 2 : 1
        var best: (word: String, distance: Int)?
        for candidate in set where abs(candidate.count - word.count) <= budget
                                && candidate.first == initial {
            let d = Grader.levenshtein(word, candidate)
            if d <= budget, d < (best?.distance ?? Int.max) {
                best = (candidate, d)
                if d == 1 { break }
            }
        }
        return best?.word
    }
}
