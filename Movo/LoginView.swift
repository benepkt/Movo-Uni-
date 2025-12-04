import SwiftUI
import AuthenticationServices
import UIKit

// MARK: - LOGIN

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isLoading = false
    @State private var currentNonce: String?
    @State private var showRegister = false

    private var isAnon: Bool { authService.user?.isAnonymous ?? authService.isGuest }
    private var canAuth: Bool { !email.isEmpty && !password.isEmpty && !isLoading }

    // MARK: - Adaptive Farben

    private var pageBackground: LinearGradient {
        scheme == .dark
        ? LinearGradient(colors: [Color(.systemGray6), Color(.black)],
                         startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color.white, Color(.systemGray6)],
                         startPoint: .top, endPoint: .bottom)
    }

    private var fieldBackground: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var fieldShadowOpacity: Double {
        scheme == .dark ? 0.0 : 0.05
    }

    private var accent: Color { .blue }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Logo / Hero
                        Image("fitness_robot_blue")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .padding(.top, 12)

                        Text("Movo Login")
                            .font(.largeTitle.weight(.semibold))

                        // Eingabefelder
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(accent)
                                TextField("E-Mail", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.next)
                            }
                            .padding()
                            .background(fieldBackground)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(fieldShadowOpacity),
                                    radius: 3)

                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(accent)
                                SecureField("Passwort", text: $password)
                                    .submitLabel(.go)
                            }
                            .padding()
                            .background(fieldBackground)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(fieldShadowOpacity),
                                    radius: 3)
                        }

                        // Hinweise / Fehler
                        if let infoMessage {
                            Text(infoMessage)
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // E-Mail Login Button
                        Button(action: login) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Einloggen")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(canAuth ? accent : accent.opacity(0.35))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(!canAuth)

                        // Registrieren Sheet
                        Button {
                            showRegister = true
                        } label: {
                            Text("Noch kein Konto? Registrieren")
                                .font(.footnote)
                                .foregroundColor(accent)
                        }
                        .disabled(isLoading)

                        // Passwort zurücksetzen
                        Button(action: resetPassword) {
                            Text("Passwort vergessen?")
                                .font(.footnote)
                                .underline()
                        }
                        .disabled(isLoading || email.isEmpty)

                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                            Text("ODER")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        .padding(.top, 4)

                        // Apple Login
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: configureAppleRequest,
                            onCompletion: handleAppleResult
                        )
                        .signInWithAppleButtonStyle(
                            scheme == .dark ? .white : .black
                        )
                        .frame(height: 48)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .disabled(isLoading)

                        // Google Login – weißer Button mit Outline
                        Button(action: loginWithGoogle) {
                            HStack(spacing: 12) {
                                if UIImage(named: "google_g") != nil {
                                    Image("google_g")
                                        .resizable()
                                        .frame(width: 18, height: 18)
                                        .cornerRadius(3)
                                } else {
                                    Image(systemName: "g.circle")
                                        .font(.title3)
                                }
                                Text(isAnon
                                     ? "Konto verknüpfen mit Google"
                                     : "Mit Google anmelden")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .frame(height: 45)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(GoogleOutlineButtonStyle(isLoading: isLoading))
                        .padding(.horizontal)
                        .disabled(isLoading)

                        Spacer(minLength: 8)
                    }
                    .iPadConstrained()
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(.keyboard)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(authService)
        }
    }

    // MARK: - Actions

    private func login() {
        guard canAuth else { return }
        setState(loading: true, error: nil, info: nil)

        authService.signIn(email: email, password: password) { result in
            DispatchQueue.main.async {
                self.setState(loading: false)
                switch result {
                case .success:
                    self.dismiss()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resetPassword() {
        guard !email.isEmpty else {
            self.errorMessage = "Bitte gib zuerst deine E-Mail ein."
            return
        }

        setState(loading: true, error: nil, info: nil)

        authService.sendPasswordReset(to: email) { result in
            DispatchQueue.main.async {
                self.setState(loading: false)
                switch result {
                case .success:
                    self.infoMessage = "E-Mail zum Zurücksetzen wurde gesendet."
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loginWithGoogle() {
        guard !isLoading else { return }
        guard let presenter = topViewController() else {
            self.errorMessage = "Konnte Präsentationscontroller nicht finden."
            return
        }

        setState(loading: true, error: nil, info: nil)

        authService.signInWithGoogle(presenting: presenter) { result in
            DispatchQueue.main.async {
                self.setState(loading: false)
                switch result {
                case .success:
                    self.dismiss()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Apple Login

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce
            else {
                errorMessage = "Apple Login fehlgeschlagen. Bitte erneut versuchen."
                return
            }

            setState(loading: true, error: nil, info: nil)

            authService.signInWithApple(credential: credential, nonce: nonce) { result in
                DispatchQueue.main.async {
                    self.setState(loading: false)
                    switch result {
                    case .success:
                        self.dismiss()
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func setState(loading: Bool? = nil,
                          error: String? = nil,
                          info: String? = nil) {
        if let loading { self.isLoading = loading }
        if let error { self.errorMessage = error }
        if let info { self.infoMessage = info }
    }
}

// MARK: - Presenter Helper (für Google Sign-In)

fileprivate func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }

    let keyWindow = scenes
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }

    func traverse(_ vc: UIViewController?) -> UIViewController? {
        if let nav = vc as? UINavigationController {
            return traverse(nav.visibleViewController)
        }
        if let tab = vc as? UITabBarController {
            return traverse(tab.selectedViewController)
        }
        if let presented = vc?.presentedViewController {
            return traverse(presented)
        }
        return vc
    }

    return traverse(keyWindow?.rootViewController)
}

// MARK: - Google Outline ButtonStyle

private struct GoogleOutlineButtonStyle: ButtonStyle {
    var isLoading: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        Color.gray.opacity(configuration.isPressed ? 0.5 : 0.35),
                        lineWidth: 1
                    )
            )
            .cornerRadius(10)
            .shadow(
                color: Color.black.opacity(
                    configuration.isPressed ? 0.05 : 0.08
                ),
                radius: 4,
                x: 0,
                y: 1
            )
            .opacity(isLoading ? 0.7 : 1.0)
            .foregroundColor(.black)
    }
}

// MARK: - REGISTER

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var email = ""
    @State private var password = ""
    @State private var repeatPassword = ""
    @State private var acceptedTerms = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private var isAnon: Bool {
        authService.user?.isAnonymous ?? authService.isGuest
    }

    private var pageBackground: LinearGradient {
        scheme == .dark
        ? LinearGradient(colors: [Color(.systemGray6), Color(.black)],
                         startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color.white, Color(.systemGray6)],
                         startPoint: .top, endPoint: .bottom)
    }

    private var fieldBackground: Color {
        scheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var fieldShadowOpacity: Double {
        scheme == .dark ? 0.0 : 0.05
    }

    private var accent: Color { .blue }

    private var canSubmit: Bool {
        !email.isEmpty &&
        password.count >= 6 &&
        password == repeatPassword &&
        acceptedTerms &&
        !isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {

                        Text(isAnon ? "Konto verknüpfen" : "Registrieren")
                            .font(.system(size: 32, weight: .heavy))
                            .padding(.top, 8)

                        VStack(spacing: 16) {
                            inputRow(icon: "envelope") {
                                TextField("E-Mail", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(.primary)
                            }

                            inputRow(icon: "lock") {
                                SecureField("Passwort (min. 6 Zeichen)", text: $password)
                                    .foregroundStyle(.primary)
                            }

                            inputRow(icon: "lock.rotation") {
                                SecureField("Passwort wiederholen", text: $repeatPassword)
                                    .foregroundStyle(.primary)
                            }
                        }

                        // Terms
                        HStack(spacing: 12) {
                            Toggle(isOn: $acceptedTerms) { EmptyView() }
                                .labelsHidden()
                            Text("Ich akzeptiere die Nutzungsbedingungen")
                                .foregroundStyle(.primary)
                                .font(.body)
                            Spacer()
                        }
                        .padding()
                        .background(fieldBackground)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(fieldShadowOpacity),
                                radius: 4, x: 0, y: 1)

                        // Hinweise
                        if let infoMessage {
                            Text(infoMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                        }

                        // CTA
                        Button(action: submit) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text(isAnon
                                     ? "Konto verknüpfen"
                                     : "Konto erstellen")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(canSubmit ? accent : accent.opacity(0.35))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(!canSubmit)

                        Spacer(minLength: 0)
                    }
                    .iPadConstrained()
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(.keyboard)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - UI Helper

    @ViewBuilder
    private func inputRow<Content: View>(icon: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(accent)
            content()
                .tint(accent)
        }
        .padding()
        .background(fieldBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(fieldShadowOpacity),
                radius: 4, x: 0, y: 1)
    }

    // MARK: - Actions

    private func submit() {
        guard canSubmit else { return }
        errorMessage = nil
        infoMessage = nil
        isLoading = true

        if isAnon {
            authService.linkCurrentUser(email: email, password: password) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success:
                        infoMessage = "Konto verknüpft. Viel Spaß!"
                        dismiss()
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            authService.signUp(email: email, password: password) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success:
                        infoMessage = "Konto erstellt. Willkommen!"
                        dismiss()
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
