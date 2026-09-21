import Foundation

/// Firebase, without the Firebase SDK.
///
/// Everything the app needs from Firebase is two ordinary REST APIs — Identity
/// Toolkit for the account and Firestore for the one document that learner owns — so
/// it talks to them over URLSession, exactly as it already talks to Gemini. No
/// package to resolve, no `GoogleService-Info.plist` to keep in step with the build,
/// no minutes added to every compile: the two strings in `Secrets` are the entire
/// configuration, and without them the app is what it always was, a file on a phone.
enum FirebaseClient {

    static var apiKey: String { Secrets.firebaseAPIKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    static var projectID: String { Secrets.firebaseProjectID.trimmingCharacters(in: .whitespacesAndNewlines) }
    static var isConfigured: Bool { !apiKey.isEmpty && !projectID.isEmpty }

    /// The collection each learner's single document lives in.
    static let collection = "learners"

    // MARK: - Errors

    enum Failure: LocalizedError, Equatable {
        /// The console strings in `Secrets` are still empty.
        case notConfigured
        /// Identity Toolkit's own code, e.g. `EMAIL_EXISTS`.
        case auth(String)
        case http(Int, String)
        case noDocument
        case decoding
        /// The session is over and could not be renewed: sign in again.
        case signedOut

        var errorDescription: String? { message.it }

        /// Said in both interface languages, because every screen in this app is.
        var message: Bilingual {
            switch self {
            case .notConfigured:
                return Bilingual(it: "Account non configurato in questa build.",
                                 uz: "Bu versiyada akkaunt sozlanmagan.")
            case .auth(let code):
                return Self.explain(code)
            case .http(let code, let body):
                let detail = AIClient.readableMessage(from: body)
                return Bilingual(it: "Errore del server (\(code)). \(detail)",
                                 uz: "Server xatosi (\(code)). \(detail)")
            case .noDocument:
                return Bilingual(it: "Nessun progresso salvato sul server.",
                                 uz: "Serverda saqlangan yutuq yo'q.")
            case .decoding:
                return Bilingual(it: "Risposta del server non leggibile.",
                                 uz: "Server javobini o'qib bo'lmadi.")
            case .signedOut:
                return Bilingual(it: "Sessione scaduta: accedi di nuovo.",
                                 uz: "Sessiya tugadi: qayta kiring.")
            }
        }

        /// Identity Toolkit answers with machine codes; these are the ones a learner
        /// can actually hit, said the way a person would say them.
        private static func explain(_ code: String) -> Bilingual {
            switch code.split(separator: ":").first.map(String.init)?
                       .trimmingCharacters(in: .whitespaces) ?? code {
            case "EMAIL_EXISTS":
                return Bilingual(it: "Questa email ha già un account. Accedi invece di registrarti.",
                                 uz: "Bu email allaqachon ro'yxatdan o'tgan. Ro'yxatdan o'tish o'rniga kiring.")
            case "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND":
                return Bilingual(it: "Email o password non corrette.",
                                 uz: "Email yoki parol noto'g'ri.")
            case "WEAK_PASSWORD":
                return Bilingual(it: "La password deve avere almeno 6 caratteri.",
                                 uz: "Parol kamida 6 belgidan iborat bo'lishi kerak.")
            case "INVALID_EMAIL":
                return Bilingual(it: "Questa email non è scritta bene.",
                                 uz: "Bu email noto'g'ri yozilgan.")
            case "TOO_MANY_ATTEMPTS_TRY_LATER":
                return Bilingual(it: "Troppi tentativi. Riprova fra qualche minuto.",
                                 uz: "Juda ko'p urinish. Bir necha daqiqadan keyin qayta urinib ko'ring.")
            case "USER_DISABLED":
                return Bilingual(it: "Questo account è stato disattivato.",
                                 uz: "Bu akkaunt o'chirilgan.")
            case "CREDENTIAL_TOO_OLD_LOGIN_AGAIN", "TOKEN_EXPIRED", "USER_NOT_FOUND":
                return Bilingual(it: "Sessione scaduta: accedi di nuovo.",
                                 uz: "Sessiya tugadi: qayta kiring.")
            case "OPERATION_NOT_ALLOWED":
                return Bilingual(it: "Questo modo di accedere non è abilitato nel progetto Firebase.",
                                 uz: "Bu kirish usuli Firebase loyihasida yoqilmagan.")
            case "MISSING_OR_INVALID_NONCE":
                return Bilingual(it: "Apple e il server non si sono trovati d'accordo. Riprova.",
                                 uz: "Apple va server kelisha olmadi. Qayta urinib ko'ring.")
            case "INVALID_IDP_RESPONSE", "INVALID_IDENTIFIER":
                return Bilingual(it: "Il provider ha risposto in un modo che il server non accetta. Riprova.",
                                 uz: "Provayder javobini server qabul qilmadi. Qayta urinib ko'ring.")
            case "FEDERATED_USER_ID_ALREADY_LINKED":
                return Bilingual(it: "Questo profilo è già legato a un altro account. Accedi con quello.",
                                 uz: "Bu profil boshqa akkauntga bog'langan. O'sha bilan kiring.")
            default:
                return Bilingual(it: "Accesso non riuscito (\(code)).",
                                 uz: "Kirish amalga oshmadi (\(code)).")
            }
        }
    }

    // MARK: - What a signed-in session is made of

    struct Session: Equatable {
        var uid: String
        var email: String
        var idToken: String
        var refreshToken: String
        /// When `idToken` stops being accepted. Firebase issues them for an hour.
        var expires: Date

        var isFresh: Bool { expires > Date().addingTimeInterval(60) }
    }

    private struct AuthResponse: Decodable {
        let idToken: String
        let email: String?
        let refreshToken: String
        let expiresIn: String
        let localId: String
    }

    private struct RefreshResponse: Decodable {
        let id_token: String
        let refresh_token: String
        let expires_in: String
        let user_id: String
    }

    // MARK: - Accounts

    static func signUp(email: String, password: String) async throws -> Session {
        try await authenticate(endpoint: "accounts:signUp", email: email, password: password)
    }

    static func signIn(email: String, password: String) async throws -> Session {
        try await authenticate(endpoint: "accounts:signInWithPassword", email: email, password: password)
    }

    private static func authenticate(endpoint: String, email: String, password: String) async throws -> Session {
        guard isConfigured else { throw Failure.notConfigured }
        let decoded: AuthResponse = try await post(
            url: identityURL(endpoint),
            body: ["email": email, "password": password, "returnSecureToken": true])
        return session(from: decoded, fallbackEmail: email)
    }

    /// Signs in with an identity token from Apple or Google.
    ///
    /// Same endpoint for both, and the session that comes back is indistinguishable
    /// from one bought with an email and a password — including the uid, which is
    /// what makes the progress document the same document.
    static func signIn(idToken: String,
                       provider: Federated,
                       rawNonce: String? = nil,
                       fallbackEmail: String? = nil) async throws -> Session {
        guard isConfigured else { throw Failure.notConfigured }
        var body = "id_token=\(idToken)&providerId=\(provider.rawValue)"
        // Apple signs a hashed nonce; Firebase needs the original to check it.
        if let rawNonce { body += "&nonce=\(rawNonce)" }
        let decoded: AuthResponse = try await post(
            url: identityURL("accounts:signInWithIdp"),
            body: ["postBody": body,
                   "requestUri": "https://\(projectID).firebaseapp.com",
                   "returnIdpCredential": true,
                   "returnSecureToken": true])
        // Apple manda l'indirizzo una volta sola, alla primissima registrazione: se
        // Firebase non lo ripete, quello che Apple ha appena dato all'app è l'unico
        // che ci sia, e senza di lui Profilo mostrerebbe una riga vuota per sempre.
        return session(from: decoded, fallbackEmail: fallbackEmail ?? "")
    }

    enum Federated: String {
        case apple = "apple.com"
        case google = "google.com"

        var label: Bilingual {
            switch self {
            case .apple: return Bilingual(it: "Continua con Apple", uz: "Apple bilan davom etish")
            case .google: return Bilingual(it: "Continua con Google", uz: "Google bilan davom etish")
            }
        }
    }

    /// Trades the long-lived refresh token for a new hour of access.
    static func refresh(_ refreshToken: String, email: String) async throws -> Session {
        guard isConfigured else { throw Failure.notConfigured }
        var request = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = "grant_type=refresh_token&refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? refreshToken)"
        request.httpBody = Data(form.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        guard let decoded = try? JSONDecoder().decode(RefreshResponse.self, from: data) else {
            throw Failure.decoding
        }
        return Session(uid: decoded.user_id, email: email,
                       idToken: decoded.id_token, refreshToken: decoded.refresh_token,
                       expires: Date().addingTimeInterval(Double(decoded.expires_in) ?? 3600))
    }

    /// Sends the "forgot my password" email Firebase writes itself.
    static func sendPasswordReset(to email: String) async throws {
        guard isConfigured else { throw Failure.notConfigured }
        let _: EmptyReply = try await post(url: identityURL("accounts:sendOobCode"),
                                           body: ["requestType": "PASSWORD_RESET", "email": email])
    }

    /// Wipes the account itself, not just this phone's copy of it.
    static func deleteAccount(idToken: String) async throws {
        let _: EmptyReply = try await post(url: identityURL("accounts:delete"),
                                           body: ["idToken": idToken])
    }

    private struct EmptyReply: Decodable {}

    private static func session(from r: AuthResponse, fallbackEmail: String) -> Session {
        Session(uid: r.localId, email: r.email ?? fallbackEmail,
                idToken: r.idToken, refreshToken: r.refreshToken,
                expires: Date().addingTimeInterval(Double(r.expiresIn) ?? 3600))
    }

    private static func identityURL(_ endpoint: String) -> URL {
        URL(string: "https://identitytoolkit.googleapis.com/v1/\(endpoint)?key=\(apiKey)")!
    }

    // MARK: - The learner's one document

    /// What is actually stored: the saved profile, zipped, plus a couple of plain
    /// fields so the Firebase console is readable at a glance.
    struct Snapshot {
        var blob: Data
        var updatedAt: Date
        var xp: Int
        var streak: Int
    }

    private struct Document: Decodable {
        struct Value: Decodable {
            let stringValue: String?
            let integerValue: String?
            let timestampValue: String?
            let bytesValue: String?
        }
        let fields: [String: Value]?
    }

    static func fetch(session: Session) async throws -> Snapshot {
        guard isConfigured else { throw Failure.notConfigured }
        var request = URLRequest(url: documentURL(uid: session.uid))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(session.idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { throw Failure.noDocument }
        try check(response, data)
        guard let doc = try? JSONDecoder().decode(Document.self, from: data),
              let fields = doc.fields,
              let encoded = fields["blob"]?.bytesValue,
              let blob = Data(base64Encoded: encoded) else { throw Failure.noDocument }

        return Snapshot(blob: blob,
                        updatedAt: fields["updatedAt"]?.timestampValue.flatMap(parse) ?? .distantPast,
                        xp: Int(fields["xp"]?.integerValue ?? "0") ?? 0,
                        streak: Int(fields["streak"]?.integerValue ?? "0") ?? 0)
    }

    static func upload(_ snapshot: Snapshot, session: Session) async throws {
        guard isConfigured else { throw Failure.notConfigured }
        var request = URLRequest(url: documentURL(uid: session.uid))
        request.httpMethod = "PATCH"          // creates the document if it is not there yet
        request.timeoutInterval = 30
        request.setValue("Bearer \(session.idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "fields": [
                "blob": ["bytesValue": snapshot.blob.base64EncodedString()],
                "updatedAt": ["timestampValue": format(snapshot.updatedAt)],
                "xp": ["integerValue": String(snapshot.xp)],
                "streak": ["integerValue": String(snapshot.streak)],
            ],
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
    }

    static func deleteDocument(session: Session) async throws {
        guard isConfigured else { throw Failure.notConfigured }
        var request = URLRequest(url: documentURL(uid: session.uid))
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.setValue("Bearer \(session.idToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return }
        try check(response, data)
    }

    private static func documentURL(uid: String) -> URL {
        URL(string: "https://firestore.googleapis.com/v1/projects/\(projectID)"
            + "/databases/(default)/documents/\(collection)/\(uid)")!
    }

    // MARK: - Shared plumbing

    private static func post<T: Decodable>(url: URL, body: [String: Any]) async throws -> T {
        guard isConfigured else { throw Failure.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        if T.self == EmptyReply.self, let empty = EmptyReply() as? T { return empty }
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else { throw Failure.decoding }
        return decoded
    }

    /// Google answers a refused call with `{"error": {"message": "EMAIL_EXISTS"}}`,
    /// which is worth far more to a learner than the status code on its own.
    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw Failure.decoding }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let message = AIClient.readableMessage(from: body)
            if http.statusCode == 400 || http.statusCode == 401 || http.statusCode == 403 {
                throw Failure.auth(message)
            }
            throw Failure.http(http.statusCode, body)
        }
    }

    // MARK: - Firestore timestamps

    private static let rfc3339: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func format(_ date: Date) -> String { rfc3339.string(from: date) }

    static func parse(_ text: String) -> Date? {
        rfc3339.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
