import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import AuthenticationServices
import CryptoKit
import UIKit
import Combine
import GoogleSignIn

@MainActor
final class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isGuest: Bool = false
    @Published var hasSubscription: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private var launchObserver: NSObjectProtocol?
    private var userDocListener: ListenerRegistration?

    // MARK: - Init / Deinit

    init() {
        if FirebaseApp.app() != nil {
            bootstrapAuth()
        } else {
            launchObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didFinishLaunchingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.bootstrapAuth() }
            }
        }
    }

    deinit {
        if let h = authListener { Auth.auth().removeStateDidChangeListener(h) }
        if let obs = launchObserver { NotificationCenter.default.removeObserver(obs) }
        userDocListener?.remove()
    }

    // MARK: - Bootstrap

    private func bootstrapAuth() {
        if let h = authListener {
            Auth.auth().removeStateDidChangeListener(h)
        }

        self.user = Auth.auth().currentUser
        self.isGuest = self.user?.isAnonymous ?? false
        attachUserDocListenerIfNeeded(for: self.user)

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.user = user
                self.isGuest = user?.isAnonymous ?? false
                self.attachUserDocListenerIfNeeded(for: user)

                if let u = user, !u.isAnonymous {
                    await self.ensureUserProfile(for: u)
                    _ = await self.cacheProfileImageForCurrentUser(reason: "auth state change")
                } else {
                    self.clearLocalAvatarCache()
                }
            }
        }
    }

    // MARK: - Live-Listener /users/<uid>

    private func attachUserDocListenerIfNeeded(for user: FirebaseAuth.User?) {
        userDocListener?.remove()
        userDocListener = nil

        guard let uid = user?.uid, user?.isAnonymous == false else { return }

        let ref = Firestore.firestore().collection("users").document(uid)
        userDocListener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }
            if let error {
                print("[PROFILE] userDocListener error:", error.localizedDescription)
                return
            }
            guard let data = snap?.data() else { return }
            if let urlStr = data["photoURL"] as? String, !urlStr.isEmpty {
                Task { @MainActor in
                    print("[PROFILE] photoURL changed, recache…")
                    _ = await self.cacheProfileImageForCurrentUser(reason: "photoURL listener")
                }
            }
        }
    }

    // MARK: - E-Mail / Passwort (Callbacks)

    func signIn(email: String,
                password: String,
                completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured(completion: completion) else { return }

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            Task { @MainActor in
                if let error { completion(.failure(error)); return }
                guard let self, let user = result?.user else { return }

                self.isGuest = false
                self.user = user
                self.attachUserDocListenerIfNeeded(for: user)
                await self.ensureUserProfile(for: user)
                _ = await self.cacheProfileImageForCurrentUser(reason: "signIn callback")
                completion(.success(()))
            }
        }
    }

    func signUp(email: String,
                password: String,
                completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured(completion: completion) else { return }

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            Task { @MainActor in
                if let error { completion(.failure(error)); return }
                guard let self, let user = result?.user else { return }

                self.isGuest = false
                self.user = user
                self.attachUserDocListenerIfNeeded(for: user)
                await self.ensureUserProfile(for: user)
                _ = await self.cacheProfileImageForCurrentUser(reason: "signUp callback")
                completion(.success(()))
            }
        }
    }

    func sendPasswordReset(to email: String,
                           completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured(completion: completion) else { return }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error { completion(.failure(error)) }
            else { completion(.success(())) }
        }
    }

    // MARK: - Gastmodus

    /// Klassischer Gast-Login, falls du ihn irgendwo direkt aufrufst.
    func signInAsGuest(completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured(completion: completion) else { return }

        Auth.auth().signInAnonymously { [weak self] result, error in
            Task { @MainActor in
                if let error { completion(.failure(error)) }
                else {
                    self?.isGuest = true
                    self?.user = result?.user
                    completion(.success(()))
                }
            }
        }
    }

    /// Für AuthChoiceView: „Ohne Registrierung fortfahren“.
    /// Nutzt anonymen User nur als Auth-Träger, Daten bleiben lokal (über SyncService).
    func signInAnonymouslyIfNeeded() {
        guard FirebaseApp.app() != nil else {
            print("[AUTH] Firebase not configured for anonymous sign-in.")
            return
        }

        if let current = Auth.auth().currentUser {
            self.user = current
            self.isGuest = current.isAnonymous
            return
        }

        Auth.auth().signInAnonymously { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("[AUTH] Anonymous sign-in failed:", error.localizedDescription)
                    return
                }
                guard let user = result?.user else { return }
                self.user = user
                self.isGuest = true
            }
        }
    }

    func linkCurrentUser(email: String,
                         password: String,
                         completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured(completion: completion) else { return }
        guard let current = Auth.auth().currentUser, current.isAnonymous else {
            completion(.failure(NSError(
                domain: "AuthService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Kein anonymer Nutzer aktiv."]
            )))
            return
        }

        let cred = EmailAuthProvider.credential(withEmail: email, password: password)
        current.link(with: cred) { [weak self] result, error in
            Task { @MainActor in
                if let error { completion(.failure(error)); return }
                guard let self, let user = result?.user else { return }

                self.user = user
                self.isGuest = false
                self.attachUserDocListenerIfNeeded(for: user)
                await self.ensureUserProfile(for: user)
                _ = await self.cacheProfileImageForCurrentUser(reason: "link callback")
                completion(.success(()))
            }
        }
    }

    // MARK: - Abmelden

    func signOut() {
        guard FirebaseApp.app() != nil else { return }
        do {
            try Auth.auth().signOut()
            userDocListener?.remove()
            userDocListener = nil
            self.user = nil
            self.isGuest = false
            clearLocalAvatarCache()
        } catch {
            print("SignOut error:", error.localizedDescription)
        }
    }

    // MARK: - Apple Login

    func signInWithApple(credential: ASAuthorizationAppleIDCredential,
                         nonce: String,
                         completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured(completion: completion) else { return }

        guard
            let tokenData = credential.identityToken,
            let tokenString = String(data: tokenData, encoding: .utf8)
        else {
            completion(.failure(NSError(
                domain: "AuthService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Apple Token konnte nicht gelesen werden."]
            )))
            return
        }

        let oAuthCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        let finish: (User) async -> Void = { user in
            self.isGuest = false
            self.user = user
            self.attachUserDocListenerIfNeeded(for: user)
            await self.ensureUserProfile(for: user)
            _ = await self.cacheProfileImageForCurrentUser(reason: "apple sign in")
        }

        if let current = Auth.auth().currentUser, current.isAnonymous {
            current.link(with: oAuthCredential) { _, error in
                Task { @MainActor in
                    if let error { completion(.failure(error)) }
                    else if let u = Auth.auth().currentUser {
                        await finish(u); completion(.success(()))
                    }
                }
            }
        } else {
            Auth.auth().signIn(with: oAuthCredential) { _, error in
                Task { @MainActor in
                    if let error { completion(.failure(error)) }
                    else if let u = Auth.auth().currentUser {
                        await finish(u); completion(.success(()))
                    }
                }
            }
        }
    }

    // MARK: - Google Login

    func signInWithGoogle(presenting presentingVC: UIViewController,
                          completion: @escaping (Result<Void, Error>) -> Void) {
        guard isConfigured(completion: completion) else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { [weak self] signInResult, error in
            guard let self else { return }

            if let error { completion(.failure(error)); return }

            guard
                let gUser = signInResult?.user,
                let idToken = gUser.idToken?.tokenString
            else {
                completion(.failure(NSError(
                    domain: "AuthService",
                    code: -10,
                    userInfo: [NSLocalizedDescriptionKey: "Google Anmeldedaten fehlen."]
                )))
                return
            }

            let accessToken = gUser.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            let finish: (User) async -> Void = { user in
                self.isGuest = false
                self.user = user
                self.attachUserDocListenerIfNeeded(for: user)
                await self.ensureUserProfile(for: user)
                _ = await self.cacheProfileImageForCurrentUser(reason: "google sign in")
            }

            if let current = Auth.auth().currentUser, current.isAnonymous {
                current.link(with: credential) { _, error in
                    Task { @MainActor in
                        if let error { completion(.failure(error)) }
                        else if let u = Auth.auth().currentUser {
                            await finish(u); completion(.success(()))
                        }
                    }
                }
            } else {
                Auth.auth().signIn(with: credential) { _, error in
                    Task { @MainActor in
                        if let error { completion(.failure(error)) }
                        else if let u = Auth.auth().currentUser {
                            await finish(u); completion(.success(()))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Async/Await Varianten (optional)

    func signIn(email: String, password: String) async throws {
        try ensureConfigured()
        let res = try await Auth.auth().signIn(withEmail: email, password: password)
        self.user = res.user
        self.isGuest = false
        attachUserDocListenerIfNeeded(for: res.user)
        await ensureUserProfile(for: res.user)
        _ = await cacheProfileImageForCurrentUser(reason: "signIn async")
    }

    func signUp(email: String, password: String) async throws {
        try ensureConfigured()
        let res = try await Auth.auth().createUser(withEmail: email, password: password)
        self.user = res.user
        self.isGuest = false
        attachUserDocListenerIfNeeded(for: res.user)
        await ensureUserProfile(for: res.user)
        _ = await cacheProfileImageForCurrentUser(reason: "signUp async")
    }

    func sendPasswordReset(to email: String) async throws {
        try ensureConfigured()
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func signInOrLinkEmail(email: String, password: String) async throws {
        try ensureConfigured()

        if let current = Auth.auth().currentUser, current.isAnonymous {
            let cred = EmailAuthProvider.credential(withEmail: email, password: password)
            let res = try await current.link(with: cred)
            self.user = res.user
            self.isGuest = false
            attachUserDocListenerIfNeeded(for: res.user)
            await ensureUserProfile(for: res.user)
            _ = await cacheProfileImageForCurrentUser(reason: "link async")
        } else {
            let res = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = res.user
            self.isGuest = false
            attachUserDocListenerIfNeeded(for: res.user)
            await ensureUserProfile(for: res.user)
            _ = await cacheProfileImageForCurrentUser(reason: "signIn async 2")
        }
    }

    // MARK: - Profil + Avatar

    private func ensureUserProfile(for user: User) async {
        let db = Firestore.firestore()
        let ref = db.collection("users").document(user.uid)

        do {
            let snap = try await ref.getDocument()
            var updates: [String: Any] = [:]

            if !snap.exists {
                let base = (user.email ?? user.uid).components(separatedBy: "@").first ?? "user"
                let username = base.replacingOccurrences(of: ".", with: "_")
                try await ref.setData([
                    "displayName": user.displayName ?? username,
                    "username": username,
                    "username_lower": username.lowercased(),
                    "photoURL": user.photoURL?.absoluteString ?? ""
                ])
                print("[PROFILE] created profile for \(username)")
            } else {
                if snap.get("username") == nil {
                    let base = (user.email ?? user.uid).components(separatedBy: "@").first ?? "user"
                    let username = base.replacingOccurrences(of: ".", with: "_")
                    updates["username"] = username
                    updates["username_lower"] = username.lowercased()
                }
                if snap.get("displayName") == nil, let name = user.displayName {
                    updates["displayName"] = name
                }
                if !updates.isEmpty {
                    try await ref.updateData(updates)
                    print("[PROFILE] patched profile for \(user.uid)")
                }
            }
        } catch {
            print("[PROFILE] ensureUserProfile error:", error.localizedDescription)
        }
    }

    @discardableResult
    func cacheProfileImageForCurrentUser(reason: String) async -> Bool {
        guard let uid = self.user?.uid, !self.isGuest else { return false }
        print("[PROFILE] cache avatar start (\(reason))")

        // 1) Storage
        let sref = Storage.storage().reference().child("profileImages/\(uid).jpg")
        do {
            let data = try await sref.data(maxSize: 2 * 1024 * 1024)
            setLocalAvatar(data)
            print("[PROFILE] cached from Storage")
            return true
        } catch {
            print("[PROFILE] Storage miss:", error.localizedDescription)
        }

        // 2) Firestore
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let urlStr = doc.get("photoURL") as? String,
               let url = URL(string: urlStr),
               !urlStr.isEmpty,
               let data = try? await downloadURLData(url) {
                setLocalAvatar(data)
                print("[PROFILE] cached from Firestore.photoURL")
                return true
            }
        } catch {
            print("[PROFILE] Firestore read error:", error.localizedDescription)
        }

        // 3) Auth.photoURL
        if let authURL = Auth.auth().currentUser?.photoURL,
           let data = try? await downloadURLData(authURL) {
            setLocalAvatar(data)
            print("[PROFILE] cached from Auth.user.photoURL")
            return true
        }

        print("[PROFILE] no avatar found to cache")
        return false
    }

    private func downloadURLData(_ url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    private func setLocalAvatar(_ data: Data) {
        UserDefaults.standard.set(data, forKey: "profile.imageData")
    }

    private func clearLocalAvatarCache() {
        UserDefaults.standard.removeObject(forKey: "profile.imageData")
    }

    // MARK: - Helpers

    private func isConfigured(completion: ((Result<Void, Error>) -> Void)? = nil) -> Bool {
        guard FirebaseApp.app() != nil else {
            let err = NSError(
                domain: "AuthService",
                code: -1000,
                userInfo: [NSLocalizedDescriptionKey: "Firebase ist noch nicht konfiguriert."]
            )
            completion?(.failure(err))
            return false
        }
        return true
    }

    private func ensureConfigured() throws {
        if FirebaseApp.app() == nil {
            throw NSError(
                domain: "AuthService",
                code: -1000,
                userInfo: [NSLocalizedDescriptionKey: "Firebase ist noch nicht konfiguriert."]
            )
        }
    }
}

// MARK: - Nonce Utilities

func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if status != errSecSuccess { fatalError("Random error: \(status)") }
        for random in randoms where remainingLength > 0 {
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    return result
}

func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = CryptoKit.SHA256.hash(data: inputData)
    return hashed.map { String(format: "%02x", $0) }.joined()
}

// MARK: - Account-Löschung & Daten-Cleanup

extension AuthService {
    func deleteAccountPermanently(completion: @escaping (Result<Void, Error>) -> Void) {
        guard FirebaseApp.app() != nil else {
            completion(.failure(NSError(
                domain: "AuthService",
                code: -1000,
                userInfo: [NSLocalizedDescriptionKey: "Firebase ist noch nicht konfiguriert."]
            )))
            return
        }
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(
                domain: "AuthService",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "Kein Benutzer angemeldet."]
            )))
            return
        }

        let uid = user.uid

        Task { @MainActor in
            do {
                try await deleteAllUserData(uid: uid)
                await deleteStorageIfExists(path: "profileImages/\(uid).jpg")
                await deleteStorageFolderIfExists(prefix: "userContent/\(uid)")

                do {
                    try await user.delete()
                } catch {
                    if let err = error as NSError?,
                       err.domain == AuthErrorDomain,
                       err.code == AuthErrorCode.requiresRecentLogin.rawValue {
                        completion(.failure(NSError(
                            domain: "AuthService",
                            code: err.code,
                            userInfo: [NSLocalizedDescriptionKey:
                                       "Bitte melde dich kurz neu an und versuche es erneut."]
                        )))
                        return
                    } else {
                        throw error
                    }
                }

                self.userDocListener?.remove()
                self.userDocListener = nil
                self.user = nil
                self.isGuest = false
                self.clearLocalAvatarCache()

                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func deleteAllUserData(uid: String) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        let subcollections = [
            "history",
            "templates",
            "challenges",
            "trainingUnits",
            "diagnostics",
            "notes"
        ]

        for name in subcollections {
            try await deleteCollection(path: "users/\(uid)/\(name)", batchSize: 200)
        }

        try await userRef.delete()
    }

    private func deleteCollection(path: String,
                                  batchSize: Int) async throws {
        let db = Firestore.firestore()
        let colRef = db.collection(path)

        while true {
            let snap = try await colRef.limit(to: batchSize).getDocuments()
            if snap.isEmpty { break }
            let batch = db.batch()
            for doc in snap.documents { batch.deleteDocument(doc.reference) }
            try await batch.commit()
        }
    }

    private func deleteStorageIfExists(path: String) async {
        let ref = Storage.storage().reference(withPath: path)
        do { try await ref.delete() } catch { }
    }

    private func deleteStorageFolderIfExists(prefix: String) async {
        let ref = Storage.storage().reference(withPath: prefix)
        do {
            let list = try await ref.listAll()
            for item in list.items { try? await item.delete() }
            for dir in list.prefixes {
                await deleteStorageFolderIfExists(prefix: dir.fullPath)
            }
        } catch { }
    }
}
