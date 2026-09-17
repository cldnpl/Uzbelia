import Foundation

/// The pool of open questions a video call is assembled from.
struct QuestionBank: Codable {
    /// Level → slot ("open" / "follow" / "close") → variants.
    var generic: [String: [String: [Bilingual]]]
    /// Unit id → questions that use that unit's vocabulary.
    var units: [String: [Bilingual]]

    static let empty = QuestionBank(generic: [:], units: [:])

    func generic(_ level: CEFR, _ slot: String) -> [Bilingual] {
        generic[level.rawValue]?[slot] ?? []
    }
    func questions(forUnit id: String) -> [Bilingual] { units[id] ?? [] }
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

    var unitID: String? {
        if case .unit(let id) = origin { return id }
        return nil
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
            return Bilingual(it: "Conversazione \(level.label)", uz: "\(level.label) suhbati")
        }
        return focusUnit.title
    }
}
