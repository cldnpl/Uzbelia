import Foundation

// MARK: - Putting two copies of the same learner back together

extension PersistedState {

    /// Merges the copy on this phone with the copy on the server.
    ///
    /// The rule is one line long and it is the whole point of having an account:
    /// **nothing is ever lost**. Where the two disagree about a number, the larger
    /// one wins; where they disagree about a date, the later one; where they hold
    /// lists or sets, the union. No "last write wins", because last write wins is
    /// exactly how a week of lessons disappears when two phones sync in the wrong
    /// order.
    ///
    /// `self` is the local copy and keeps the last word on the few things that
    /// genuinely belong to this phone: which course is being taken, what is switched
    /// on in Profilo, and which skill is on hold right now.
    func merged(with remote: PersistedState) -> PersistedState {
        var out = self

        out.nativeLanguage = nativeLanguage ?? remote.nativeLanguage
        out.onboarded = onboarded || remote.onboarded

        out.xp = max(xp, remote.xp)
        out.gems = max(gems, remote.gems)
        out.streak = max(streak, remote.streak)
        out.freezes = max(freezes, remote.freezes)

        // Hearts are a moment in time, not a score: take the reading that was taken last.
        if remote.heartsStamp > heartsStamp {
            out.hearts = remote.hearts
            out.heartsStamp = remote.heartsStamp
        }

        out.lastPracticeDay = [lastPracticeDay, remote.lastPracticeDay].compactMap { $0 }.max()

        out.records = records.merging(remote.records) { mine, theirs in
            var r = mine
            r.completions = max(mine.completions, theirs.completions)
            r.bestAccuracy = max(mine.bestAccuracy, theirs.bestAccuracy)
            r.crowns = max(mine.crowns, theirs.crowns)
            r.lastCompleted = [mine.lastCompleted, theirs.lastCompleted].compactMap { $0 }.max()
            return r
        }

        // For a word's memory strength the more practised copy is the true one: it has
        // seen answers the other never saw, and its due date is the one that follows.
        out.srs = srs.merging(remote.srs) { mine, theirs in
            if theirs.reps != mine.reps { return theirs.reps > mine.reps ? theirs : mine }
            return theirs.strength > mine.strength ? theirs : mine
        }

        var days: [String: DaySnapshot] = [:]
        for day in history + remote.history {
            if let seen = days[day.day] {
                days[day.day] = DaySnapshot(day: day.day,
                                            xp: max(seen.xp, day.xp),
                                            minutes: max(seen.minutes, day.minutes))
            } else {
                days[day.day] = day
            }
        }
        out.history = days.values.sorted { $0.day > $1.day }

        out.unlockedLevels = unlockedLevels.union(remote.unlockedLevels)

        // Mistakes: both banks, this phone's first, no duplicates, still capped.
        var seenMistakes = Set<String>()
        out.mistakesBank = (mistakesBank + remote.mistakesBank).filter {
            seenMistakes.insert($0.id).inserted
        }
        if out.mistakesBank.count > Self.mistakeBankCap {
            out.mistakesBank = Array(out.mistakesBank.suffix(Self.mistakeBankCap))
        }

        var seenQuestions = Set<String>()
        out.recentCallQuestions = (recentCallQuestions + remote.recentCallQuestions).filter {
            seenQuestions.insert($0).inserted
        }
        if out.recentCallQuestions.count > Self.recentQuestionCap {
            out.recentCallQuestions = Array(out.recentCallQuestions.suffix(Self.recentQuestionCap))
        }

        // A looked-up meaning is paid for once and kept for good, on either phone.
        out.wordGlosses = wordGlosses.merging(remote.wordGlosses) { mine, _ in mine }

        out.acceptedAlternatives = acceptedAlternatives.merging(remote.acceptedAlternatives) { mine, theirs in
            var list = mine
            for alt in theirs where !list.contains(alt) { list.append(alt) }
            return Array(list.suffix(8))
        }

        // Settings and "I can't speak right now" belong to the phone in her hand.
        out.settings = settings
        out.skillSnoozes = skillSnoozes
        return out
    }

    static let mistakeBankCap = 120
    static let recentQuestionCap = 60

    // MARK: - What travels to the server

    /// The saved profile with the things that have no business leaving the phone
    /// taken out of it: the API key above all — it is the owner's to pay for, and a
    /// synced document is one more place it could leak from — and the fifteen-minute
    /// hold on a skill, which means nothing on another device an hour later.
    var uploadable: PersistedState {
        var out = self
        out.settings.aiKey = ""
        out.settings.aiProvider = .none
        out.skillSnoozes = [:]
        return out
    }

    // MARK: - Getting it down the wire

    /// Zipped JSON. A learner who finishes the whole course carries a few thousand
    /// spaced-repetition items, which is several hundred kilobytes of JSON and a
    /// small fraction of that once compressed — comfortably inside the one megabyte
    /// a Firestore document is allowed.
    func packed() throws -> Data {
        let json = try JSONEncoder().encode(self)
        guard let zipped = try? (json as NSData).compressed(using: .zlib) as Data else {
            return json          // unzipped still decodes: `unpacked` tries both
        }
        return zipped
    }

    static func unpacked(_ data: Data) throws -> PersistedState {
        if let unzipped = try? (data as NSData).decompressed(using: .zlib) as Data,
           let state = try? JSONDecoder().decode(PersistedState.self, from: unzipped) {
            return state
        }
        return try JSONDecoder().decode(PersistedState.self, from: data)
    }
}
