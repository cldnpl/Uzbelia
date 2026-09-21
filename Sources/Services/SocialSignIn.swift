import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Signing in with Apple and with Google, without either company's SDK.
///
/// Both come down to the same thing: get an OpenID `id_token` from the provider, hand
/// it to Firebase's `accounts:signInWithIdp`, and get back the very same session an
/// email and password would have produced. Apple's half is one system framework;
/// Google's is a browser window and the standard OAuth dance with PKCE — so the app
/// still resolves no packages and still weighs what it weighed.
enum SocialSignIn {

    /// Il client id iOS, ripulito. Vuoto vuol dire che il pulsante Google non ha
    /// niente con cui presentarsi, e la schermata lo tiene nascosto invece di
    /// offrire un pulsante che fallisce appena lo tocchi.
    static var googleClientID: String {
        Secrets.googleOAuthClientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isGoogleConfigured: Bool { !googleClientID.isEmpty }

    /// Accedi con Apple è un framework di sistema: non ha chiavi da configurare,
    /// e sotto iOS 13 non esisterebbe proprio. Quel che gli serve — l'entitlement
    /// `com.apple.developer.applesignin` e l'interruttore Apple nella console
    /// Firebase — non è una cosa che l'app possa leggere da dentro.
    static var isAppleConfigured: Bool { true }

    enum Failure: LocalizedError {
        case cancelled
        case notConfigured
        case noToken
        case appleAccountMissing
        case provider(String)

        var errorDescription: String? { message.it }

        var message: Bilingual {
            switch self {
            case .cancelled:
                return Bilingual(it: "Accesso annullato.", uz: "Kirish bekor qilindi.")
            case .notConfigured:
                return Bilingual(it: "Accesso con Google non configurato in questa build.",
                                 uz: "Bu versiyada Google orqali kirish sozlanmagan.")
            case .appleAccountMissing:
                return Bilingual(it: "Nessun ID Apple su questo dispositivo. Aprilo in Impostazioni, accedi, e riprova.",
                                 uz: "Bu qurilmada Apple ID yo'q. Sozlamalarni oching, kiring va qayta urinib ko'ring.")
            case .noToken:
                return Bilingual(it: "Il provider non ha restituito un'identità valida.",
                                 uz: "Provayder yaroqli identifikator qaytarmadi.")
            case .provider(let detail):
                return Bilingual(it: "Accesso non riuscito. \(detail)",
                                 uz: "Kirish amalga oshmadi. \(detail)")
            }
        }
    }

    // MARK: - Apple

    /// The token Apple hands back, with the nonce Firebase needs in order to believe it.
    struct AppleIdentity {
        var idToken: String
        var rawNonce: String
        /// Apple sends the name once, on the very first sign-in, and never again.
        var fullName: String?
        /// Same story, and worth keeping for the rare account that hides its address.
        var email: String?
    }

    @MainActor
    static func apple() async throws -> AppleIdentity {
        let rawNonce = randomString(length: 32)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        // Apple signs the hash; Firebase is told the original and checks it matches,
        // which is what stops a token from one app being replayed into another.
        request.nonce = sha256(rawNonce)

        let delegate = AppleDelegate(rawNonce: rawNonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            delegate.retain = delegate          // alive until Apple answers
            controller.performRequests()
        }
    }

    private final class AppleDelegate: NSObject, ASAuthorizationControllerDelegate,
                                       ASAuthorizationControllerPresentationContextProviding {
        let rawNonce: String
        var continuation: CheckedContinuation<AppleIdentity, Error>?
        var retain: AppleDelegate?

        init(rawNonce: String) { self.rawNonce = rawNonce }

        private func finish(_ result: Result<AppleIdentity, Error>) {
            continuation?.resume(with: result)
            continuation = nil
            retain = nil
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithAuthorization authorization: ASAuthorization) {
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8) else {
                return finish(.failure(Failure.noToken))
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            finish(.success(AppleIdentity(idToken: token, rawNonce: rawNonce,
                                          fullName: name.isEmpty ? nil : name,
                                          email: credential.email)))
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithError error: Error) {
            switch (error as? ASAuthorizationError)?.code {
            case .canceled:
                // Ha chiuso il foglio: non è un guasto, e non va detto niente.
                finish(.failure(Failure.cancelled))
            case .unknown, .failed:
                // Il codice 1000 arriva quasi sempre da una cosa sola: nessun Apple ID
                // sul dispositivo (tipico del simulatore appena creato). Dirlo per nome
                // risparmia mezz'ora a chiunque lo veda.
                finish(.failure(Failure.appleAccountMissing))
            default:
                finish(.failure(Failure.provider(error.localizedDescription)))
            }
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            SocialSignIn.anchor()
        }
    }

    // MARK: - Google

    /// Google's iOS clients are public clients: no secret to hide in the app, and PKCE
    /// instead — a one-time verifier kept in memory, so an intercepted redirect is
    /// worth nothing to whoever intercepted it.
    @MainActor
    static func google() async throws -> String {
        let clientID = googleClientID
        guard !clientID.isEmpty else { throw Failure.notConfigured }

        // Google's iOS clients redirect to the client id read backwards, which is also
        // the URL scheme ASWebAuthenticationSession listens on — and because it listens
        // itself, nothing has to be registered in Info.plist.
        let scheme = clientID.split(separator: ".").reversed().joined(separator: ".")
        let redirect = "\(scheme):/oauth2redirect"
        let verifier = randomString(length: 64)
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        // PKCE difende il codice; `state` difende la richiesta, che è l'altra metà.
        let state = randomString(length: 24)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            // Senza questo, chi ha già un account Google su questo telefono viene
            // fatto entrare con quello, senza che nessuno glielo chieda.
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let url = components.url else { throw Failure.notConfigured }

        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let presenter = WebPresenter()
            var resumed = false
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { url, error in
                // Il sistema ha già chiamato questa chiusura una volta sola in ogni
                // caso noto, ma una continuation ripresa due volte è un crash, non un
                // bug da leggere nei log.
                guard !resumed else { return }
                resumed = true
                presenter.retain = nil
                if let url { return continuation.resume(returning: url) }
                if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    return continuation.resume(throwing: Failure.cancelled)
                }
                continuation.resume(throwing: Failure.provider(error?.localizedDescription ?? ""))
            }
            session.presentationContextProvider = presenter
            // I cookie di Safari restano condivisi apposta: è quello che fa apparire
            // subito l'account già usato su questo telefono, invece di far ridigitare
            // una password lunga su una tastiera piccola. `prompt=select_account`
            // qui sopra è ciò che impedisce a quella comodità di scegliere da sola.
            session.prefersEphemeralWebBrowserSession = false
            presenter.retain = presenter
            session.start()
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        // Google risponde sullo stesso redirect sia quando dice di sì sia quando dice
        // di no; senza questo ramo un rifiuto diventava un silenzioso "annullato".
        if let denied = value("error") {
            if denied == "access_denied" { throw Failure.cancelled }
            throw Failure.provider(denied)
        }
        guard value("state") == state else { throw Failure.provider("state") }
        guard let code = value("code") else { throw Failure.cancelled }

        return try await exchange(code: code, verifier: verifier,
                                  clientID: clientID, redirect: redirect)
    }

    private struct TokenReply: Decodable { let id_token: String? }

    /// Trades the one-time code for the identity token Firebase will accept.
    private static func exchange(code: String, verifier: String,
                                 clientID: String, redirect: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirect,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ].map { "\($0.key)=\(escape($0.value))" }.joined(separator: "&")
        request.httpBody = Data(form.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure.provider(AIClient.readableMessage(from: String(data: data, encoding: .utf8) ?? ""))
        }
        guard let token = (try? JSONDecoder().decode(TokenReply.self, from: data))?.id_token else {
            throw Failure.noToken
        }
        return token
    }

    private final class WebPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
        var retain: WebPresenter?
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            SocialSignIn.anchor()
        }
    }

    // MARK: - Odds and ends

    @MainActor
    static func anchor() -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first { $0.activationState == .foregroundActive }?.keyWindow
            ?? scenes.first?.keyWindow
        return window ?? ASPresentationAnchor()
    }

    private static func randomString(length: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var out = ""
        for _ in 0..<length {
            var byte: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            out.append(alphabet[Int(byte) % alphabet.count])
        }
        return out
    }

    private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
