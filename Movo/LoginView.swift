import SwiftUI
import AuthenticationServices
import UIKit

// MARK: - LOGIN

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isLoading = false
    @State private var currentNonce: String?
    @State private var showRegister = false
    @State private var showEmailLogin = false // New state for toggling views

    private var isAnon: Bool { authService.user?.isAnonymous ?? authService.isGuest }
    private var canAuth: Bool { !email.isEmpty && !password.isEmpty && !isLoading }

    // MARK: - View Config
    private var backgroundColor: Color {
        Color(hex: 0x050505) // Deep black/dark
    }

    private var accent: Color { .blue }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                if showEmailLogin {
                    emailFlowView
                        .transition(.move(edge: .trailing))
                } else {
                    landingView
                        .transition(.move(edge: .leading))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showEmailLogin)
            .toolbar {
                if showEmailLogin {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showEmailLogin = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(appSettings.localized("login.back"))
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(authService)
        }
    }
    
    // MARK: - Landing View (Canopi Style)
    var landingView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo & Title
            VStack(spacing: 24) {
                Image("fitness_robot_blue")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .shadow(color: .blue.opacity(0.3), radius: 20)
                
                VStack(spacing: 8) {
                    Text(appSettings.localized("login.welcome"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Text("Movo")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                
                Text(appSettings.localized("login.tagline"))
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
            
            Spacer()
            
            // Feature Grid (Visual Flair)
            HStack(spacing: 20) {
                featureItem(icon: "dumbbell.fill", label: appSettings.localized("login.feature.training"))
                featureItem(icon: "figure.run", label: appSettings.localized("login.feature.steps"))
                featureItem(icon: "chart.bar.fill", label: appSettings.localized("login.feature.analysis"))
            }
            .padding(.bottom, 40)
            
            Spacer()
            
            // Bottom Actions
            VStack(spacing: 16) {
                // Apple
                SignInWithAppleButton(
                    .signIn,
                    onRequest: configureAppleRequest,
                    onCompletion: handleAppleResult
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .cornerRadius(27)
                .frame(maxWidth: .infinity)
                
                // Google
                Button(action: loginWithGoogle) {
                    HStack(spacing: 12) {
                        if UIImage(named: "google_g") != nil {
                            Image("google_g")
                                .resizable()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                        }
                        Text(appSettings.localized("login.google.continue"))
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: 0x1C1C1E))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                // Email
                Button {
                    showEmailLogin = true
                } label: {
                    Text(appSettings.localized("login.email.signin"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Email Flow View
    var emailFlowView: some View {
        ScrollView {
            VStack(spacing: 28) {
                
                Text(isAnon ? appSettings.localized("login.link.account") : appSettings.localized("login.signin"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Eingabefelder
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.gray)
                        TextField("", text: $email, prompt: Text(appSettings.localized("login.email.placeholder")).foregroundColor(.gray))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .submitLabel(.next)
                    }
                    .padding()
                    .background(Color(hex: 0x1C1C1E))
                    .cornerRadius(16)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                        SecureField("", text: $password, prompt: Text(appSettings.localized("login.password.placeholder")).foregroundColor(.gray))
                            .foregroundStyle(.white)
                            .submitLabel(.go)
                    }
                    .padding()
                    .background(Color(hex: 0x1C1C1E))
                    .cornerRadius(16)
                }
                
                // Fehlermeldungen
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                
                // Login Button
                Button(action: login) {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white) // Use white tint for contrast on blue
                        } else {
                            Text(appSettings.localized("login.button.login"))
                                .font(.body.weight(.bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(canAuth ? Color.blue : Color.blue.opacity(0.5))
                    .cornerRadius(27)
                    .contentShape(Rectangle())
                }
                .foregroundColor(.white)
                .disabled(!canAuth)
                
                // Links
                HStack {
                    Button(appSettings.localized("login.create.account")) { showRegister = true }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    Button(appSettings.localized("login.forgot.password")) { resetPassword() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func featureItem(icon: String, label: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x1C1C1E))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Actions (Keep existing logic)
    
    // ... [Rest of logic follows below] ...


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
            self.errorMessage = appSettings.localized("login.error.email.required")
            return
        }

        setState(loading: true, error: nil, info: nil)

        authService.sendPasswordReset(to: email) { result in
            DispatchQueue.main.async {
                self.setState(loading: false)
                switch result {
                case .success:
                    self.infoMessage = appSettings.localized("login.password.reset.sent")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loginWithGoogle() {
        guard !isLoading else { return }
        guard let presenter = topViewController() else {
            self.errorMessage = appSettings.localized("login.error.presenter")
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
                errorMessage = appSettings.localized("login.error.apple.failed")
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
    @EnvironmentObject var appSettings: AppSettings
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

    private var backgroundColor: Color {
        Color(hex: 0x050505)
    }

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
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        Text(isAnon ? appSettings.localized("register.link.account") : appSettings.localized("register.create.account"))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 20)

                        VStack(spacing: 16) {
                            inputRow(icon: "envelope.fill") {
                                TextField("", text: $email, prompt: Text(appSettings.localized("login.email.placeholder")).foregroundColor(.gray))
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(.white)
                            }

                            inputRow(icon: "lock.fill") {
                                SecureField("", text: $password, prompt: Text(appSettings.localized("register.password.min")).foregroundColor(.gray))
                                    .foregroundStyle(.white)
                            }

                            inputRow(icon: "lock.rotation") {
                                SecureField("", text: $repeatPassword, prompt: Text(appSettings.localized("register.password.repeat")).foregroundColor(.gray))
                                    .foregroundStyle(.white)
                            }
                        }

                        // Terms
                        HStack(spacing: 12) {
                            Toggle(isOn: $acceptedTerms) { EmptyView() }
                                .labelsHidden()
                                .tint(.blue)
                            Text(appSettings.localized("register.accept.terms"))
                                .foregroundStyle(.white)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(hex: 0x1C1C1E))
                        .cornerRadius(16)

                        // Hinweise
                        if let infoMessage {
                            Text(infoMessage)
                                .font(.callout)
                                .foregroundColor(.gray)
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
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isAnon ? appSettings.localized("register.link.account") : appSettings.localized("register.create.account"))
                                        .font(.body.weight(.bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canSubmit ? Color.blue : Color.blue.opacity(0.5))
                            .cornerRadius(27)
                            .contentShape(Rectangle())
                        }
                        .foregroundColor(.white)
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
                    Button(appSettings.localized("register.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(.white)
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
                .foregroundColor(.gray)
                .font(.title3)
                .frame(width: 24)
            content()
                .tint(.blue)
        }
        .padding()
        .background(Color(hex: 0x1C1C1E))
        .cornerRadius(16)
    }
    
    //Test//

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
                        infoMessage = appSettings.localized("register.success.linked")
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
                        infoMessage = appSettings.localized("register.success.created")
                        dismiss()
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
