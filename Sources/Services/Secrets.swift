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

    /// ↓ and the Azure Speech key here ↓
    ///
    /// This one is what gives Uzbek a real voice (`uz-UZ-MadinaNeural`) instead of the
    /// Turkish stand-in iOS falls back to, and real Uzbek ears for the pronunciation
    /// exercises. It is a different key from the Gemini one, from a different company.
    ///
    /// Where to get it: `portal.azure.com` → Create a resource → *Speech* → pricing
    /// tier **F0** (free: 500.000 caratteri di voce e 5 ore di ascolto al mese) →
    /// once created, *Keys and Endpoint* gives you KEY 1 and the Location/Region.
    /// The region is the short name shown there, like `westeurope` or `italynorth`.
    static let azureSpeechKey = ""
    static let azureSpeechRegion = ""

    /// ↓ and the two Firebase strings here ↓
    ///
    /// **Non serve scriverle a mano.** Un comando solo crea il progetto, registra
    /// l'app iOS, accende Email, Apple e Google, mette le regole di Firestore e
    /// riempie le tre righe qui sotto:
    ///
    ///     ./scripts/crea-progetto-firebase.sh
    ///
    /// Chiede solo il login Google nel browser, una volta. Quel che segue è il
    /// percorso a mano, per chi preferisce vedere dove sta ogni cosa.
    ///
    /// These are what give the app accounts, so that progress lives on a server and
    /// survives a reinstall or a new phone. Both come from one place:
    ///
    ///   console.firebase.google.com → create a project → ⚙ Project settings
    ///     · **Project ID**          — the line right at the top ("uzbelia-1a2b3")
    ///     · **Web API Key**         — a little further down, an `AIzaSy…` string
    ///
    /// Then, still in the console, two switches have to be flipped:
    ///     · Build → **Authentication** → Get started → Sign-in method →
    ///       enable **Email/Password**
    ///     · Build → **Firestore Database** → Create database (any region)
    ///
    /// and the security rules (Firestore → Rules) set so that each learner can only
    /// ever touch her own document:
    ///
    ///     rules_version = '2';
    ///     service cloud.firestore {
    ///       match /databases/{db}/documents {
    ///         match /learners/{uid} {
    ///           allow read, write: if request.auth != nil && request.auth.uid == uid;
    ///         }
    ///       }
    ///     }
    ///
    /// The Web API key is not a secret in the way the others here are — it only names
    /// the project, and the rules above are what actually keep the data private. Left
    /// empty, the whole account section simply disappears and the app saves on the
    /// phone alone, exactly as it did before.
    static let firebaseAPIKey = ""
    static let firebaseProjectID = ""

    /// ↓ and, only if you want the Google button, the iOS OAuth client id here ↓
    ///
    /// *Accedi con Apple* needs nothing here: it is a system framework and the only
    /// switch is Firebase console → Authentication → Sign-in method → **Apple**.
    ///
    /// Google needs one string, e nasce da sé: basta registrare un'app **iOS** nel
    /// progetto Firebase con il bundle `com.uzbelia.app` e Firebase crea il client
    /// OAuth iOS insieme a lei. Lo trovi nel `GoogleService-Info.plist` alla voce
    /// `CLIENT_ID`, o su Google Cloud console → *APIs & Services → Credentials*.
    /// Ha questa forma: `1234567890-abcdefg.apps.googleusercontent.com`.
    ///
    /// Va anche abilitato **Google** in Firebase → Authentication → Sign-in method.
    ///
    /// Nothing has to go in Info.plist: the sign-in window listens for the redirect
    /// itself. Left empty, the Google button simply does not appear — che è il
    /// comportamento giusto, perché senza client id non potrebbe fare altro che
    /// aprirsi e scusarsi.
    static let googleOAuthClientID = ""

    /// Which of the two Uzbek voices reads the course.
    static let uzbekVoice = AzureSpeech.Voice.madina

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
