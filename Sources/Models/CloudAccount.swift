import Foundation
import Observation

/// The account, and the progress that follows it.
///
/// Signed out, the app is exactly what it was: one JSON file in Application Support.
/// Signed in, that file gains a twin on Firestore — pushed a few seconds after every
/// change, pulled and **merged** on every sign-in. The merge is in
/// `PersistedState.merged(with:)` and it is deliberately additive, so plugging in a
/// second phone, or reinstalling on the first, can only ever add lessons back.
@MainActor
@Observable
final class CloudAccount {

    enum Status: Equatable {
        case signedOut
        case working
        case synced(Date)
        case failed(Bilingual)
    }

    private(set) var session: FirebaseClient.Session?
    private(set) var status: Status = .signedOut
    /// Set while a sign-in or a manual sync is in flight, so buttons can spin.
    private(set) var busy = false

    var isSignedIn: Bool { session != nil }
    var email: String { session?.email ?? "" }
    /// False when the two strings in `Secrets` are still empty: the whole section
    /// then stays off the screen rather than offering something that cannot work.
    var isAvailable: Bool { FirebaseClient.isConfigured }

    private weak var state: AppState?
    private var uploadTask: Task<Void, Never>?

    private enum Stored {
        static let refresh = "refreshToken"
        static let email = "email"
        static let uid = "uid"
    }

    // MARK: - Lifecycle

    /// Built alongside `AppState`, which is not itself tied to the main actor;
    /// everything this class then goes on to do is.
    nonisolated init() {}

    func attach(to state: AppState) {
        self.state = state
        guard isAvailable, let refresh = Keychain.get(Stored.refresh),
              let email = Keychain.get(Stored.email), let uid = Keychain.get(Stored.uid) else { return }
        // A stored refresh token is a signed-in account; the short-lived one it
        // trades for is fetched on the first call that needs it.
        session = FirebaseClient.Session(uid: uid, email: email, idToken: "",
                                         refreshToken: refresh, expires: .distantPast)
        status = .synced(.distantPast)
        Task { await self.syncNow(quietly: true) }
    }

    // MARK: - Signing in and up

    func signUp(email: String, password: String) async {
        await authenticate { try await FirebaseClient.signUp(email: Self.tidy(email), password: password) }
    }

    func signIn(email: String, password: String) async {
        await authenticate { try await FirebaseClient.signIn(email: Self.tidy(email), password: password) }
    }

    private func authenticate(via provider: FirebaseClient.Federated? = nil,
                              _ work: () async throws -> FirebaseClient.Session) async {
        guard isAvailable else { status = .failed(FirebaseClient.Failure.notConfigured.message); return }
        busy = true
        status = .working
        defer { busy = false }
        do {
            let new = try await work()
            remember(new)
            // Da qui in poi l'accesso è riuscito: se il server non si fa sentire,
            // resta una sincronizzazione da riprovare, non un login da rifare.
            do {
                try await pullMergePush()
                status = .synced(.now)
            } catch {
                status = .synced(.distantPast)
            }
        } catch SocialSignIn.Failure.cancelled {
            // She closed the sheet: not a failure, and nothing to shout about.
            status = .signedOut
        } catch {
            forget()
            status = .failed(Self.describe(error, provider: provider))
        }
    }

    /// Apple: a system sheet, a token, and the same session as any other route.
    func signInWithApple() async {
        await authenticate(via: .apple) {
            let identity = try await SocialSignIn.apple()
            return try await FirebaseClient.signIn(idToken: identity.idToken,
                                                   provider: .apple,
                                                   rawNonce: identity.rawNonce,
                                                   fallbackEmail: identity.email)
        }
    }

    func signInWithGoogle() async {
        await authenticate(via: .google) {
            let token = try await SocialSignIn.google()
            return try await FirebaseClient.signIn(idToken: token, provider: .google)
        }
    }

    func sendPasswordReset(to email: String) async -> Bilingual? {
        do {
            try await FirebaseClient.sendPasswordReset(to: Self.tidy(email))
            return nil
        } catch {
            return Self.describe(error)
        }
    }

    /// Leaves the progress on this phone untouched — signing out is not losing a
    /// week's work, and the server copy is still there to sign back into.
    func signOut() {
        uploadTask?.cancel()
        forget()
        status = .signedOut
    }

    /// Removes the account and the document behind it, for good.
    func deleteAccount() async -> Bilingual? {
        guard let _ = session else { return nil }
        busy = true
        defer { busy = false }
        do {
            let fresh = try await validSession()
            try? await FirebaseClient.deleteDocument(session: fresh)
            try await FirebaseClient.deleteAccount(idToken: fresh.idToken)
            forget()
            status = .signedOut
            return nil
        } catch {
            let message = Self.describe(error)
            status = .failed(message)
            return message
        }
    }

    // MARK: - Syncing

    /// Called by hand from Profilo, and once on launch.
    func syncNow(quietly: Bool = false) async {
        guard isSignedIn else { return }
        if !quietly { busy = true; status = .working }
        defer { busy = false }
        do {
            try await pullMergePush()
            status = .synced(.now)
        } catch {
            // A launch with no signal must not look like a failed login.
            if !quietly { status = .failed(Self.describe(error)) }
        }
    }

    /// Every `AppState.save()` lands here. Uploading on each one would mean a request
    /// per answered question, so the writes are gathered up and sent once things go
    /// quiet — and a session that ends mid-upload simply sends again next launch.
    nonisolated func scheduleUpload() {
        Task { @MainActor in
            guard self.isSignedIn else { return }
            self.uploadTask?.cancel()
            self.uploadTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                do {
                    try await self.push()
                    self.status = .synced(.now)
                } catch {
                    // Offline is not an error worth shouting about: the next save retries.
                }
            }
        }
    }

    private func pullMergePush() async throws {
        guard let state else { return }
        let fresh = try await validSession()
        do {
            let remote = try await FirebaseClient.fetch(session: fresh)
            let theirs = try PersistedState.unpacked(remote.blob)
            state.adopt(state.snapshot.merged(with: theirs))
        } catch FirebaseClient.Failure.noDocument {
            // First sign-in on a brand new account: there is nothing to merge, and
            // what this phone already holds becomes the first version on the server.
        }
        try await push()
    }

    private func push() async throws {
        guard let state else { return }
        let fresh = try await validSession()
        let payload = state.snapshot.uploadable
        let snapshot = FirebaseClient.Snapshot(blob: try payload.packed(),
                                               updatedAt: .now,
                                               xp: payload.xp,
                                               streak: payload.streak)
        try await FirebaseClient.upload(snapshot, session: fresh)
    }

    /// An id token lasts an hour; this is what quietly buys the next one.
    private func validSession() async throws -> FirebaseClient.Session {
        guard let current = session else { throw FirebaseClient.Failure.signedOut }
        if current.isFresh, !current.idToken.isEmpty { return current }
        do {
            let renewed = try await FirebaseClient.refresh(current.refreshToken, email: current.email)
            remember(renewed)
            return renewed
        } catch FirebaseClient.Failure.auth(let code) {
            // The refresh token itself was rejected — the password changed, or the
            // account is gone. Nothing to retry: ask for the password again.
            forget()
            status = .failed(FirebaseClient.Failure.auth(code).message)
            throw FirebaseClient.Failure.signedOut
        }
    }

    // MARK: - Where the session is kept

    private func remember(_ new: FirebaseClient.Session) {
        session = new
        Keychain.set(new.refreshToken, for: Stored.refresh)
        Keychain.set(new.email, for: Stored.email)
        Keychain.set(new.uid, for: Stored.uid)
    }

    private func forget() {
        session = nil
        Keychain.remove(Stored.refresh)
        Keychain.remove(Stored.email)
        Keychain.remove(Stored.uid)
    }

    private static func tidy(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func describe(_ error: Error,
                                 provider: FirebaseClient.Federated? = nil) -> Bilingual {
        // "Non abilitato" senza dire cosa manda a cercare nel posto sbagliato: il
        // pulsante che si è appena toccato è l'unica informazione che serve.
        if case FirebaseClient.Failure.auth(let code) = error,
           code.hasPrefix("OPERATION_NOT_ALLOWED"), let provider {
            let name = provider == .apple ? "Apple" : "Google"
            return Bilingual(it: "Accesso con \(name) non è abilitato nel progetto Firebase.",
                             uz: "\(name) orqali kirish Firebase loyihasida yoqilmagan.")
        }
        if let failure = error as? FirebaseClient.Failure { return failure.message }
        if let failure = error as? SocialSignIn.Failure { return failure.message }
        let urlError = error as? URLError
        if urlError?.code == .notConnectedToInternet || urlError?.code == .timedOut {
            return Bilingual(it: "Nessuna connessione. I progressi restano salvati sul telefono.",
                             uz: "Internet yo'q. Yutuqlar telefonda saqlanib qoladi.")
        }
        return Bilingual(it: error.localizedDescription, uz: error.localizedDescription)
    }
}
