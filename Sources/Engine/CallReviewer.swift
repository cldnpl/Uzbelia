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
            case .spelling: return Bilingual(it: "Ortografia", uz: "Imlo")
            case .grammar: return Bilingual(it: "Grammatica", uz: "Grammatika")
            case .wording: return Bilingual(it: "Più naturale", uz: "Tabiiyroq")
            case .language: return Bilingual(it: "Lingua", uz: "Til")
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
    enum Source: String { case local, claude }
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
                       native: Language,
                       curriculum: Curriculum,
                       level: CEFR) -> CallReview {
        let target = native.other
        let lexicon = Lexicon(curriculum: curriculum)
        var reviews: [TurnReview] = []
        var stats = CallStats()
        stats.total = turns.count

        var allWords: [String] = []
        var targetHits = 0, nativeHits = 0

        for turn in turns {
            stats.seconds += turn.seconds
            let said = Grader.normalise(turn.answer)
            let words = said.split(separator: " ").map(String.init)

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
                    note: native == .it
                        ? Bilingual(it: "Hai risposto in italiano: prova a dirlo in uzbeko, anche con errori.",
                                    uz: "Siz italyancha javob berdingiz.")
                        : Bilingual(it: "Hai risposto in uzbeko.",
                                    uz: "Siz o'zbekcha javob berdingiz: italyanchada aytishga urinib ko'ring, xato bo'lsa ham.")))
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
                    note: Bilingual(it: "Dal corso, un modo più naturale di dirlo.",
                                    uz: "Kursdan olingan tabiiyroq ifoda.")))
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
                          tips: tips(for: reviews, stats: stats, native: native, level: level))
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
                note: Bilingual(it: "Forse volevi dire «\(near)».",
                                uz: "Ehtimol «\(near)» demoqchi edingiz.")))
        }
        return out
    }

    // MARK: - Grammar

    private struct Rule {
        let pattern: String
        let replacement: String
        let note: Bilingual
    }

    private static func grammarChecks(_ text: String, target: Language) -> [Correction] {
        let rules = target == .uz ? uzbekRules : italianRules
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

    /// Mistakes an Italian speaker reliably makes in Uzbek.
    private static let uzbekRules: [Rule] = [
        Rule(pattern: "\\b((?:bir|ikki|uch|to'rt|besh|olti|yetti|sakkiz|to'qqiz|o'n|nechta|necha|ko'p)(?:ta)?)\\s+(\\w+?)lar\\b",
             replacement: "$1 $2",
             note: Bilingual(it: "Dopo un numero o una quantità il nome resta al singolare: niente -lar.",
                             uz: "Sondan keyin ot birlikda qoladi: -lar qo'shilmaydi.")),
        Rule(pattern: "\\b(\\w+)\\s+(man|san|miz|siz)\\b",
             replacement: "$1$2",
             note: Bilingual(it: "La desinenza personale si attacca alla parola, non si stacca.",
                             uz: "Shaxs qo'shimchasi so'zga qo'shib yoziladi.")),
        Rule(pattern: "\\bmen\\s+([a-z'’]+)\\s+emas\\b",
             replacement: "men $1 emasman",
             note: Bilingual(it: "Con «men» la negazione diventa «emasman».",
                             uz: "«Men» bilan inkor «emasman» bo'ladi.")),
        Rule(pattern: "\\bmen\\s+men\\b", replacement: "men",
             note: Bilingual(it: "«men» ripetuto.", uz: "«men» takrorlangan.")),
        Rule(pattern: "\\bjuda\\s+juda\\b", replacement: "juda",
             note: Bilingual(it: "«juda» ripetuto.", uz: "«juda» takrorlangan.")),
        Rule(pattern: "\\bmen\\s+(\\w+)dan\\s+kelaman\\b", replacement: "men $1danman",
             note: Bilingual(it: "Per dire la provenienza basta «-danman».",
                             uz: "Kelib chiqishni aytish uchun «-danman» yetarli.")),
    ]

    /// Mistakes an Uzbek speaker reliably makes in Italian.
    private static let italianRules: [Rule] = [
        Rule(pattern: "\\bho\\s+(andato|andata|venuto|venuta|arrivato|arrivata|partito|partita|tornato|tornata|uscito|uscita|entrato|entrata|stato|stata|rimasto|rimasta|nato|nata)\\b",
             replacement: "sono $1",
             note: Bilingual(it: "I verbi di movimento e di stato vogliono «essere».",
                             uz: "Harakat va holat fe'llari «essere» bilan keladi.")),
        Rule(pattern: "\\bsono\\s+(mangiato|bevuto|fatto|letto|scritto|visto|comprato|studiato|lavorato|parlato|detto|preso|messo|finito|cominciato|dormito)\\b",
             replacement: "ho $1",
             note: Bilingual(it: "Questi verbi vogliono «avere».",
                             uz: "Bu fe'llar «avere» bilan keladi.")),
        Rule(pattern: "\\bin\\s+(roma|milano|napoli|firenze|venezia|torino|tashkent|toshkent|samarcanda|samarqand|bukhara|buxoro)\\b",
             replacement: "a $1",
             note: Bilingual(it: "Con le città si usa «a»: a Roma, a Tashkent.",
                             uz: "Shaharlar bilan «a» ishlatiladi: a Roma, a Tashkent.")),
        Rule(pattern: "\\ba\\s+(italia|uzbekistan|francia|germania|spagna|turchia|russia|cina|inghilterra|america)\\b",
             replacement: "in $1",
             note: Bilingual(it: "Con i paesi si usa «in»: in Italia, in Uzbekistan.",
                             uz: "Davlatlar bilan «in» ishlatiladi: in Italia, in Uzbekistan.")),
        Rule(pattern: "\\bmi piace\\s+(i|le|gli)\\s+(\\w+)\\b",
             replacement: "mi piacciono $1 $2",
             note: Bilingual(it: "Al plurale diventa «mi piacciono».",
                             uz: "Ko'plikda «mi piacciono» bo'ladi.")),
        Rule(pattern: "\\bsono\\s+(\\d+|venti|ventuno|venticinque|trenta|quaranta|diciotto|diciannove)\\s+anni\\b",
             replacement: "ho $1 anni",
             note: Bilingual(it: "L'età si dice con «avere»: ho 25 anni.",
                             uz: "Yosh «avere» bilan aytiladi: ho 25 anni.")),
        Rule(pattern: "\\b(io\\s+)?sono\\s+(fame|sete|freddo|caldo|ragione|paura|sonno)\\b",
             replacement: "ho $2",
             note: Bilingual(it: "Fame, sete, freddo, ragione: si dicono con «avere».",
                             uz: "Fame, sete, freddo, ragione — «avere» bilan.")),
        Rule(pattern: "\\bpiù\\s+(meglio|peggio)\\b", replacement: "$1",
             note: Bilingual(it: "«Meglio» è già un comparativo: niente «più».",
                             uz: "«Meglio» o'zi qiyosiy daraja: «più» kerak emas.")),
        Rule(pattern: "\\bogni\\s+(giorni|anni|settimane|mesi)\\b",
             replacement: "ogni giorno",
             note: Bilingual(it: "Dopo «ogni» il nome va al singolare.",
                             uz: "«Ogni» dan keyin ot birlikda bo'ladi.")),
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
            return Bilingual(it: "Conversazione sciolta!", uz: "Suhbat ravon o'tdi!")
        case 0.6..<0.85:
            return Bilingual(it: "Bella chiacchierata", uz: "Yaxshi suhbat bo'ldi")
        case 0.3..<0.6:
            return Bilingual(it: "Ci siamo quasi", uz: "Deyarli yaxshi")
        default:
            return Bilingual(it: "Riproviamo con calma", uz: "Keling, yana bir bor urinamiz")
        }
    }

    private static func tips(for turns: [TurnReview],
                             stats: CallStats,
                             native: Language,
                             level: CEFR) -> [Bilingual] {
        var out: [Bilingual] = []
        let short = turns.filter { $0.status == .tooShort }.count
        let skipped = turns.filter { $0.status == .skipped }.count
        let wrongLang = turns.filter { $0.status == .wrongLanguage }.count
        let spelling = turns.flatMap(\.corrections).filter { $0.kind == .spelling }.count
        let grammar = turns.flatMap(\.corrections).filter { $0.kind == .grammar }.count

        if wrongLang > 0 {
            out.append(Bilingual(it: "Resta nella lingua che stai imparando, anche sbagliando: è lì che si impara.",
                                 uz: "O'rganayotgan tilingizda qoling, xato qilsangiz ham — o'rganish shunda."))
        }
        if skipped >= 2 {
            out.append(Bilingual(it: "Hai saltato \(skipped) domande: la prossima volta prova a dire anche solo una frase.",
                                 uz: "\(skipped) ta savolni o'tkazib yubordingiz: keyingi safar hech bo'lmasa bitta jumla ayting."))
        }
        if short >= 2 {
            out.append(Bilingual(it: "Molte risposte erano brevi: prova ad aggiungere un «perché» o un esempio.",
                                 uz: "Javoblar qisqa bo'ldi: «nega» yoki misol qo'shishga harakat qiling."))
        }
        if spelling >= 3 {
            out.append(native == .it
                       ? Bilingual(it: "Occhio agli apostrofi uzbeki: o‘ e g‘ cambiano la parola.",
                                   uz: "O'zbek apostroflariga e'tibor bering.")
                       : Bilingual(it: "Attenzione all'ortografia italiana.",
                                   uz: "Italyan imlosiga e'tibor bering: qo'sh undoshlar va urg'u belgilari."))
        }
        if grammar >= 2 {
            out.append(Bilingual(it: "Rileggi le correzioni qui sotto: sono gli errori che ripeti più spesso.",
                                 uz: "Quyidagi tuzatishlarni ko'rib chiqing: bular eng ko'p takrorlanadigan xatolar."))
        }
        if stats.averageWords >= Double(level <= .a2 ? 6 : 10) {
            out.append(Bilingual(it: "Risposte lunghe e articolate: continua così.",
                                 uz: "Javoblaringiz to'liq va mazmunli: shu ruhda davom eting."))
        }
        if out.isEmpty {
            out.append(Bilingual(it: "Buona conversazione: riprova con un altro argomento.",
                                 uz: "Yaxshi suhbat: boshqa mavzuda ham urinib ko'ring."))
        }
        return out
    }
}

// MARK: - The words and phrases the checker knows

struct Lexicon {
    struct Phrase { let raw: String; let normalised: String }

    private var words: [Language: Set<String>] = [:]
    private var phraseList: [Language: [Phrase]] = [:]

    init(curriculum: Curriculum) {
        for language in Language.allCases {
            var set = Set<String>()
            var phrases: [Phrase] = []
            for pair in curriculum.allPairs {
                let raw = pair[language]
                let norm = Grader.normalise(raw)
                for word in norm.split(separator: " ") { set.insert(String(word)) }
                if norm.split(separator: " ").count >= 3 {
                    phrases.append(Phrase(raw: raw, normalised: norm))
                }
            }
            words[language] = set
            phraseList[language] = phrases
        }
    }

    func knows(_ word: String, language: Language) -> Bool {
        words[language]?.contains(word) ?? false
    }

    func phrases(_ language: Language) -> [Phrase] { phraseList[language] ?? [] }

    /// The closest known word, when it is close enough to be a typo rather than a
    /// different word.
    ///
    /// Two guards keep it honest on an agglutinative language where the course can
    /// never contain every inflected form: the first letter has to match (a changed
    /// initial is almost never a slip — *deyman* is not a misspelt *yeyman*), and a
    /// two-letter distance is only accepted on long words.
    func nearest(_ word: String, language: Language) -> String? {
        guard let set = words[language], let initial = word.first else { return nil }
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
