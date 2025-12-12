// ProfileView.swift – FRIENDS FEATURE PAUSED
// Profilbild als Base64 in Firestore (/users/{uid}/state/profile.imageB64)

import SwiftUI
import PhotosUI
import UIKit
import HealthKit
import FirebaseAuth
import FirebaseFirestore

// =====================================================
// UI-Grundlagen (Spacing/Radius + Karten-Modifier + Helpers)
// =====================================================

private struct UI {
    struct Radius {
        static let card: CGFloat = 18
        static let hero: CGFloat = 22
        static let chip: CGFloat = 14
    }
    struct Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }
}

private struct AppHeroCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(UI.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: UI.Radius.hero, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UI.Radius.hero, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .background(   // sanfte Farbblobs – Apple-like
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.30)).blur(radius: 70).offset(x: -90, y: -80)
                    Circle().fill(Color.secondary.opacity(0.22)).blur(radius: 90).offset(x: 120, y: 60)
                }
            )
            .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)
    }
}

private struct AppElevatedCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(UI.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: UI.Radius.card, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: UI.Radius.card, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}


private struct IconBadge: View {
    @Environment(\.designTokens) private var t
    let systemName: String
    let size: CGFloat
    var tint: Color? = nil
    var body: some View {
        let c = tint ?? t.palette.primary
        ZStack {
            Circle().fill(c.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(c)
        }
        .frame(width: size, height: size)
    }
}

private struct InfoChip: View {
    @Environment(\.designTokens) private var t
    let title: String
    var body: some View {
        HStack(spacing: 8) { Text(title).font(.subheadline.weight(.semibold)) }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(t.palette.secondary.opacity(0.12)))
            .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 0.5))
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
    }
}

// =====================================================
// ProfileView (Layout zurückgesetzt, nur Edit-Sheet modern)
// =====================================================

struct ProfileView: View {
    @Binding var customProfileImageData: Data?

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var gm: GamificationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t

    @State private var selectedItem: PhotosPickerItem?
    @State private var showEditProfileSheet = false
    @State private var displayName: String = ""
    @State private var userInitials: String = "?"
    @State private var showRestoreAlert = false
    @State private var confirmLogout = false
    @State private var username: String = ""
    @State private var isSavingUsername = false
    @State private var usernameError: String?
    @State private var showSettingsSheet = false
    @State private var showQR = false

    // 👉 Nur Upload wenn im Edit-Sheet wirklich ein neues Bild gewählt wurde
    @State private var didPickNewImage = false

    // Körperwerte & Profilbild
    @AppStorage("profile.weightKg") private var weightKg: Double = 0
    @AppStorage("profile.heightCm") private var heightCm: Double = 0
    @AppStorage("profile.bodyFatPct") private var bodyFatPct: Double = 0
    @AppStorage("profile.restingHR") private var restingHR: Int = 0
    @AppStorage("profile.imageData") private var storedProfileImageData: Data?

    @State private var showEditMetrics = false
    @State private var metricsError: String?
    @State private var showHealthAlert = false

    private let healthStore = HKHealthStore()
    private let MAX_INLINE_AVATAR_BYTES = 500_000 // ~0.5 MB cap vor Base64

    private var shareString: String {
        if !username.isEmpty { return "app://user/@\(username)" }
        if let uid = authService.user?.uid { return "app://user/\(uid)" }
        return "app://user/guest"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: UI.Spacing.lg) {

                headerCard()
                quickActionsRow()

                sectionHeader(appSettings.localized("settings.general"))
                HStack(spacing: UI.Spacing.sm) {
                    statCard(title: appSettings.localized("profile.xp"), value: "\(gm.xp)")
                    statCard(title: appSettings.localized("profile.coins"), value: "\(gm.coins)")
                }

                sectionHeader(appSettings.localized("profile.streakHeader") ?? "Streak")
                streakCard()

                sectionHeader(appSettings.localized("profile.badges"))
                badgesCard()

                sectionHeader(appSettings.localized("profile.metrics.title"))
                metricsGrid()

                Spacer(minLength: UI.Spacing.lg)
            }
            .padding(.horizontal, UI.Spacing.md)
            .padding(.top, UI.Spacing.sm)
        }
        .navigationTitle(appSettings.localized("profile.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(appSettings.localized("profile.close")) { dismiss() }
            }
        }
        .onAppear {
            loadInitials()
            loadProfileFromFirestore()
            if customProfileImageData == nil, let saved = storedProfileImageData {
                customProfileImageData = saved
            }
        }
        .onChange(of: customProfileImageData) { storedProfileImageData = $0 }

        // Settings
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView()
                    .environmentObject(appSettings)
                    .environmentObject(authService)
                    .navigationTitle(appSettings.localized("settings.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(appSettings.localized("settings.done")) { showSettingsSheet = false }
                        }
                    }
            }
            .preferredColorScheme(appSettings.themeMode.colorScheme)
        }

        // Metrics bearbeiten
        .sheet(isPresented: $showEditMetrics) {
            EditMetricsSheet(
                weightKg: $weightKg,
                heightCm: $heightCm,
                bodyFatPct: $bodyFatPct,
                restingHR: $restingHR,
                importFromHealth: { await importFromHealth() },
                error: $metricsError,
                accent: t.palette.primary,
                title: appSettings.localized("profile.metrics.edit")
            )
        }
        
        // Profil bearbeiten Sheet (modern, inkl. Remove)
        .sheet(isPresented: $showEditProfileSheet) {
            EditProfileSheet(
                username: $username,
                displayName: $displayName,
                customProfileImageData: $customProfileImageData,
                onSave: { await saveProfileChanges() },
                accent: t.palette.primary,
                didPickNewImage: $didPickNewImage,
                onDeleteImage: {
                    guard let uid = authService.user?.uid else { return }
                    do { try await deleteInlineAvatar(uid: uid) }
                    catch { usernameError = "Profilbild löschen fehlgeschlagen: \(error.localizedDescription)" }
                }
            )
        }

        // Alerts
        .alert(appSettings.localized("statistics.unlock.restore"),
               isPresented: $showRestoreAlert) {
            Button(appSettings.localized("settings.done"), role: .cancel) { }
        } message: {
            Text(appSettings.localized("iap.restore.started") ?? "Wiederherstellung gestartet – später IAP-Manager einbinden.")
        }

        .alert(appSettings.localized("settings.logout"), isPresented: $confirmLogout) {
            Button(appSettings.localized("settings.logout"), role: .destructive) { authService.signOut() }
            Button(appSettings.localized("settings.done"), role: .cancel) { }
        } message: {
            Text(appSettings.localized("settings.logout.confirm") ?? "Möchtest du dich wirklich abmelden?")
        }

        .alert(appSettings.localized("profile.metrics.healthImport.title") ?? "Health-Import",
               isPresented: $showHealthAlert) {
            Button(appSettings.localized("settings.done"), role: .cancel) { metricsError = nil }
        } message: {
            Text(metricsError ?? "")
        }
    }

    // MARK: - Header (dein ursprünglicher Hero)
    @ViewBuilder private func headerCard() -> some View {
        VStack(spacing: UI.Spacing.sm) {
            // 🔹 Profilbild + Kamera-Button
            ZStack(alignment: .bottomTrailing) {
                profileImageView
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 3))
                    .shadow(radius: 4)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    IconBadge(systemName: "camera.fill", size: 32, tint: .white)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        guard let item = newItem,
                              let raw = try? await item.loadTransferable(type: Data.self),
                              let uid = authService.user?.uid, !authService.isGuest
                        else { return }

                        // 1) Lokal anzeigen/cachen
                        let optimized = optimizeImageDataIfNeeded(raw, maxBytes: MAX_INLINE_AVATAR_BYTES)
                        customProfileImageData = optimized
                        storedProfileImageData = optimized

                        // 2) **Firestore**: Base64 in /users/{uid}/state/profile.imageB64 (+ /users.photoInline)
                        do {
                            try await setInlineAvatar(uid: uid, jpegData: optimized)
                            print("[PROFILE] ✅ imageB64 geschrieben (state/profile)")
                        } catch {
                            print("[PROFILE] ❌ Firestore write:", error.localizedDescription)
                            usernameError = "Profilbild speichern fehlgeschlagen: \(error.localizedDescription)"
                        }
                    }
                }
                .accessibilityLabel(appSettings.localized("profile.photo.change") ?? "Profilbild ändern")
            }

            // 🔹 E-Mail/Anzeigename + Username
            VStack(spacing: 2) {
                Text(displayName.isEmpty ? (authService.user?.email ?? appSettings.localized("profile.guest")) : displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if !username.isEmpty {
                    Text("@\(username)")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            // 🔹 Buttons
            HStack(spacing: 8) {
                if let _ = authService.user?.uid, !authService.isGuest {
                    Button {
                        showEditProfileSheet = true
                    } label: {
                        Label(appSettings.localized("profile.edit") ?? "Profil bearbeiten", systemImage: "pencil")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
            }
            .padding(.top, 2)

            // 🔹 Level-Info + Gauge (systemiger)
            let target = max(100, gm.level * 100)
            VStack(spacing: 8) {
                Text(String(format: appSettings.localized("profile.level"), gm.level))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Gauge(value: Double(gm.xp % target), in: 0...Double(target)) { }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(Gradient(colors: [.white, .white.opacity(0.5)]))
                    .frame(height: 10)
                    .clipShape(Capsule())

                Text(
                    String(
                        format: appSettings.localized("profile.xpProgress"),
                        gm.xp % target,
                        target,
                        gm.level + 1
                    )
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, 2)
        }
        .appHeroCard()
        .padding(.top, 4)
    }

    // MARK: - Quick Actions
    @ViewBuilder private func quickActionsRow() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UI.Spacing.sm) {
                Button { showSettingsSheet = true } label: { InfoChip(title: appSettings.localized("settings.title")) }

                if authService.user != nil {
                    Button { confirmLogout = true } label: { InfoChip(title: appSettings.localized("settings.logout")) }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Cards
    @ViewBuilder private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.title2.bold()).foregroundStyle(t.palette.primary)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .appElevatedCard()
    }

    @ViewBuilder private func streakCard() -> some View {
        let streak = trainingStore.currentStreakDays()
        HStack(spacing: UI.Spacing.md) {
            IconBadge(systemName: "flame.fill", size: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: appSettings.localized("profile.streak"), streak))
                    .font(.headline)
                Text(appSettings.localized("profile.streakHint"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .appElevatedCard()
    }

    @ViewBuilder private func badgesCard() -> some View {
        VStack(alignment: .leading, spacing: UI.Spacing.sm) {
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: UI.Spacing.md) {
                ForEach(gm.badges) { badge in
                    VStack(spacing: 8) {
                        IconBadge(systemName: badge.icon, size: 40, tint: badge.color)
                        Text(localizedBadgeTitle(badge))
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72)
                }
            }
        }
        .appElevatedCard()
    }

    // =====================================================
    // 🔸 Firestore Helpers (Profilfelder + Bild Base64)
    // =====================================================

    private func persistProfile(updates: [String: Any]) async throws {
        guard let uid = authService.user?.uid else { throw NSError(domain: "Auth", code: 401) }
        try await Firestore.firestore()
            .collection("users").document(uid)
            .setData(updates, merge: true)
    }

    private func stateProfileRef(uid: String) -> DocumentReference {
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("state").document("profile")
    }

    /// Schreibt Base64-JPEG ins state/profile.imageB64 + Duplikat ins /users.photoInline (Batch, capped)
    private func setInlineAvatar(uid: String, jpegData: Data) async throws {
        let optimized = optimizeImageDataIfNeeded(jpegData, maxBytes: MAX_INLINE_AVATAR_BYTES) // cap
        let b64 = optimized.base64EncodedString()
        let db = Firestore.firestore()

        let batch = db.batch()
        let stateRef = stateProfileRef(uid: uid)
        let userRef  = db.collection("users").document(uid)

        batch.setData([
            "imageB64": b64,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: stateRef, merge: true)

        batch.setData([
            "photoInline": b64,
            "photoUpdatedAt": FieldValue.serverTimestamp()
        ], forDocument: userRef, merge: true)

        try await batch.commit()
    }

    /// Entfernt das Inline-Profilbild (Cloud) und leert lokale Caches
    private func deleteInlineAvatar(uid: String) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        let stateRef = stateProfileRef(uid: uid)
        let userRef  = db.collection("users").document(uid)

        batch.setData([
            "imageB64": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: stateRef, merge: true)

        batch.setData([
            "photoInline": FieldValue.delete(),
            "photoUpdatedAt": FieldValue.serverTimestamp()
        ], forDocument: userRef, merge: true)

        try await batch.commit()

        await MainActor.run {
            self.customProfileImageData = nil
            self.storedProfileImageData = nil
            self.didPickNewImage = false
        }
    }

    // MARK: - Profil laden
    private func loadProfileFromFirestore() {
        guard let uid = authService.user?.uid else { return }

        Task {
            do {
                let db = Firestore.firestore()

                // 1) User-Dokument
                let userSnap = try await db.collection("users").document(uid).getDocument()
                let userData = userSnap.data() ?? [:]

                // 2) State/Profile (bevorzugt)
                let stateSnap = try? await stateProfileRef(uid: uid).getDocument()
                let stateData = stateSnap?.data() ?? [:]

                await MainActor.run {
                    // Textfelder
                    self.username    = (userData["username"] as? String) ?? ""
                    self.displayName = (userData["displayName"] as? String) ?? ""

                    // Bild: bevorzugt Base64 aus state/profile, sonst /users.photoInline
                    let b64 = (stateData["imageB64"] as? String) ?? (userData["photoInline"] as? String)

                    // NICHT überschreiben, wenn gerade neues Bild im Sheet gewählt wurde
                    if !self.didPickNewImage, let b64,
                       let bytes = Data(base64Encoded: b64) {
                        self.customProfileImageData = bytes
                        self.storedProfileImageData = bytes   // @AppStorage-Cache
                    }
                }

                print("[PROFILE] ℹ️ loaded profile for \(uid)")
            } catch {
                await MainActor.run {
                    self.usernameError = "Fehler beim Laden des Profils: \(error.localizedDescription)"
                }
                print("[PROFILE] ❌ load error:", error.localizedDescription)
            }
        }
    }

    // MARK: - Username speichern (optional)
    private func saveUsername() async {
        guard authService.user?.uid != nil else { return }
        let newName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        isSavingUsername = true; usernameError = nil
        do {
            try await persistProfile(updates: [
                "username": newName,
                "username_lower": newName.lowercased()
            ])
            print("[PROFILE] Username aktualisiert auf \(newName)")
        } catch {
            usernameError = "Fehler: \(error.localizedDescription)"
        }
        isSavingUsername = false
    }

    // MARK: - Profil speichern (Sheet)
    @MainActor
    private func saveProfileChanges() async {
        guard let uid = authService.user?.uid else { return }

        isSavingUsername = true
        usernameError = nil
        defer { isSavingUsername = false }

        do {
            let trimmedUsername    = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

            var updates: [String: Any] = [:]

            if !trimmedUsername.isEmpty {
                updates["username"]       = trimmedUsername
                updates["username_lower"] = trimmedUsername.lowercased()
            }
            if !trimmedDisplayName.isEmpty {
                updates["displayName"] = String(trimmedDisplayName.prefix(40))
            }

            // 🔹 Profilbild nur wenn im aktuellen Sheet NEU gewählt
            if didPickNewImage, let data = customProfileImageData {
                do {
                    let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.95) ?? data
                    try await setInlineAvatar(uid: uid, jpegData: jpeg) // Firestore-only
                    updates["photoUpdatedAt"] = FieldValue.serverTimestamp()
                    didPickNewImage = false
                } catch {
                    usernameError = "Profilbild-Upload fehlgeschlagen: \(error.localizedDescription)"
                }
            }

            if !updates.isEmpty {
                try await persistProfile(updates: updates)
                print("[PROFILE] ✅ Firestore merge ok with keys:", Array(updates.keys))
            }

            // Optional: Auth-Profil Displayname syncen
            if let user = Auth.auth().currentUser, !trimmedDisplayName.isEmpty {
                let change = user.createProfileChangeRequest()
                change.displayName = String(trimmedDisplayName.prefix(40))
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    change.commitChanges { error in
                        if let error { cont.resume(throwing: error) } else { cont.resume(returning: ()) }
                    }
                }
            }

            print("[PROFILE] ✅ Profil aktualisiert (state/profile.imageB64 aktiv)")
        } catch {
            usernameError = "Fehler: \(error.localizedDescription)"
            print("[PROFILE] ❌ Fehler beim Speichern:", error.localizedDescription)
        }
    }

    // MARK: - Metrics
    @ViewBuilder private func metricsGrid() -> some View {
        VStack(spacing: UI.Spacing.sm) {
            HStack {
                MetricCard(
                    title: appSettings.localized("profile.metrics.weightKg"),
                    value: weightKg > 0 ? "\(format(weightKg))" : "—",
                    icon: "scalemass",
                    accent: t.palette.primary
                )
                MetricCard(
                    title: appSettings.localized("profile.metrics.heightCm"),
                    value: heightCm > 0 ? "\(Int(heightCm))" : "—",
                    icon: "ruler",
                    accent: t.palette.primary
                )
            }

            HStack {
                MetricCard(
                    title: appSettings.localized("profile.metrics.bmi"),
                    value: bmiText(),
                    icon: "figure.arms.open",
                    accent: t.palette.primary
                )
                MetricCard(
                    title: appSettings.localized("profile.metrics.restingHR"),
                    value: restingHR > 0 ? "\(restingHR)" : "—",
                    icon: "heart.fill",
                    accent: t.palette.warning
                )
            }

            HStack {
                MetricCard(
                    title: appSettings.localized("profile.metrics.bodyFatPct"),
                    value: bodyFatPct > 0 ? "\(format(bodyFatPct))" : "—",
                    icon: "percent",
                    accent: t.palette.secondary
                )
                Button { showEditMetrics = true } label: {
                    HStack(spacing: UI.Spacing.md) {
                        IconBadge(systemName: "slider.horizontal.3", size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appSettings.localized("common.edit")).font(.headline)
                            Text(appSettings.localized("profile.metrics.title"))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(height: 96)
                    .appElevatedCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Section Header
    @ViewBuilder private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, UI.Spacing.lg)
        .padding(.horizontal, 2)
    }

    // MARK: - Helpers
    private var profileImageView: some View {
        Group {
            if let data = customProfileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill().clipShape(Circle())
            } else if let data = storedProfileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(userInitials)
                    .font(.largeTitle).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 100, height: 100)
                    .background(Circle().fill(Color.accentColor))
            }
        }
    }

    private func loadInitials() {
        if let email = authService.user?.email {
            let namePart = email.split(separator: "@").first ?? ""
            let parts = namePart.split(separator: ".")
            let initials = parts.prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
            userInitials = initials.isEmpty ? "?" : initials
        } else if authService.isGuest {
            userInitials = appSettings.localized("profile.guest")
        } else {
            userInitials = "?"
        }
    }

    private func format(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func bmiText() -> String {
        guard weightKg > 0, heightCm > 0 else { return "—" }
        let m = heightCm / 100.0
        let bmi = weightKg / (m*m)
        return format(bmi)
    }

    // Lokalisierter Badge-Titel (Fallback)
    private func localizedBadgeTitle(_ badge: BadgeItem) -> String {
        let key = "badge.\(badge.type.rawValue)"
        let value = appSettings.localized(key)
        return (value == key) ? badge.displayName : value
    }

    // MARK: - Health Import
    private func importFromHealth() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            metricsError = appSettings.localized("profile.metrics.health.unavailable") ?? "Health nicht verfügbar."
            showHealthAlert = true
            return
        }
        let readTypes: Set = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        ]
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            async let w = fetchLatestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
            async let h = fetchLatestQuantity(.height, unit: .meterUnit(with: .centi))
            async let bf = fetchLatestQuantity(.bodyFatPercentage, unit: HKUnit.percent())
            async let rhr = fetchLatestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: HKUnit.minute()))
            let (kg, cm, fat, bpm) = try await (w, h, bf, rhr)
            if let kg { weightKg = kg }
            if let cm { heightCm = cm }
            if let fat { bodyFatPct = max(0, min(100, fat * 100)) }
            if let bpm { restingHR = Int(round(bpm)) }
        } catch {
            metricsError = (appSettings.localized("profile.metrics.health.authFailed") ?? "Health-Zugriff fehlgeschlagen") + ": \(error.localizedDescription)"
            showHealthAlert = true
        }
    }

    private func fetchLatestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let qType = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: .distantPast, end: Date(), options: [])
        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: qType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                guard let sample = samples?.first as? HKQuantitySample else {
                    cont.resume(returning: nil); return
                }
                cont.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    /// Komprimiert Bilddaten falls größer als `maxBytes`
    private func optimizeImageDataIfNeeded(_ data: Data, maxBytes: Int) -> Data {
        guard data.count > maxBytes,
              let image = UIImage(data: data) else { return data }
        var compression: CGFloat = 0.9
        var newData = image.jpegData(compressionQuality: compression) ?? data
        while newData.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            newData = image.jpegData(compressionQuality: compression) ?? data
        }
        return newData
    }
}

// =====================================================
// Unteransichten / Eingaben
// =====================================================

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: UI.Spacing.md) {
            IconBadge(systemName: icon, size: 40, tint: accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.footnote).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
            Spacer()
        }
        .frame(height: 96)
        .appElevatedCard()
    }
}

private struct EditMetricsSheet: View {
    @Binding var weightKg: Double
    @Binding var heightCm: Double
    @Binding var bodyFatPct: Double
    @Binding var restingHR: Int

    var importFromHealth: () async -> Void
    @Binding var error: String?

    let accent: Color
    let title: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumericField(title: appSettings.localized("profile.metrics.weightKg"), value: $weightKg, step: 0.1)
                    NumericField(title: appSettings.localized("profile.metrics.heightCm"), value: $heightCm, step: 1)
                    NumericField(title: appSettings.localized("profile.metrics.bodyFatPct"), value: $bodyFatPct, step: 0.1)
                    StepperField(title: appSettings.localized("profile.metrics.restingHR"), value: $restingHR, range: 20...240)
                } header: { Text(title) }

                Section {
                    Button {
                        Task { await importFromHealth() }
                    } label: {
                        Label(appSettings.localized("profile.metrics.importHealth"), systemImage: "heart.fill")
                    }
                } header: { Text(appSettings.localized("profile.metrics.healthImport.title") ?? "Apple Health") }
            }
            .tint(accent)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(appSettings.localized("settings.done")) { dismiss() } }
            }
        }
    }
}

private struct EditProfileSheet: View {
    @Binding var username: String
    @Binding var displayName: String
    @Binding var customProfileImageData: Data?
    var onSave: () async -> Void
    let accent: Color

    // 👉 Flag, ob in DIESEM Sheet ein neues Bild gewählt wurde
    @Binding var didPickNewImage: Bool

    // 👉 Callback zum kompletten Entfernen des Profilbilds
    var onDeleteImage: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Profilbild
                Section {
                    HStack {
                        Spacer()
                        ZStack(alignment: .bottomTrailing) {
                            profileImage
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 2))
                                .shadow(radius: 3)

                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .foregroundStyle(.white)
                                            .font(.system(size: 16, weight: .semibold))
                                    )
                                    .shadow(radius: 2)
                            }
                            .onChange(of: selectedItem) { newItem in
                                Task {
                                    if let newItem,
                                       let data = try? await newItem.loadTransferable(type: Data.self) {
                                        customProfileImageData = data
                                        didPickNewImage = true
                                    }
                                }
                            }
                            .accessibilityLabel(appSettings.localized("profile.photo.change") ?? "Profilbild ändern")
                        }
                        Spacer()
                    }
                }

                // MARK: - Profilinformationen
                Section(appSettings.localized("profile.info.title") ?? "Profilinformationen") {
                    TextField(appSettings.localized("profile.displayName") ?? "Anzeigename", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)

                    TextField(appSettings.localized("profile.username") ?? "Benutzername", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(appSettings.localized("profile.info.note.title") ?? "Hinweis") {
                    Text(appSettings.localized("profile.info.note.text") ?? "Dein Anzeigename wird öffentlich angezeigt. Der Benutzername ist eindeutig.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Bild entfernen
                Section {
                    Button(role: .destructive) {
                        Task {
                            await onDeleteImage()
                            dismiss()
                        }
                    } label: {
                        Label(appSettings.localized("profile.photo.remove") ?? "Profilbild entfernen", systemImage: "trash")
                    }
                }
            }
            .tint(accent)
            .navigationTitle(appSettings.localized("profile.edit.title") ?? "Profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { didPickNewImage = false }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("training.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("training.save")) {
                        Task { await onSave(); dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Profilbildanzeige
    private var profileImage: some View {
        Group {
            if let data = customProfileImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(accent.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(accent)
                            .font(.system(size: 40, weight: .medium))
                    )
            }
        }
    }
}

private struct NumericField: View {
    let title: String
    @Binding var value: Double
    let step: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, formatter: numberFormatter)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 80)
        }
    }

    private var numberFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .current
        f.numberStyle = .decimal
        if step < 1 { f.minimumFractionDigits = 0; f.maximumFractionDigits = 1 }
        else { f.minimumFractionDigits = 0; f.maximumFractionDigits = 0 }
        return f
    }
}

private struct StepperField: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...300

    var body: some View {
        Stepper(value: $value, in: range, step: 1) {
            HStack {
                Text(title)
                Spacer()
                Text(value > 0 ? "\(value)" : "—").foregroundStyle(.secondary)
            }
        }
    }
}

