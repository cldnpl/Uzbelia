import Foundation

/// The pool of open questions a video call is assembled from.
struct QuestionBank: Codable {
    /// Level → slot ("open" / "follow" / "close") → variants.
    var generic: [String: [String: [Bilingual]]]
    /// Unit id → questions that use that unit's vocabulary.
    var units: [String: [Bilingual]]
    /// Unit id → for each of its questions, in the same order, the two that follow on
    /// from it whatever she answered: one a step deeper, one a step to the side.
    var follow: [String: [[Bilingual]]] = [:]

    static let empty = QuestionBank(generic: [:], units: [:])

    func generic(_ level: CEFR, _ slot: String) -> [Bilingual] {
        generic[level.rawValue]?[slot] ?? []
    }
    func questions(forUnit id: String) -> [Bilingual] { units[id] ?? [] }

    func followUps(forUnit id: String, question index: Int) -> [Bilingual] {
        guard let all = follow[id], all.indices.contains(index) else { return [] }
        return all[index]
    }

    private enum CodingKeys: String, CodingKey { case generic, units, follow }

    init(generic: [String: [String: [Bilingual]]], units: [String: [Bilingual]],
         follow: [String: [[Bilingual]]] = [:]) {
        self.generic = generic
        self.units = units
        self.follow = follow
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generic = try c.decode([String: [String: [Bilingual]]].self, forKey: .generic)
        units = try c.decode([String: [Bilingual]].self, forKey: .units)
        follow = try c.decodeIfPresent([String: [[Bilingual]]].self, forKey: .follow) ?? [:]
    }
}

/// One thing Anorcha asks during a call.
struct CallQuestion: Identifiable, Hashable {
    enum Origin: Hashable {
        case opening
        case unit(String)       // the unit it draws its vocabulary from
        case followUp
        case closing
        case generated          // written by Claude, when a key is configured
    }
    let id = UUID()
    var text: Bilingual
    var origin: Origin
    /// Words from that unit the learner could reasonably use — the review checks against these.
    var suggestedVocabulary: [Pair] = []
    /// What Anorcha says just before asking — "tell me something" — when
    /// the question opens a new subject rather than following on from the last answer.
    var lead: Bilingual? = nil

    var unitID: String? {
        if case .unit(let id) = origin { return id }
        return nil
    }

    /// The whole line as it is spoken: the lead-in, if any, then the question.
    func spoken(in language: Language) -> String {
        guard let lead else { return text[language] }
        return lead[language] + " " + text[language]
    }
}

/// Everything a single call is made of.
struct CallPlan {
    var level: CEFR
    /// The unit the learner is actually at, which the questions revolve around.
    var focusUnit: Unit?
    var questions: [CallQuestion]
    var generatedByAI: Bool = false

    var title: Bilingual {
        guard let focusUnit else {
            return Bilingual("\(level.label) conversation")
        }
        return focusUnit.title
    }
}
