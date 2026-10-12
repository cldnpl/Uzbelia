import Foundation

enum ExerciseFactory {

    // MARK: - Public entry points

    /// Builds one pass over a node. `focus` changes what the pass drills, so the
    /// five sessions a lesson needs are five genuinely different workouts — and a
    /// pass is made only of exercises of its own skill: "Ascolto" is all listening,
    /// "Scrittura" all writing (closing on a short text of her own), and so on.
    ///
    /// `fresh` is sentences written for this chapter by the assistant (see
    /// `PhraseForge`). They are mixed in from the second pass onwards: the first pass
    /// is where the chapter's own words are met for the first time, and meeting them
    /// inside a sentence nobody has ever checked is not how you meet a word.
    ///
    /// `familiarity` says how many times she has already answered a pair (0 = never).
    /// The later passes use it to reach for what she has seen least, so each one
    /// brings sentences the previous one did not.
    static func session(for node: PathNode,
                        unit: Unit,
                        curriculum: Curriculum,
                        native: Language,
                        settings: Settings,
                        focus requested: SessionFocus = .discover,
                        fresh: [Pair] = [],
                        familiarity: (Pair) -> Int = { _ in 0 }) -> [Exercise] {
        let pool = curriculum.pairsUpTo(unitID: unit.id)
        // a pass whose skill is switched off becomes a mixed review, never a
        // "listening" pass full of something else
        let focus = requested.available(with: settings)
        switch node.kind {
        case .lesson(let lesson):
            let pairs = focus == .discover
                ? lesson.allPairs
                : rotation(words: lesson.vocab,
                           sentences: lesson.phrases + lesson.drills,
                           fresh: fresh, familiarity: familiarity,
                           wordCount: 4, sentenceCount: 8)
            // the writing pass keeps its last slot for the short text — in a language
            // she can type; a script she cannot is written with tiles instead
            let text = focus == .writing && native.other.isLatin
                ? CompositionPlanner.task(sentences: lesson.phrases + lesson.drills,
                                          native: native, level: node.level,
                                          familiarity: familiarity)
                : nil
            var out = build(pairs: pairs, pool: pool, native: native,
                            settings: settings,
                            maxCount: focus.length - (text == nil ? 0 : 1),
                            includeMatch: focus == .discover,
                            productionBias: focus.productionBias,
                            onlySkill: focus.skill)
            if let text { out.append(compose(text)) }
            return out
        case .story(let dialogue):
            let lines = dialogue.lines.map { Pair(en: $0.en, tx: $0.tx, rom: $0.rom) }
            return build(pairs: blend(taught: lines, fresh: fresh, want: 12),
                         pool: pool, native: native,
                         settings: settings, maxCount: 9, includeMatch: false,
                         productionBias: 0.4, onlySkill: focus.skill)
        case .writing:
            // Not a set of exercises at all — see `ChatChapterView`.
            return []
        case .review:
            let pairs = rotation(words: unit.lessons.flatMap(\.vocab),
                                 sentences: unit.lessons.flatMap(\.phrases) + unit.allDrills,
                                 fresh: fresh, familiarity: familiarity,
                                 wordCount: 6, sentenceCount: 12)
            return build(pairs: pairs, pool: pool, native: native,
                         settings: settings, maxCount: 14, includeMatch: true,
                         productionBias: 0.65)
        }
    }

    /// The short-text exercise for a brief.
    static func compose(_ task: CompositionTask) -> Exercise {
        let target = task.target
        // the pair it trains, for spaced repetition and for the results screen
        let pair = task.outline.first ?? Pair(en: "", tx: "")
        return Exercise(kind: .compose, pair: pair,
                        prompt: task.outline.map { $0[task.native] }.joined(separator: " "),
                        promptLanguage: task.native,
                        answer: task.model, answerLanguage: target,
                        composition: task)
    }

    /// What a later pass over a lesson is made of: a handful of its words, and a
    /// dozen of its sentences — the course's own, the practice sentences written for
    /// it, and whatever the assistant has added — least practised first.
    ///
    /// Least practised, not simply random: a random dozen out of sixteen would still
    /// repeat most of the last session. Ties are broken at random, so two sessions
    /// over sentences she has never seen are two different sessions.
    static func rotation(words: [Pair], sentences: [Pair], fresh: [Pair],
                         familiarity: (Pair) -> Int,
                         wordCount: Int, sentenceCount: Int) -> [Pair] {
        func leastSeen(_ pairs: [Pair], _ n: Int) -> [Pair] {
            var seen = Set<String>()
            let unique = pairs.filter { seen.insert($0.id).inserted }
            return Array(unique.map { ($0, familiarity($0), Int.random(in: 0..<1_000_000)) }
                .sorted { ($0.1, $0.2) < ($1.1, $1.2) }
                .prefix(n)
                .map(\.0))
        }
        let pickedWords = leastSeen(words, wordCount)
        // newly written sentences never outnumber the checked ones: at most half
        let newest = leastSeen(fresh, sentenceCount / 2)
        let checked = leastSeen(sentences, sentenceCount - newest.count)
        let picked = pickedWords + checked + newest
        return picked.isEmpty ? Array(words.prefix(wordCount)) : picked.shuffled()
    }

    /// Roughly half the chapter's own material and half newly written, shuffled
    /// together. Half, because a session made entirely of generated sentences would
    /// stop drilling the very words the chapter exists to teach — and because a
    /// wrong sentence, if one ever slips through, should never be most of a lesson.
    static func blend(taught: [Pair], fresh: [Pair], want: Int) -> [Pair] {
        guard !fresh.isEmpty else { return taught }
        let newest = Array(fresh.shuffled().prefix(max(1, want / 2)))
        let known = Array(taught.shuffled().prefix(max(1, want - newest.count)))
        return (known + newest).shuffled()
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
                     includeMatch: false, productionBias: 0.6)
    }

    static func practice(pairs: [Pair],
                         pool: [Pair],
                         native: Language,
                         settings: Settings,
                         count: Int = 12,
                         productionBias: Double = 0.5,
                         restrictTo skill: Skill? = nil,
                         level: CEFR = .a1) -> [Exercise] {
        var s = settings
        if let skill {
            s.listeningExercises = (skill == .listening)
            s.speakingExercises = (skill == .speaking)
        }
        // a writing drill ends, like the writing pass, on a short text
        let text = skill == .writing
            ? CompositionPlanner.task(sentences: pairs, native: native, level: level)
            : nil
        var out = build(pairs: pairs, pool: pool, native: native, settings: s,
                        maxCount: count - (text == nil ? 0 : 1), includeMatch: skill == nil,
                        productionBias: skill == .writing ? 0.85 : productionBias,
                        onlySkill: skill)
        if let text { out.append(compose(text)) }
        return out
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
                      onlySkill: Skill? = nil) -> [Exercise] {

        let target = native.other
        let pairs = rawPairs.filter { !$0.en.isEmpty && !$0.tx.isEmpty }
        guard !pairs.isEmpty else { return [] }
        let pool = pool(for: rawPool.isEmpty ? pairs : rawPool)

        var out: [Exercise] = []

        // 1. Opening matching game over short items. Words that share a translation
        //    (bog' = giardino / parco) would make the game ambiguous, so keep one.
        let singles = unambiguous(pairs.filter { $0.wordCount(target) <= 2 },
                                  native: native, target: target)
        var paired = Set<String>()
        if includeMatch, singles.count >= 4, onlySkill == nil || onlySkill == .reading {
            let picked = Array(singles.prefix(5))
            out.append(Exercise(kind: .match, pair: picked[0], matchPairs: picked))
            paired = Set(picked.map(\.id))
            // a lesson that is mostly words gets a second round of pairs further in,
            // rather than a long run of one multiple choice after another
            let more = Array(singles.dropFirst(5).prefix(5))
            if onlySkill == .reading, more.count >= 4, singles.count >= 11 {
                out.append(Exercise(kind: .match, pair: more[0], matchPairs: more))
                paired.formUnion(more.map(\.id))
            }
        }
        // the words she has just paired up are not asked again one by one — as long
        // as that still leaves a session's worth of questions
        let unpaired = pairs.filter { !paired.contains($0.id) }
        let items = unpaired.count >= maxCount / 2 ? unpaired : pairs

        // 2. One question per item. The two kind lists are shuffled once and then
        //    walked in order, so every available format gets used evenly.
        let shortKinds = allowedKinds(short: true, settings: settings, onlySkill: onlySkill)
        let longKinds = allowedKinds(short: false, settings: settings, onlySkill: onlySkill)
        var shortIdx = 0, longIdx = 0
        // the direction is dealt out evenly rather than rolled: a bias of 0.5 is one
        // each way in turn, not five the same way by bad luck
        var lean = Double.random(in: 0..<1)

        for pair in items.shuffled() {
            let isShort = pair.wordCount(target) <= 2
            let kind: Exercise.Kind
            if isShort {
                guard !shortKinds.isEmpty else { continue }
                kind = shortKinds[shortIdx % shortKinds.count]; shortIdx += 1
            } else {
                guard !longKinds.isEmpty else { continue }
                kind = longKinds[longIdx % longKinds.count]; longIdx += 1
            }
            lean += productionBias
            let produce = lean >= 1
            if produce { lean -= 1 }
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
        // a second round of pairs goes halfway through, never straight after the first
        if let i = out.firstIndex(where: { $0.kind == .match }) {
            let second = out.remove(at: i)
            out.insert(second, at: min(out.count, max(2, out.count / 2)))
        }
        if let head { out.insert(head, at: 0) }
        return Array(out.prefix(maxCount))
    }

    /// Reorders a session so consecutive questions rarely share a format — a format
    /// being the kind of question and the direction it is asked in: reading Uzbek and
    /// picking the Italian is not the same exercise as the other way round.
    private static func spread(_ list: [Exercise]) -> [Exercise] {
        func format(_ e: Exercise) -> String { "\(e.kind)|\(e.promptLanguage)" }
        var remaining = list
        var out: [Exercise] = []
        while !remaining.isEmpty {
            let idx = remaining.firstIndex { e in out.last.map { format($0) != format(e) } ?? true } ?? 0
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

    /// The formats a session may use. With a skill, only that skill's formats —
    /// never a reading question in a writing pass. Each list repeats its staples so
    /// that walking it in order gives a sensible mix.
    private static func allowedKinds(short: Bool, settings: Settings,
                                     onlySkill: Skill?) -> [Exercise.Kind] {
        var kinds: [Exercise.Kind]
        switch onlySkill {
        case .reading?:
            kinds = short ? [.choice, .choice, .fillBlank]
                          : [.wordBank, .choice, .fillBlank, .wordBank]
        case .listening?:
            kinds = short ? [.listenChoice, .listenMeaning, .listenType]
                          : [.listenType, .listenBuild, .listenMeaning, .listenBuild, .listenChoice]
        case .writing?:
            kinds = [.type]
        case .speaking?:
            kinds = short ? [.speak, .speakRepeat, .speak]
                          : [.speak, .speakRepeat]
        case nil:
            if short {
                kinds = [.choice, .type, .choice, .fillBlank]
                if settings.listeningExercises { kinds += [.listenChoice, .listenMeaning] }
                if settings.speakingExercises { kinds.append(.speak) }
            } else {
                kinds = [.wordBank, .choice, .type, .fillBlank, .wordBank]
                if settings.listeningExercises { kinds += [.listenType, .listenBuild] }
                if settings.speakingExercises { kinds += [.speak, .speakRepeat] }
            }
        }
        return kinds.shuffled()
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
            // nobody starting Thai or Persian can type it: she builds it from tiles
            if !to.isLatin {
                return make(kind: .wordBank, pair: pair, pool: pool,
                            native: native, target: target, produceTarget: produceTarget)
            }
            return Exercise(kind: .type, pair: pair,
                            prompt: pair[from], promptLanguage: from,
                            answer: pair[to], answerLanguage: to,
                            audioText: from == target ? pair[target] : nil,
                            audioLanguage: from == target ? target : nil,
                            hint: pair.hint)

        case .listenType:
            if !target.isLatin {
                return make(kind: .listenBuild, pair: pair, pool: pool,
                            native: native, target: target, produceTarget: produceTarget)
            }
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
                            prompt: Grader.join(words, like: sentence), promptLanguage: target,
                            answer: missing, answerLanguage: target,
                            options: opts.shuffled(),
                            audioText: sentence, audioLanguage: target,
                            blankIndex: idx,
                            hint: pair[native])

        case .listenMeaning:
            let correct = pair[native]
            let opts = distractors(for: correct, lang: native, pool: pool, count: 3,
                                   prompt: pair[target], promptLang: target) + [correct]
            return Exercise(kind: .listenMeaning, pair: pair,
                            prompt: "", promptLanguage: target,
                            answer: correct, answerLanguage: native,
                            options: opts.shuffled(),
                            audioText: pair[target], audioLanguage: target,
                            hint: pair.hint)

        case .listenBuild:
            let answer = pair[target]
            var chips = Grader.tokenize(answer)
            guard chips.count >= 2 else {
                return make(kind: .listenChoice, pair: pair, pool: pool,
                            native: native, target: target, produceTarget: produceTarget)
            }
            chips += decoyWords(avoiding: chips, lang: target, pool: pool,
                                count: min(3, max(2, chips.count / 2)))
            return Exercise(kind: .listenBuild, pair: pair,
                            prompt: "", promptLanguage: target,
                            answer: answer, answerLanguage: target,
                            tokens: chips.shuffled(),
                            audioText: answer, audioLanguage: target,
                            hint: pair.hint)

        case .speakRepeat:
            return Exercise(kind: .speakRepeat, pair: pair,
                            prompt: pair[target], promptLanguage: target,
                            answer: pair[target], answerLanguage: target,
                            audioText: pair[target], audioLanguage: target,
                            hint: pair[native])

        case .match, .compose:
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
