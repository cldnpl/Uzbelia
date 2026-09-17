import Foundation
import Observation

// MARK: - Persisted records

struct LessonRecord: Codable, Hashable {
    var completions: Int = 0
    var bestAccuracy: Double = 0      // 0...1
    var lastCompleted: Date?
    var crowns: Int = 0               // 0...3, one per clean-ish run
}

struct SRSItem: Codable, Hashable {
    var pairID: String
    var strength: Double = 0          // 0...1
    var due: Date = .now
    var reps: Int = 0
    var lapses: Int = 0

    mutating func grade(correct: Bool, now: Date = .now) {
        if correct {
            reps += 1
            strength = min(1, strength + (strength < 0.5 ? 0.28 : 0.16))
        } else {
            lapses += 1
            reps = max(0, reps - 1)
            strength = max(0, strength - 0.34)
        }
        // interval in hours grows with strength
        let hours = [4.0, 12, 24, 72, 168, 336][min(5, max(0, Int(strength * 5.99)))]
        due = now.addingTimeInterval(hours * 3600 * (correct ? 1 : 0.25))
    }
}

struct DaySnapshot: Codable, Hashable {
    var day: String                   // yyyy-MM-dd
    var xp: Int
    var minutes: Int
}

// MARK: - Settings

struct Settings: Codable, Hashable {
    var sounds = true
    var haptics = true
    var speakingExercises = true
    var listeningExercises = true
    var speechRate: Double = 0.44     // AVSpeechUtterance rate
    var dailyGoal: Int = 50           // xp
    var largeText = false
    var reminderOn = false
    var reminderHour = 19
    var reminderMinute = 0
    /// Hearts and gems never run out. On by default: this build is a gift, not a shop.
    var unlimitedResources = true
    /// Optional Anthropic key. Empty = the video call uses the offline generator.
    var claudeAPIKey = ""
}

// MARK: - The whole persisted blob

struct PersistedState: Codable {
    var nativeLanguage: Language?
    var xp: Int = 0
    var gems: Int = 120
    var hearts: Int = 5
    var heartsStamp: Date = .now
    var streak: Int = 0
    var lastPracticeDay: String?
    var freezes: Int = 1
    var records: [String: LessonRecord] = [:]
    var srs: [String: SRSItem] = [:]
    var history: [DaySnapshot] = []
    var unlockedLevels: Set<String> = ["a1"]
    var settings = Settings()
    var onboarded = false
    var mistakesBank: [Pair] = []
}

// MARK: - Observable app state

@Observable
final class AppState {
    private(set) var s = PersistedState()
    var curriculum: Curriculum = .empty
    var questions: QuestionBank = .empty

    static let heartCap = 5
    static let heartRegenMinutes: Double = 25
    /// How many separate sessions a lesson node takes before the path moves on.
    static let sessionsPerLesson = 5

    // MARK: derived language config
    /// The language the user already speaks (drives the UI language).
    var native: Language { s.nativeLanguage ?? .it }
    /// The language being learned.
    var target: Language { native.other }
    var isOnboarded: Bool { s.onboarded && s.nativeLanguage != nil }

    var xp: Int { s.xp }
    var gems: Int { s.gems }
    var streak: Int { s.streak }
    var freezes: Int { s.freezes }
    var settings: Settings { get { s.settings } set { s.settings = newValue; save() } }
    var records: [String: LessonRecord] { s.records }
    var unlockedLevels: Set<String> { s.unlockedLevels }
    var mistakesBank: [Pair] { s.mistakesBank }

    /// When true the UI shows ∞ instead of counters and nothing is ever consumed.
    var unlimited: Bool { s.settings.unlimitedResources }

    var hearts: Int {
        if unlimited { return Self.heartCap }
        let regen = Int(Date.now.timeIntervalSince(s.heartsStamp) / (Self.heartRegenMinutes * 60))
        return min(Self.heartCap, s.hearts + max(0, regen))
    }

    var minutesToNextHeart: Int {
        guard hearts < Self.heartCap else { return 0 }
        let period = Self.heartRegenMinutes * 60
        let elapsed = Date.now.timeIntervalSince(s.heartsStamp).truncatingRemainder(dividingBy: period)
        return max(1, Int((period - elapsed) / 60) + 1)
    }

    var xpToday: Int { s.history.first(where: { $0.day == Self.dayKey() })?.xp ?? 0 }
    var goalProgress: Double { min(1, Double(xpToday) / Double(max(10, s.settings.dailyGoal))) }

    // MARK: - Lifecycle

    /// `persistent: false` keeps everything in memory — used by the tests so that
    /// running them never touches a real learner's saved progress.
    @ObservationIgnored private let persistent: Bool

    init(persistent: Bool = true) {
        self.persistent = persistent
        curriculum = ContentStore.loadCurriculum()
        questions = ContentStore.loadQuestions()
        if persistent, let loaded = Self.read() { s = loaded }
        normaliseHearts()
    }

    private func normaliseHearts() {
        let h = hearts
        if h != s.hearts { s.hearts = h; s.heartsStamp = .now }
    }

    // MARK: - Onboarding

    func chooseCourse(native: Language) {
        s.nativeLanguage = native
        save()
    }

    func finishOnboarding(goal: Int, startLevel: CEFR) {
        s.settings.dailyGoal = goal
        for lvl in CEFR.allCases where lvl <= startLevel { s.unlockedLevels.insert(lvl.rawValue) }
        s.onboarded = true
        save()
    }

    // MARK: - Progress queries

    func record(_ id: String) -> LessonRecord { s.records[id] ?? LessonRecord() }

    /// Sessions already finished on a node.
    func sessionsDone(_ id: String) -> Int { record(id).completions }
    /// True once the learner has seen a node at least once (drives the word list).
    func hasStarted(_ id: String) -> Bool { record(id).completions > 0 }

    func required(for node: PathNode) -> Int { node.requiredSessions }

    /// A node counts as done only when all of its sessions are finished.
    func isCompleted(_ node: PathNode) -> Bool {
        sessionsDone(node.id) >= node.requiredSessions
    }

    /// Node-id based variant used where only the identifier is at hand.
    func isCompleted(_ id: String) -> Bool {
        sessionsDone(id) >= requiredSessions(forNodeID: id)
    }

    func requiredSessions(forNodeID id: String) -> Int {
        if id.hasSuffix("-story") || id.hasSuffix("-review") { return 1 }
        return Self.sessionsPerLesson
    }

    /// The focus of the next session on this node.
    func nextFocus(for node: PathNode) -> SessionFocus {
        node.focus(forSession: sessionsDone(node.id))
    }

    /// Every node of the course in learning order.
    var orderedNodes: [PathNode] {
        curriculum.levels.flatMap { pack in
            pack.units.enumerated().flatMap { i, u in u.nodes(level: pack.level, index: i) }
        }
    }

    func nodes(for level: CEFR) -> [PathNode] {
        guard let pack = curriculum.levels.first(where: { $0.level == level }) else { return [] }
        return pack.units.enumerated().flatMap { i, u in u.nodes(level: pack.level, index: i) }
    }

    func isLevelUnlocked(_ level: CEFR) -> Bool { s.unlockedLevels.contains(level.rawValue) }

    func unlock(level: CEFR) {
        for l in CEFR.allCases where l <= level { s.unlockedLevels.insert(l.rawValue) }
        save()
    }

    /// Ordered node ids per level, computed once: the path screen asks for these
    /// on every row and the curriculum never changes at runtime.
    @ObservationIgnored private var nodeIDCache: [CEFR: [String]] = [:]

    func nodeIDs(for level: CEFR) -> [String] {
        if let cached = nodeIDCache[level] { return cached }
        let ids = nodes(for: level).map(\.id)
        nodeIDCache[level] = ids
        return ids
    }

    /// A node opens when its level is unlocked and the previous node in that level is done.
    func isUnlocked(_ node: PathNode) -> Bool {
        guard isLevelUnlocked(node.level) else { return false }
        let ids = nodeIDs(for: node.level)
        guard let idx = ids.firstIndex(of: node.id) else { return false }
        if idx == 0 { return true }
        return isCompleted(ids[idx - 1])
    }

    func currentNode(in level: CEFR) -> PathNode? {
        let list = nodes(for: level)
        return list.first { !isCompleted($0.id) } ?? list.last
    }

    /// Id of the next node to tackle, without rebuilding the node objects.
    func currentNodeID(in level: CEFR) -> String? {
        let ids = nodeIDs(for: level)
        return ids.first { !isCompleted($0) } ?? ids.last
    }

    func completion(of level: CEFR) -> Double {
        let ids = nodeIDs(for: level)
        guard !ids.isEmpty else { return 0 }
        var done = 0, total = 0
        for id in ids {
            let need = requiredSessions(forNodeID: id)
            total += need
            done += min(need, sessionsDone(id))
        }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    func completion(ofUnit unit: Unit, level: CEFR) -> Double {
        let list = unit.nodes(level: level, index: 0)
        guard !list.isEmpty else { return 0 }
        let total = list.reduce(0) { $0 + $1.requiredSessions }
        let done = list.reduce(0) { $0 + min($1.requiredSessions, sessionsDone($1.id)) }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    // MARK: - Video calls follow the path

    /// True once the first node of that unit is open, i.e. the learner got there.
    func hasReached(unitID: String) -> Bool {
        guard let level = curriculum.level(of: unitID),
              let unit = curriculum.unit(id: unitID),
              let first = unit.nodes(level: level, index: 0).first else { return false }
        return isUnlocked(first)
    }

    /// Position of a unit in the whole course, for ordering call topics.
    func courseOrder(ofUnit unitID: String) -> Int {
        curriculum.allUnits.firstIndex { $0.id == unitID } ?? Int.max
    }

    /// The unit a call at this level should revolve around: the furthest one the
    /// learner has opened there.
    func currentUnit(in level: CEFR) -> Unit? {
        let units = curriculum.levels.first { $0.level == level }?.units ?? []
        return units.last { hasReached(unitID: $0.id) } ?? units.first
    }

    /// Where a locked call becomes available, for the "coming up" label.
    func unitTitle(_ unitID: String?) -> Bilingual? {
        guard let unitID else { return nil }
        return curriculum.unit(id: unitID)?.title
    }

    // MARK: - Chapter revision

    /// Units the learner has already worked on, newest first — what "repeat a
    /// chapter" offers.
    var startedUnits: [(unit: Unit, level: CEFR)] {
        var out: [(Unit, CEFR)] = []
        for pack in curriculum.levels {
            for unit in pack.units {
                let nodes = unit.nodes(level: pack.level, index: 0)
                if nodes.contains(where: { sessionsDone($0.id) > 0 }) {
                    out.append((unit, pack.level))
                }
            }
        }
        return out.reversed().map { (unit: $0.0, level: $0.1) }
    }

    func hasStartedUnit(_ unit: Unit, level: CEFR) -> Bool {
        unit.nodes(level: level, index: 0).contains { sessionsDone($0.id) > 0 }
    }

    /// A no-hearts practice run over everything a unit teaches.
    func unitPracticeRequest(for unit: Unit, level: CEFR) -> SessionRequest {
        let pairs = Array(unit.allPairs.shuffled().prefix(24))
        let exercises = ExerciseFactory.practice(pairs: pairs,
                                                 pool: curriculum.pairsUpTo(unitID: unit.id),
                                                 native: native,
                                                 settings: settings,
                                                 count: 18,
                                                 productionBias: 0.6)
        return SessionRequest(mode: .practice,
                              customExercises: exercises,
                              customTitle: unit.title,
                              consumesHearts: false,
                              xpReward: 25)
    }

    var wordsLearned: Int { s.srs.values.filter { $0.strength >= 0.5 }.count }
    var wordsSeen: Int { s.srs.count }

    // MARK: - Session results

    func finishSession(nodeID: String, xpEarned: Int, accuracy: Double, minutes: Int, mistakes: [Pair]) {
        var r = record(nodeID)
        r.completions += 1
        r.bestAccuracy = max(r.bestAccuracy, accuracy)
        r.lastCompleted = .now
        r.crowns = min(3, (r.completions * 3) / max(1, requiredSessions(forNodeID: nodeID)))
        s.records[nodeID] = r

        addXP(xpEarned, minutes: minutes)
        s.gems += 10 + (accuracy == 1 ? 5 : 0)
        bumpStreak()

        for m in mistakes where !s.mistakesBank.contains(m) { s.mistakesBank.append(m) }
        if s.mistakesBank.count > 120 { s.mistakesBank.removeFirst(s.mistakesBank.count - 120) }
        save()
    }

    /// Marks everything a passed knowledge check covered as already learned.
    func markPassedTest(_ target: TestTarget, accuracy: Double) {
        for id in target.nodesToClear {
            var r = record(id)
            r.completions = max(r.completions, requiredSessions(forNodeID: id))
            r.bestAccuracy = max(r.bestAccuracy, accuracy)
            r.lastCompleted = .now
            r.crowns = max(r.crowns, 2)
            s.records[id] = r
        }
        if case .unlockLevel(let level) = target.kind {
            for l in CEFR.allCases where l <= level { s.unlockedLevels.insert(l.rawValue) }
        }
        bumpStreak()
        save()
    }

    func addXP(_ amount: Int, minutes: Int = 0) {
        s.xp += amount
        let key = Self.dayKey()
        if let i = s.history.firstIndex(where: { $0.day == key }) {
            s.history[i].xp += amount
            s.history[i].minutes += minutes
        } else {
            s.history.insert(DaySnapshot(day: key, xp: amount, minutes: minutes), at: 0)
        }
        if s.history.count > 400 { s.history.removeLast(s.history.count - 400) }
    }

    fileprivate func bumpStreak() {
        let today = Self.dayKey()
        guard s.lastPracticeDay != today else { return }
        if let last = s.lastPracticeDay, last == Self.dayKey(daysAgo: 1) {
            s.streak += 1
        } else if let last = s.lastPracticeDay, last < Self.dayKey(daysAgo: 1), s.freezes > 0, last == Self.dayKey(daysAgo: 2) {
            s.freezes -= 1                 // a freeze covers exactly one missed day
            s.streak += 1
        } else {
            s.streak = 1
        }
        s.lastPracticeDay = today
    }

    // MARK: - Hearts & shop

    func loseHeart() {
        guard !unlimited else { return }
        normaliseHearts()
        if s.hearts == Self.heartCap { s.heartsStamp = .now }
        s.hearts = max(0, s.hearts - 1)
        save()
    }

    func refillHearts(costingGems: Bool) -> Bool {
        if unlimited {
            s.hearts = Self.heartCap; s.heartsStamp = .now; save(); return true
        }
        if costingGems {
            guard s.gems >= 100 else { return false }
            s.gems -= 100
        }
        s.hearts = Self.heartCap
        s.heartsStamp = .now
        save()
        return true
    }

    func buyFreeze() -> Bool {
        if unlimited, s.freezes < 2 { s.freezes += 1; save(); return true }
        guard s.gems >= 200, s.freezes < 2 else { return false }
        s.gems -= 200; s.freezes += 1; save(); return true
    }

    // MARK: - SRS

    func gradePair(_ pair: Pair, correct: Bool) {
        var item = s.srs[pair.id] ?? SRSItem(pairID: pair.id)
        item.grade(correct: correct)
        s.srs[pair.id] = item
    }

    func strength(of pair: Pair) -> Double { s.srs[pair.id]?.strength ?? 0 }

    /// Pairs that are due for review, weakest first.
    func duePairs(limit: Int = 40) -> [Pair] {
        let all = curriculum.allPairs
        // the same translation can legitimately be taught in more than one lesson,
        // so collapse duplicates instead of trapping on them
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let due = s.srs.values
            .filter { $0.due <= .now && $0.strength < 1 }
            .sorted { $0.strength < $1.strength }
            .compactMap { byID[$0.pairID] }
        return Array(due.prefix(limit))
    }

    func clearMistakes() { s.mistakesBank.removeAll(); save() }

    // MARK: - Reset

    func resetEverything() {
        s = PersistedState()
        save()
    }

    // MARK: - Persistence

    static func dayKey(daysAgo: Int = 0, from date: Date = .now) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: date) ?? date
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("uzbelia-state.json")
    }

    private static func read() -> PersistedState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }

    func save() {
        guard persistent else { return }
        let snapshot = s
        Task.detached(priority: .background) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: AppState.fileURL, options: .atomic)
        }
    }
}

// MARK: - Forgiving decoding for the saved profile
// Every field falls back to its default so that adding new state in a future
// version never wipes a learner's progress.

extension Settings {
    enum CodingKeys: String, CodingKey {
        case sounds, haptics, speakingExercises, listeningExercises, speechRate, dailyGoal, largeText
        case reminderOn, reminderHour, reminderMinute, unlimitedResources, claudeAPIKey
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sounds = try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? true
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        speakingExercises = try c.decodeIfPresent(Bool.self, forKey: .speakingExercises) ?? true
        listeningExercises = try c.decodeIfPresent(Bool.self, forKey: .listeningExercises) ?? true
        speechRate = try c.decodeIfPresent(Double.self, forKey: .speechRate) ?? 0.44
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? 50
        largeText = try c.decodeIfPresent(Bool.self, forKey: .largeText) ?? false
        reminderOn = try c.decodeIfPresent(Bool.self, forKey: .reminderOn) ?? false
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 19
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        unlimitedResources = try c.decodeIfPresent(Bool.self, forKey: .unlimitedResources) ?? true
        claudeAPIKey = try c.decodeIfPresent(String.self, forKey: .claudeAPIKey) ?? ""
    }
}

extension LessonRecord {
    enum CodingKeys: String, CodingKey { case completions, bestAccuracy, lastCompleted, crowns }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completions = try c.decodeIfPresent(Int.self, forKey: .completions) ?? 0
        bestAccuracy = try c.decodeIfPresent(Double.self, forKey: .bestAccuracy) ?? 0
        lastCompleted = try c.decodeIfPresent(Date.self, forKey: .lastCompleted)
        crowns = try c.decodeIfPresent(Int.self, forKey: .crowns) ?? 0
    }
}

extension SRSItem {
    enum CodingKeys: String, CodingKey { case pairID, strength, due, reps, lapses }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pairID = try c.decode(String.self, forKey: .pairID)
        strength = try c.decodeIfPresent(Double.self, forKey: .strength) ?? 0
        due = try c.decodeIfPresent(Date.self, forKey: .due) ?? .now
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        lapses = try c.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
    }
}

extension PersistedState {
    enum CodingKeys: String, CodingKey {
        case nativeLanguage, xp, gems, hearts, heartsStamp, streak, lastPracticeDay, freezes
        case records, srs, history, unlockedLevels, settings, onboarded, mistakesBank
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nativeLanguage = try c.decodeIfPresent(Language.self, forKey: .nativeLanguage)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        gems = try c.decodeIfPresent(Int.self, forKey: .gems) ?? 120
        hearts = try c.decodeIfPresent(Int.self, forKey: .hearts) ?? 5
        heartsStamp = try c.decodeIfPresent(Date.self, forKey: .heartsStamp) ?? .now
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastPracticeDay = try c.decodeIfPresent(String.self, forKey: .lastPracticeDay)
        freezes = try c.decodeIfPresent(Int.self, forKey: .freezes) ?? 1
        records = try c.decodeIfPresent([String: LessonRecord].self, forKey: .records) ?? [:]
        srs = try c.decodeIfPresent([String: SRSItem].self, forKey: .srs) ?? [:]
        history = try c.decodeIfPresent([DaySnapshot].self, forKey: .history) ?? []
        unlockedLevels = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedLevels) ?? ["a1"]
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        mistakesBank = try c.decodeIfPresent([Pair].self, forKey: .mistakesBank) ?? []
    }
}
