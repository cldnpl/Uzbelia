import Foundation

enum ExerciseFactory {

    // MARK: - Public entry points

    /// Builds one pass over a node. `focus` changes what the pass drills, so the
    /// five sessions a lesson needs are five genuinely different workouts.
    static func session(for node: PathNode,
                        unit: Unit,
                        curriculum: Curriculum,
                        native: Language,
                        settings: Settings,
                        focus: SessionFocus = .discover) -> [Exercise] {
        let pool = curriculum.pairsUpTo(unitID: unit.id)
        switch node.kind {
        case .lesson(let lesson):
            return build(pairs: lesson.allPairs, pool: pool, native: native,
                         settings: settings, maxCount: 15,
                         includeMatch: focus == .discover,
                         productionBias: focus.productionBias,
                         emphasis: focus.emphasis)
        case .story(let dialogue):
            let pairs = dialogue.lines.map { Pair(it: $0.it, uz: $0.uz) }
            return build(pairs: pairs, pool: pool, native: native,
                         settings: settings, maxCount: 12, includeMatch: false,
                         productionBias: 0.4, emphasis: .listening)
        case .review:
            let pairs = unit.allPairs.shuffled()
            return build(pairs: Array(pairs.prefix(22)), pool: pool, native: native,
                         settings: settings, maxCount: 20, includeMatch: true,
                         productionBias: 0.65, emphasis: nil)
        }
    }

    /// A knowledge check: no matching game, production heavy, drawn from a wide pool.
    static func placementTest(pairs: [Pair],
                              pool: [Pair],
                              native: Language,
                              settings: Settings,
                              count: Int) -> [Exercise] {
        var s = settings
        s.speakingExercises = false          // a test should never depend on a microphone
        return build(pairs: Array(pairs.shuffled().prefix(count + 6)), pool: pool,
                     native: native, settings: s, maxCount: count,
                     includeMatch: false, productionBias: 0.6, emphasis: nil)
    }

    static func practice(pairs: [Pair],
                         pool: [Pair],
                         native: Language,
                         settings: Settings,
                         count: Int = 15,
                         productionBias: Double = 0.5,
                         restrictTo skill: Skill? = nil) -> [Exercise] {
        var s = settings
        if let skill {
            s.listeningExercises = (skill == .listening)
            s.speakingExercises = (skill == .speaking)
        }
        return build(pairs: pairs, pool: pool, native: native, settings: s,
                     maxCount: count, includeMatch: skill == nil,
                     productionBias: productionBias, onlySkill: skill)
    }

    // MARK: - The distractor pool
    //
    // Normalising 2000 strings for every single question was the hot spot, so the
    // pool is digested once per session: normalised forms, word lists, and the map
    // of alternative translations used to avoid questions with two right answers.

    /// The last digested pool. A learner runs five sessions over the same unit, and
    /// each one would otherwise re-normalise the whole vocabulary pool.
    private nonisolated(unsafe) static var poolCache: (key: String, pool: Pool)?

    private static func pool(for pairs: [Pair]) -> Pool {
        let key = "\(pairs.count)|\(pairs.first?.id ?? "")|\(pairs.last?.id ?? "")"
        if let cached = poolCache, cached.key == key { return cached.pool }
        let built = Pool(pairs)
        poolCache = (key, built)
        return built
    }

    private struct Pool {
        struct Entry {
            let raw: String
            let norm: String
            let words: Int
        }
        var texts: [Language: [Entry]] = [:]
        var words: [Language: [String]] = [:]
        /// norm(text in L) → every accepted translation (normalised) in the other language
        var synonyms: [Language: [String: Set<String>]] = [:]

        init(_ pairs: [Pair]) {
            for lang in Language.allCases {
                var entries: [Entry] = []
                var seen = Set<String>()
                var words: [String] = []
                var wordSeen = Set<String>()
                var syn: [String: Set<String>] = [:]
                let other = lang.other
                for p in pairs {
                    let raw = p[lang]
                    guard !raw.isEmpty else { continue }
                    let norm = Grader.normalise(raw)
                    if seen.insert(norm).inserted {
                        entries.append(Entry(raw: raw, norm: norm,
                                             words: raw.split(separator: " ").count))
                    }
                    syn[norm, default: []].insert(Grader.normalise(p[other]))
                    for w in Grader.tokenize(raw) where w.count > 1 {
                        let n = Grader.normalise(w)
                        if !n.isEmpty, wordSeen.insert(n).inserted { words.append(w) }
                    }
                }
                texts[lang] = entries
                self.words[lang] = words
                synonyms[lang] = syn
            }
        }
    }

    // MARK: - Core builder

    static func build(pairs rawPairs: [Pair],
                      pool rawPool: [Pair],
                      native: Language,
                      settings: Settings,
                      maxCount: Int,
                      includeMatch: Bool,
                      productionBias: Double,
                      onlySkill: Skill? = nil,
                      emphasis: Skill? = nil) -> [Exercise] {

        let target = native.other
        let pairs = rawPairs.filter { !$0.it.isEmpty && !$0.uz.isEmpty }
        guard !pairs.isEmpty else { return [] }
        let pool = pool(for: rawPool.isEmpty ? pairs : rawPool)

        var out: [Exercise] = []

        // 1. Opening matching game over short items. Words that share a translation
        //    (bog' = giardino / parco) would make the game ambiguous, so keep one.
        let singles = unambiguous(pairs.filter { $0.wordCount(target) <= 2 },
                                  native: native, target: target)
        if includeMatch, singles.count >= 4, onlySkill == nil || onlySkill == .reading {
            let picked = Array(singles.prefix(5))
            out.append(Exercise(kind: .match, pair: picked[0], matchPairs: picked))
        }

        // 2. One question per item. The two kind lists are shuffled once and then
        //    walked in order, so every available format gets used evenly.
        let shortKinds = allowedKinds(short: true, settings: settings,
                                      onlySkill: onlySkill, emphasis: emphasis)
        let longKinds = allowedKinds(short: false, settings: settings,
                                     onlySkill: onlySkill, emphasis: emphasis)
        var shortIdx = 0, longIdx = 0

        for pair in pairs.shuffled() {
            let isShort = pair.wordCount(target) <= 2
            let kind: Exercise.Kind
            if isShort {
                guard !shortKinds.isEmpty else { continue }
                kind = shortKinds[shortIdx % shortKinds.count]; shortIdx += 1
            } else {
                guard !longKinds.isEmpty else { continue }
                kind = longKinds[longIdx % longKinds.count]; longIdx += 1
            }
            let produce = Double.random(in: 0...1) < productionBias
            if let ex = make(kind: kind, pair: pair, pool: pool,
                             native: native, target: target, produceTarget: produce) {
                out.append(ex)
            }
            if out.count >= maxCount { break }
        }

        // 3. Keep the matching game first, then spread the formats so the same kind
        //    of question never comes up twice in a row.
        var head: Exercise?
        if out.count > 2, case .match = out[0].kind { head = out.removeFirst() }
        out.shuffle()
        out = spread(out)
        if let head { out.insert(head, at: 0) }
        return Array(out.prefix(maxCount))
    }

    /// Reorders a session so consecutive questions rarely share a format.
    private static func spread(_ list: [Exercise]) -> [Exercise] {
        var remaining = list
        var out: [Exercise] = []
        while !remaining.isEmpty {
            let idx = remaining.firstIndex { $0.kind != out.last?.kind } ?? 0
            out.append(remaining.remove(at: idx))
        }
        return out
    }

    /// Drops items whose translation collides with one already kept, in either language.
    private static func unambiguous(_ pairs: [Pair], native: Language, target: Language) -> [Pair] {
        var seenTarget = Set<String>(), seenNative = Set<String>()
        var out: [Pair] = []
        for p in pairs.shuffled() {
            let t = Grader.normalise(p[target]), n = Grader.normalise(p[native])
            guard !seenTarget.contains(t), !seenNative.contains(n) else { continue }
            seenTarget.insert(t); seenNative.insert(n)
            out.append(p)
        }
        return out
    }

    private static func allowedKinds(short: Bool, settings: Settings,
                                     onlySkill: Skill?, emphasis: Skill? = nil) -> [Exercise.Kind] {
        var kinds: [Exercise.Kind]
        if short {
            kinds = [.choice, .type, .choice, .fillBlank]
            if settings.listeningExercises { kinds.append(.listenChoice) }
            if settings.speakingExercises { kinds.append(.speak) }
        } else {
            kinds = [.wordBank, .choice, .type, .fillBlank, .wordBank]
            if settings.listeningExercises { kinds.append(.listenType) }
            if settings.speakingExercises { kinds.append(.speak) }
        }
        // An emphasised skill takes about half the session and no more: every pass
        // leans somewhere without ever turning into fifteen copies of one format.
        if let emphasis, onlySkill == nil {
            let favoured = kinds.filter { kindSkill($0) == emphasis }
            let others = kinds.filter { kindSkill($0) != emphasis }
            if !favoured.isEmpty, !others.isEmpty {
                var boosted: [Exercise.Kind] = []
                while boosted.count < others.count { boosted += favoured }
                kinds = Array(boosted.prefix(others.count)) + others
            }
        }
        if let onlySkill {
            kinds = kinds.filter { kindSkill($0) == onlySkill }
            if kinds.isEmpty {
                kinds = onlySkill == .listening ? [short ? .listenChoice : .listenType]
                      : onlySkill == .speaking ? [.speak]
                      : onlySkill == .writing ? [.type]
                      : [.choice]
            }
        }
        return kinds.shuffled()
    }

    private static func kindSkill(_ k: Exercise.Kind) -> Skill {
        switch k {
        case .type: return .writing
        case .listenType, .listenChoice: return .listening
        case .speak: return .speaking
        default: return .reading
        }
    }

    // MARK: - Individual question makers

    private static func make(kind: Exercise.Kind,
                             pair: Pair,
                             pool: Pool,
                             native: Language,
                             target: Language,
                             produceTarget: Bool) -> Exercise? {
        switch kind {

        case .choice:
            let from: Language = produceTarget ? native : target
            let to: Language = from.other
            let correct = pair[to]
            let opts = distractors(for: correct, lang: to, pool: pool, count: 3,
                                   prompt: pair[from], promptLang: from) + [correct]
            return Exercise(kind: .choice, pair: pair,
                            prompt: pair[from], promptLanguage: from,
                            answer: correct, answerLanguage: to,
                            options: opts.shuffled(),
                            audioText: from == target ? pair[target] : nil,
                            audioLanguage: from == target ? target : nil,
                            hint: pair.hint)

        case .listenChoice:
            let correct = pair[target]
            let opts = distractors(for: correct, lang: target, pool: pool, count: 3,
                                   prompt: pair[native], promptLang: native) + [correct]
            return Exercise(kind: .listenChoice, pair: pair,
                            prompt: "", promptLanguage: target,
                            answer: correct, answerLanguage: target,
                            options: opts.shuffled(),
                            audioText: pair[target], audioLanguage: target,
                            hint: pair.hint)

        case .wordBank:
            let from: Language = produceTarget ? native : target
            let to: Language = from.other
            let answer = pair[to]
            var chips = Grader.tokenize(answer)
            guard chips.count >= 2 else {
                return make(kind: .choice, pair: pair, pool: pool,
                            native: native, target: target, produceTarget: produceTarget)
            }
            chips += decoyWords(avoiding: chips, lang: to, pool: pool,
                                count: min(3, max(2, chips.count / 2)))
            return Exercise(kind: .wordBank, pair: pair,
                            prompt: pair[from], promptLanguage: from,
                            answer: answer, answerLanguage: to,
                            tokens: chips.shuffled(),
                            audioText: from == target ? pair[target] : nil,
                            audioLanguage: from == target ? target : nil,
                            hint: pair.hint)

        case .type:
            let from: Language = produceTarget ? native : target
            let to: Language = from.other
            return Exercise(kind: .type, pair: pair,
                            prompt: pair[from], promptLanguage: from,
                            answer: pair[to], answerLanguage: to,
                            audioText: from == target ? pair[target] : nil,
                            audioLanguage: from == target ? target : nil,
                            hint: pair.hint)

        case .listenType:
            return Exercise(kind: .listenType, pair: pair,
                            prompt: "", promptLanguage: target,
                            answer: pair[target], answerLanguage: target,
                            audioText: pair[target], audioLanguage: target,
                            hint: pair.hint)

        case .speak:
            return Exercise(kind: .speak, pair: pair,
                            prompt: pair[target], promptLanguage: target,
                            answer: pair[target], answerLanguage: target,
                            audioText: pair[target], audioLanguage: target,
                            hint: pair[native])

        case .fillBlank:
            let sentence = pair[target]
            var words = Grader.tokenize(sentence)
            guard words.count >= 2 else {
                return make(kind: .choice, pair: pair, pool: pool,
                            native: native, target: target, produceTarget: produceTarget)
            }
            // prefer a meaningful (longer) word, never the very first one when possible
            let candidates = words.indices.filter { words[$0].count >= 3 }
            let idx = (candidates.filter { $0 > 0 }.randomElement())
                   ?? (candidates.randomElement() ?? words.count - 1)
            let missing = words[idx]
            words[idx] = "____"
            let opts = decoyWords(avoiding: words + [missing], lang: target, pool: pool,
                                  count: 3, similarTo: missing) + [missing]
            return Exercise(kind: .fillBlank, pair: pair,
                            prompt: words.joined(separator: " "), promptLanguage: target,
                            answer: missing, answerLanguage: target,
                            options: opts.shuffled(),
                            audioText: sentence, audioLanguage: target,
                            blankIndex: idx,
                            hint: pair[native])

        case .match:
            return nil
        }
    }

    // MARK: - Distractors

    /// Plausible wrong answers for `correct`.
    ///
    /// Any candidate that is *another* accepted translation of the prompt the learner
    /// is reading gets dropped — otherwise the question would have two right answers.
    private static func distractors(for correct: String, lang: Language, pool: Pool,
                                    count: Int,
                                    prompt: String, promptLang: Language) -> [String] {
        var forbidden = pool.synonyms[promptLang]?[Grader.normalise(prompt)] ?? []
        forbidden.insert(Grader.normalise(correct))

        let entries = pool.texts[lang] ?? []
        let wanted = correct.split(separator: " ").count
        var close: [String] = [], far: [String] = []
        for e in entries where !forbidden.contains(e.norm) {
            if abs(e.words - wanted) <= 1 { close.append(e.raw) } else { far.append(e.raw) }
        }
        var picked = Array(close.shuffled().prefix(count))
        if picked.count < count {
            picked += far.shuffled().prefix(count - picked.count)
        }
        return Array(picked.prefix(count))
    }

    private static func decoyWords(avoiding used: [String], lang: Language, pool: Pool,
                                   count: Int, similarTo reference: String? = nil) -> [String] {
        let usedSet = Set(used.map(Grader.normalise))
        var candidates = (pool.words[lang] ?? []).filter { !usedSet.contains(Grader.normalise($0)) }
        if let reference {
            let len = reference.count
            let near = candidates.filter { abs($0.count - len) <= 3 }
            if near.count >= count { candidates = near }
        }
        return Array(candidates.shuffled().prefix(count))
    }
}
