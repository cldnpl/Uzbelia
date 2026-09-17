import Foundation

/// A second opinion on a free answer the grader turned down.
///
/// A course lists one wording per phrase, but a language has several: "a domani" is
/// `ertaga ko'rishguncha` in the book and `ertagacha` in the street, and both are
/// right. Three layers decide, cheapest first — what the course itself teaches, what
/// she has already had accepted, and only then the assistant.
enum AnswerJudge {

    /// Which questions can have more than one right answer.
    ///
    /// Dictation has exactly one (you write what you hear), and a multiple choice has
    /// whatever is on the buttons. Only a translation she writes herself is open.
    static func isOpen(_ kind: Exercise.Kind) -> Bool {
        switch kind {
        case .type, .wordBank: return true
        case .choice, .listenChoice, .listenType, .speak, .match, .fillBlank: return false
        }
    }

    // MARK: - Offline

    /// True when the course itself already vouches for this wording: somewhere in the
    /// curriculum, what she wrote is given as a translation of the very thing she was
    /// asked to translate.
    static func courseAgrees(_ given: String, with exercise: Exercise) -> Bool {
        let asked = Grader.alternatives(exercise.prompt).map(Grader.normalise)
        guard !asked.isEmpty, !Grader.normalise(given).isEmpty else { return false }
        guard let meaning = Glossary.look(up: given, from: exercise.answerLanguage),
              !meaning.literal else { return false }
        return meaning.text.components(separatedBy: " / ")
            .map(Grader.normalise)
            .contains { asked.contains($0) }
    }

    /// True when this exact wording has been accepted for this answer before.
    static func alreadyAccepted(_ given: String, remembered: [String]) -> Bool {
        let g = Grader.normalise(given)
        return !g.isEmpty && remembered.contains(g)
    }

    /// The offline verdict, or nil when only the assistant can settle it.
    static func offline(_ given: String, for exercise: Exercise, remembered: [String]) -> Verdict? {
        guard isOpen(exercise.kind), !given.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if alreadyAccepted(given, remembered: remembered) || courseAgrees(given, with: exercise) {
            return .alternative(canonical: exercise.answer, note: nil)
        }
        return nil
    }

    // MARK: - The assistant

    /// Asks whether what she wrote is another way of saying the same thing.
    ///
    /// Returns nil whenever it cannot tell — no key, no network, an unreadable reply —
    /// and the grader's own "wrong" stands. Being unsure never costs her a heart she
    /// should have kept, and never hands her one she should not.
    static func secondOpinion(_ given: String,
                              for exercise: Exercise,
                              level: CEFR,
                              native: Language,
                              provider: AIProvider,
                              apiKey: String) async -> Verdict? {
        guard isOpen(exercise.kind),
              !given.trimmingCharacters(in: .whitespaces).isEmpty,
              AIClient.isConfigured(provider: provider, key: apiKey) else { return nil }
        do {
            let ruling = try await AIClient.judge(provider: provider, key: apiKey,
                                                  asked: exercise.prompt,
                                                  askedLanguage: exercise.promptLanguage,
                                                  expected: exercise.answer,
                                                  given: given,
                                                  answerLanguage: exercise.answerLanguage,
                                                  native: native, level: level)
            guard ruling.acceptable else { return nil }
            let note = ruling.note.trimmingCharacters(in: .whitespacesAndNewlines)
            return .alternative(canonical: exercise.answer, note: note.isEmpty ? nil : note)
        } catch {
            return nil
        }
    }
}
