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
                    VStack(spacing: 28) {

                        // Logo / Hero
                        Image("fitness_robot_blue")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .padding(.top, 20)

                        Text("Movo Login")
                            .font(.system(size: 34, weight: .bold))
                            .padding(.bottom, 8)

                        // Eingabefelder
                        VStack(spacing: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(accent)
                                    .font(.title3)
                                    .frame(width: 24)
                                TextField("E-Mail", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.next)
                            }
                            .padding()
                            .padding(.vertical, 6)
                            .background(fieldBackground)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(fieldShadowOpacity), radius: 4, y: 2)

                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(accent)
                                    .font(.title3)
                                    .frame(width: 24)
                                SecureField("Passwort", text: $password)
                                    .submitLabel(.go)
                            }
                            .padding()
                            .padding(.vertical, 6)
                            .background(fieldBackground)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(fieldShadowOpacity), radius: 4, y: 2)
                        }

                        // Hinweise / Fehler
                        if let infoMessage {
                            Text(infoMessage)
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.callout)
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
                                    .padding(.vertical, 16)
                            } else {
                                Text("Einloggen")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .background(canAuth ? accent : accent.opacity(0.35))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .disabled(!canAuth)

                        // Registrieren + Passwort zurücksetzen
                        HStack(spacing: 24) {
                            Button {
                                showRegister = true
                            } label: {
                                Text("Noch kein Konto? Registrieren")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(accent)
                            }
                            .disabled(isLoading)
                            
                            Spacer()
                            
                            Button(action: resetPassword) {
                                Text("Passwort vergessen?")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .disabled(isLoading || email.isEmpty)
                        }
                        .padding(.horizontal, 4)

                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(.gray.opacity(0.4))
                            Text("ODER")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .padding(.vertical, 8)

                        // Apple Login
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: configureAppleRequest,
                            onCompletion: handleAppleResult
                        )
                        .signInWithAppleButtonStyle(
                            scheme == .dark ? .white : .black
                        )
                        .frame(height: 54)
                        .cornerRadius(14)
                        .disabled(isLoading)

                        // Google Login
                        Button(action: loginWithGoogle) {
                            HStack(spacing: 12) {
                                if UIImage(named: "google_g") != nil {
                                    Image("google_g")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .cornerRadius(3)
                                } else {
                                    Image(systemName: "g.circle")
                                        .font(.title3)
                                }
                                Text(isAnon ? "Konto verknüpfen mit Google" : "Mit Google anmelden")
                                    .font(.body.weight(.semibold))
                                Spacer()
                            }
                            .padding()
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(GoogleOutlineButtonStyle(isLoading: isLoading))
                        .disabled(isLoading)

                        Spacer(minLength: 20)
                    }
                    .iPadConstrained()
                    .padding(.horizontal, 24)
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
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        Color.gray.opacity(configuration.isPressed ? 0.5 : 0.3),
                        lineWidth: 1.5
                    )
            )
            .cornerRadius(14)
            .shadow(
                color: Color.black.opacity(
                    configuration.isPressed ? 0.03 : 0.06
                ),
                radius: 3,
                y: 2
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
                    VStack(alignment: .leading, spacing: 24) {

                        Text(isAnon ? "Konto verknüpfen" : "Registrieren")
                            .font(.system(size: 34, weight: .bold))
                            .padding(.top, 20)

                        VStack(spacing: 14) {
                            inputRow(icon: "envelope.fill") {
                                TextField("E-Mail", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(.primary)
                            }

                            inputRow(icon: "lock.fill") {
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
                        .padding(.vertical, 4)
                        .background(fieldBackground)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(fieldShadowOpacity), radius: 4, y: 2)

                        // Hinweise
                        if let infoMessage {
                            Text(infoMessage)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                        }

                        // CTA
                        Button(action: submit) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text(isAnon ? "Konto verknüpfen" : "Konto erstellen")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .background(canSubmit ? accent : accent.opacity(0.35))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .disabled(!canSubmit)

                        Spacer(minLength: 20)
                    }
                    .iPadConstrained()
                    .padding(.horizontal, 24)
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accent)
                .font(.title3)
                .frame(width: 24)
            content()
                .tint(accent)
        }
        .padding()
        .padding(.vertical, 6)
        .background(fieldBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(fieldShadowOpacity), radius: 4, y: 2)
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
