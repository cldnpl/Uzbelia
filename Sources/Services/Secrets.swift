import Foundation

/// The key built into the app.
///
/// Paste a Gemini API key between the quotes below and the assistant is simply on:
/// no provider to pick, no key to type in Profilo, nothing to set up on a new phone.
/// The field in *Profilo → Assistente IA* still works and still wins, for when you
/// want to try a different key without touching the code.
///
/// A Gemini key looks like `AIzaSy…` and comes from `aistudio.google.com/apikey`.
/// Anything shorter-lived — an OAuth access token, the kind that starts with `AQ.` or
/// `ya29.` — expires within the hour and is not what goes here.
///
/// Two things to know before pasting:
///
/// 1. A key compiled into an app can be read back out of the app bundle. That is fine
///    for a phone that is yours, and not fine for an app you hand to other people.
/// 2. This file is tracked by git, so an edit here would otherwise end up in a commit.
///    Keep your key out of the history with:
///
///        git update-index --skip-worktree Sources/Services/Secrets.swift
///
///    (and `--no-skip-worktree` if you ever need to change the file itself).
enum Secrets {

    /// ↓ paste the key here ↓
    static let geminiKey = ""

    /// A Claude key, if you would rather use that one. Same rules.
    static let claudeKey = ""

    /// Which assistant the app ships with, if any.
    static var builtIn: (provider: AIProvider, key: String)? {
        if !trimmed(geminiKey).isEmpty { return (.gemini, trimmed(geminiKey)) }
        if !trimmed(claudeKey).isEmpty { return (.claude, trimmed(claudeKey)) }
        return nil
    }

    private static func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
