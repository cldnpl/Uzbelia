import SwiftUI

/// Signing in and signing up: the three routes in, side by side.
///
/// It is one view because it is shown in two places that must not drift apart — the
/// last step of the onboarding, where a learner is about to start putting weeks into
/// this, and Profilo, for whoever said "later" back then.
struct AccountForm: View {
    @Environment(AppState.self) private var state

    enum Mode { case signIn, signUp }
    @State var mode: Mode = .signIn
    /// The onboarding has its own heading above this and wants no mascot of its own.
    var showsMascot = true

    @State private var email = ""
    @State private var password = ""
    @State private var resetNote: Bilingual?
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var account: CloudAccount { state.account }
    private var lang: Language { state.native }

    private var canSubmit: Bool {
        email.contains("@") && email.count > 4 && password.count >= 6 && !account.busy
    }

    var body: some View {
        VStack(spacing: 18) {
            if showsMascot { header }

            socialButtons

            HStack(spacing: 10) {
                Rectangle().fill(Palette.stroke).frame(height: 1.5)
                Text(S.orWithEmail[lang]).font(.heading(10)).kerning(0.6)
                    .foregroundStyle(Palette.inkFaint)
                    .lineLimit(1).fixedSize()
                Rectangle().fill(Palette.stroke).frame(height: 1.5)
            }
            .padding(.top, 2)

            VStack(spacing: 12) {
                field(S.emailField[lang], icon: "envelope.fill") {
                    TextField("", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                }
                field(S.passwordField[lang], icon: "lock.fill",
                      footnote: mode == .signUp ? S.passwordHint[lang] : nil) {
                    SecureField("", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { if canSubmit { submit() } }
                }
            }

            if let message = errorMessage {
                note(message, tint: Palette.red, icon: "exclamationmark.triangle.fill")
            }
            if let resetNote {
                note(resetNote, tint: Palette.green, icon: "envelope.badge.fill")
            }

            Button(action: submit) {
                if account.busy {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text(S.syncing[lang])
                    }
                } else {
                    Text(mode == .signIn ? S.signIn[lang] : S.signUp[lang])
                }
            }
            .buttonStyle(.chunky(Palette.green, Palette.greenDeep))
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)

            Button {
                Feedback.tap()
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = mode == .signIn ? .signUp : .signIn
                    resetNote = nil
                }
            } label: {
                Text(mode == .signIn ? S.noAccountYet[lang] : S.backToSignIn[lang])
                    .font(.heading(13)).foregroundStyle(Palette.brand)
            }
            .buttonStyle(.plain)

            if mode == .signIn {
                Button {
                    Feedback.tap()
                    Task { resetNote = await account.sendPasswordReset(to: email) ?? S.resetSent }
                } label: {
                    Text(S.forgotPassword[lang])
                        .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                }
                .buttonStyle(.plain)
                .disabled(!email.contains("@"))
                .opacity(email.contains("@") ? 1 : 0.4)
            }

            note(S.accountMerged, tint: Palette.brand, icon: "arrow.triangle.merge")
                .padding(.top, 4)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 10) {
            Mascot(mood: .happy, size: 78)
            Text(S.accountSub[lang])
                .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// Apple first, because Apple requires it of any app that offers another
    /// provider — and because it is the one that asks for nothing at all.
    @ViewBuilder
    private var socialButtons: some View {
        VStack(spacing: 10) {
            Button {
                Feedback.tap(); focus = nil; resetNote = nil
                Task { await account.signInWithApple() }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "apple.logo").font(.system(size: 17, weight: .medium))
                    Text(S.continueApple[lang])
                }
            }
            .buttonStyle(.chunky(Palette.ink, Palette.ink.opacity(0.75), height: 50))
            .disabled(account.busy)

            // Senza client id il pulsante non può fare altro che aprirsi e scusarsi:
            // meglio non esserci. Con il client id c'è, e funziona.
            if SocialSignIn.isGoogleConfigured {
                Button {
                    Feedback.tap(); focus = nil; resetNote = nil
                    Task { await account.signInWithGoogle() }
                } label: {
                    HStack(spacing: 9) {
                        GoogleGlyph().frame(width: 17, height: 17)
                        Text(S.continueGoogle[lang])
                    }
                }
                .buttonStyle(.chunky(Palette.card, Palette.strokeDeep, text: Palette.ink, height: 50))
                .disabled(account.busy)
            }
        }
        .opacity(account.busy ? 0.6 : 1)
    }

    private var errorMessage: Bilingual? {
        // In a build with no keys yet, every button fails for the same reason and the
        // page already says so once, underneath. Saying it twice helps nobody.
        guard account.isAvailable else { return nil }
        if case .failed(let message) = account.status { return message }
        return nil
    }

    private func field<Content: View>(_ label: String, icon: String,
                                      footnote: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black)).foregroundStyle(Palette.inkFaint)
                    .frame(width: 20)
                content()
                    .font(.plain(15))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 13).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                .fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 2))
            .overlay(alignment: .topLeading) {
                Text(label)
                    .font(.heading(10)).kerning(0.6)
                    .foregroundStyle(Palette.inkFaint)
                    .padding(.horizontal, 5)
                    .background(Palette.bg)
                    .offset(x: 12, y: -6)
            }
            if let footnote {
                Text(footnote).font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
                    .padding(.leading, 4)
            }
        }
        .padding(.top, 6)
    }

    private func note(_ text: Bilingual, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon).font(.system(size: 13, weight: .black)).foregroundStyle(tint)
            Text(text[lang]).font(.plain(12.5)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
            .fill(tint.opacity(0.13)))
    }

    private func submit() {
        Feedback.tap()
        focus = nil
        resetNote = nil
        let mail = email, pass = password
        Task {
            if mode == .signIn { await account.signIn(email: mail, password: pass) }
            else { await account.signUp(email: mail, password: pass) }
        }
    }
}

/// The same form as a sheet, for Profilo and for anyone arriving from the very first
/// screen with an account already in hand.
struct AccountSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    var mode: AccountForm.Mode = .signIn

    var body: some View {
        NavigationStack {
            ScrollView {
                AccountForm(mode: mode)
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.bottom, 24)
            }
            .background(Palette.bg)
            .navigationTitle(S.account[state.native])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(S.close[state.native]) { dismiss() }
                }
            }
            .onChange(of: state.account.isSignedIn) { _, signedIn in
                if signedIn { Feedback.pop(); dismiss() }
            }
        }
    }
}

/// Google's four-colour G, drawn: an image file would have to be licensed, bundled
/// and kept in two resolutions to say the same thing.
private struct GoogleGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let width = side * 0.19
            ZStack {
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(Color(light: 0x4285F4, dark: 0x6BA1F7), lineWidth: width)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0.25, to: 0.5)
                    .stroke(Color(light: 0x34A853, dark: 0x4CC168), lineWidth: width)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0.5, to: 0.75)
                    .stroke(Color(light: 0xFBBC05, dark: 0xFFC928), lineWidth: width)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0.75, to: 1.0)
                    .stroke(Color(light: 0xEA4335, dark: 0xF2594B), lineWidth: width)
                    .rotationEffect(.degrees(-90))
                Rectangle()
                    .fill(Color(light: 0x4285F4, dark: 0x6BA1F7))
                    .frame(width: side * 0.42, height: width)
                    .offset(x: side * 0.16, y: side * 0.02)
            }
            .padding(width / 2)
        }
    }
}

// MARK: - The row Profilo shows

/// What the account looks like from the settings screen: who is signed in, when the
/// server last heard from this phone, and the two buttons that change either.
struct AccountSection: View {
    @Environment(AppState.self) private var state
    @State private var showSheet = false
    @State private var showDelete = false
    @State private var deleteError: Bilingual?

    private var account: CloudAccount { state.account }
    private var lang: Language { state.native }

    var body: some View {
        if account.isAvailable {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: S.account[lang].uppercased())
                if account.isSignedIn { signedIn } else { signedOut }
            }
            .sheet(isPresented: $showSheet) { AccountSheet(mode: .signIn) }
            .alert(S.deleteAccount[lang], isPresented: $showDelete) {
                Button(S.cancel[lang], role: .cancel) {}
                Button(S.confirm[lang], role: .destructive) {
                    Task { deleteError = await account.deleteAccount() }
                }
            } message: { Text(S.deleteAccountMsg[lang]) }
        }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 16, weight: .black)).foregroundStyle(Palette.inkFaint)
                Text(S.notSignedIn[lang])
                    .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            Button {
                Feedback.tap(); showSheet = true
            } label: {
                Text(S.signIn[lang])
            }
            .buttonStyle(.chunky(Palette.brand, Palette.brandDeep, height: 46))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            .stroke(Palette.stroke, lineWidth: 2))
    }

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 17, weight: .black)).foregroundStyle(Palette.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.email).font(.heading(14)).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(syncLine).font(.plain(11.5)).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
                if account.busy { ProgressView().tint(Palette.brand) }
            }

            if case .failed(let message) = account.status {
                Text(message[lang]).font(.plain(11.5)).foregroundStyle(Palette.redDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let deleteError {
                Text(deleteError[lang]).font(.plain(11.5)).foregroundStyle(Palette.redDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    Feedback.tap(); Task { await account.syncNow() }
                } label: {
                    Text(S.syncNow[lang]).font(.heading(12.5)).foregroundStyle(Palette.brand)
                }
                .buttonStyle(.plain)
                .disabled(account.busy)
                Spacer(minLength: 0)
                Button {
                    Feedback.tap(); account.signOut()
                } label: {
                    Text(S.signOut[lang]).font(.heading(12.5)).foregroundStyle(Palette.inkSoft)
                }
                .buttonStyle(.plain)
                Button {
                    Feedback.tap(); showDelete = true
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(Palette.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            .stroke(Palette.stroke, lineWidth: 2))
    }

    private var syncLine: String {
        switch account.status {
        case .working: return S.syncing[lang]
        case .synced(let date):
            guard date > .distantPast else { return S.syncedNever[lang] }
            if Date().timeIntervalSince(date) < 60 { return S.syncedJustNow[lang] }
            let f = DateFormatter()
            f.timeStyle = .short
            f.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
            return "\(S.syncedAt[lang]) \(f.string(from: date))"
        case .failed: return S.syncedNever[lang]
        case .signedOut: return S.notSignedIn[lang]
        }
    }
}
