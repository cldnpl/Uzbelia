import Foundation

/// Where sentences the course never wrote come from, and where they stay.
///
/// A chapter ships perhaps twenty sentences, and the path asks a learner to go over
/// it five times: by the third pass she is not translating any more, she is
/// remembering which button she pressed last time. The forge asks the assistant for
/// new sentences built from that same chapter's vocabulary, at that chapter's CEFR
/// level, and keeps every one it gets — so the pool grows with use, and a chapter
/// revisited next month is made of material this phone has never shown.
///
/// Everything here is best-effort. No key, no signal, no patience: the caller gets
/// whatever is already on disk, which on the first run is nothing at all, and the
/// lesson is built from the course corpus exactly as it always was.
actor PhraseForge {

    static let shared = PhraseForge()

    /// Enough new material that a session can be visibly different; past this the
    /// forge stops asking and starts drawing on what it has.
    static let comfortable = 24
    /// Never let one chapter's cache grow without end.
    static let capPerLesson = 90
    /// How many to ask for in one go.
    static let batch = 12

    private var cache: [String: [Pair]] = [:]
    private var loaded = false
    /// Chapters with a request already in the air, so five taps make one call.
    private var inFlight: Set<String> = []

    // MARK: - Reading

    /// The sentences held for a chapter, newest first.
    func stored(for id: String) -> [Pair] {
        load()
        return cache[id] ?? []
    }

    func count(for id: String) -> Int {
        load()
        return cache[id]?.count ?? 0
    }

    /// Everything held for a whole unit — what the end-of-unit review draws on.
    func stored(forAnyOf ids: [String]) -> [Pair] {
        load()
        return ids.flatMap { cache[$0] ?? [] }
    }

    // MARK: - Writing

    /// What a chapter needs to have new sentences written for it. Gathered on the
    /// main side of the app, where the curriculum lives, and handed over whole.
    struct Brief: Sendable {
        var lessonID: String
        var level: CEFR
        var unitTitle: String
        var lessonTitle: String
        var grammar: [String]
        var vocabulary: [Pair]
        var native: Language
        var provider: AIProvider
        var key: String

        var isPossible: Bool { AIClient.isConfigured(provider: provider, key: key) && !vocabulary.isEmpty }
    }

    /// Asks for one batch and files what comes back. Returns the chapter's whole
    /// pool afterwards, so a caller that waited for this gets to use it at once.
    @discardableResult
    func replenish(_ brief: Brief) async -> [Pair] {
        load()
        guard brief.isPossible else { return cache[brief.lessonID] ?? [] }
        guard (cache[brief.lessonID]?.count ?? 0) < Self.capPerLesson else {
            return cache[brief.lessonID] ?? []
        }
        guard !inFlight.contains(brief.lessonID) else { return cache[brief.lessonID] ?? [] }
        inFlight.insert(brief.lessonID)
        defer { inFlight.remove(brief.lessonID) }

        let target = brief.native.other
        let existing = (cache[brief.lessonID] ?? []).map { $0[target] }
        do {
            let written = try await AIClient.freshPhrases(
                provider: brief.provider, key: brief.key,
                level: brief.level,
                unitTitle: brief.unitTitle, lessonTitle: brief.lessonTitle,
                grammar: brief.grammar, vocabulary: brief.vocabulary,
                avoid: existing + brief.vocabulary.map { $0[target] },
                target: target, native: brief.native,
                count: Self.batch)
            file(written, for: brief.lessonID, level: brief.level,
                 native: brief.native, alongside: brief.vocabulary)
        } catch {
            // A refused key, a quota, a plane: the course corpus is still there.
        }
        return cache[brief.lessonID] ?? []
    }

    /// Fire-and-forget: used to fill a chapter's pool up while the learner is busy
    /// doing something else, so the next session is ready before she asks for it.
    nonisolated func warm(_ brief: Brief) {
        Task.detached(priority: .utility) { [brief] in
            guard await self.count(for: brief.lessonID) < Self.comfortable else { return }
            await self.replenish(brief)
        }
    }

    /// Waits — but not for long — for a chapter to have something new in it.
    ///
    /// Used only when the pool is empty and the learner is looking at a spinner:
    /// past the deadline the lesson starts on the course corpus and the request is
    /// left running, so the wait is paid once and never twice for the same chapter.
    func ready(_ brief: Brief, waitingUpTo seconds: Double) async -> [Pair] {
        load()
        let held = cache[brief.lessonID] ?? []
        guard held.count < Self.comfortable, brief.isPossible else { return held }

        let work = Task { await self.replenish(brief) }
        let timeout = Task {
            try? await Task.sleep(for: .seconds(seconds))
            return [Pair]()
        }
        // Whichever finishes first wins; the loser keeps running harmlessly.
        let winner = await withTaskGroup(of: [Pair].self, returning: [Pair].self) { group in
            group.addTask { await work.value }
            group.addTask { await timeout.value }
            let first = await group.next() ?? []
            group.cancelAll()
            return first
        }
        return winner.isEmpty ? (cache[brief.lessonID] ?? []) : winner
    }

    // MARK: - Filing what came back

    /// Keeps only sentences that are actually usable: both languages filled in, the
    /// right length for the level, not a translation of itself, and not something
    /// the chapter — or an earlier batch — already says.
    private func file(_ written: [Pair], for id: String, level: CEFR,
                      native: Language, alongside vocabulary: [Pair]) {
        let target = native.other
        let band = AIClient.lengthBand(for: level)
        var seen = Set((cache[id] ?? []).map { Grader.normalise($0[target]) })
        seen.formUnion(vocabulary.map { Grader.normalise($0[target]) })

        var kept = cache[id] ?? []
        for pair in written {
            let t = pair[target].trimmingCharacters(in: .whitespacesAndNewlines)
            let n = pair[native].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !n.isEmpty else { continue }
            let normalised = Grader.normalise(t)
            guard !normalised.isEmpty, !seen.contains(normalised) else { continue }
            // A "translation" identical to its source is a model that gave up.
            guard Grader.normalise(n) != normalised else { continue }
            // One word over the band is a rounding difference; four is a level change.
            let words = t.split(whereSeparator: { $0 == " " }).count
            guard words >= max(2, band.min - 1), words <= band.max + 2 else { continue }
            seen.insert(normalised)
            kept.append(Pair(it: pair.it, uz: pair.uz, hint: pair.hint))
        }
        if kept.count > Self.capPerLesson { kept = Array(kept.suffix(Self.capPerLesson)) }
        cache[id] = kept
        persist()
    }

    // MARK: - Disk

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("uzbelia-phrases.json")
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode([String: [Pair]].self, from: data) else { return }
        cache = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    /// Emptied along with everything else when the learner resets the app.
    func wipe() {
        cache = [:]
        loaded = true
        try? FileManager.default.removeItem(at: Self.fileURL)
    }
}
