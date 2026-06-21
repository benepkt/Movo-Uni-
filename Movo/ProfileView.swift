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
    @State private var showStreakSheet = false // Streak Detail Sheet

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
        mainContent
            .navigationTitle("") // Hide title as requested (since we have custom header)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                 ToolbarItem(placement: .navigationBarLeading) {
                     Button(appSettings.localized("common.back")) { dismiss() }
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
            // Group 1: Sheets
            .sheet(isPresented: $showSettingsSheet) { settingsSheetContent }
            .sheet(isPresented: $showEditMetrics) { editMetricsSheetContent }
            .sheet(isPresented: $showEditMetrics) { editMetricsSheetContent }
            .sheet(isPresented: $showEditProfileSheet) { editProfileSheetContent }
            .sheet(isPresented: $showStreakSheet) {
                StreakDetailView()
                    .environmentObject(trainingStore)
                    .environmentObject(appSettings)
            }
            // Group 2: Alerts
            .alert(appSettings.localized("statistics.unlock.restore"), isPresented: $showRestoreAlert) {
                Button(appSettings.localized("settings.done"), role: .cancel) { }
            } message: { Text(appSettings.localized("iap.restore.started") ?? "Wiederherstellung gestartet.") }
            .alert(appSettings.localized("settings.logout"), isPresented: $confirmLogout) {
                Button(appSettings.localized("settings.logout"), role: .destructive) { authService.signOut() }
                Button(appSettings.localized("settings.done"), role: .cancel) { }
            } message: { Text(appSettings.localized("settings.logout.confirm") ?? "Abmelden?") }
            .alert(appSettings.localized("profile.metrics.healthImport.title") ?? "Health-Import", isPresented: $showHealthAlert) {
                Button(appSettings.localized("settings.done"), role: .cancel) { metricsError = nil }
            } message: { Text(metricsError ?? "") }
    }

    // MARK: - Subviews & Sheets

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: UI.Spacing.lg) {
                newProfileHeader()
                weekOverviewCard()
                levelProgressCard()
                Spacer(minLength: UI.Spacing.lg)
            }
            .padding(.horizontal, UI.Spacing.md)
            .padding(.top, UI.Spacing.sm)
        }
    }

    private var settingsSheetContent: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(appSettings)
                .environmentObject(authService)
                .navigationTitle(appSettings.localized("settings.title.short"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(appSettings.localized("settings.done")) { showSettingsSheet = false }
                    }
                }
        }
        .preferredColorScheme(appSettings.themeMode.colorScheme)
    }

    private var editMetricsSheetContent: some View {
        EditMetricsSheet(
            weightKg: $weightKg,
            heightCm: $heightCm,
            bodyFatPct: $bodyFatPct,
            restingHR: $restingHR,
            error: $metricsError,
            accent: t.palette.primary,
            title: appSettings.localized("profile.metrics.edit")
        )
    }

    private var editProfileSheetContent: some View {
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

    // MARK: - New Redesigned Header
    @ViewBuilder private func newProfileHeader() -> some View {
        VStack(spacing: 20) {
            // 1. Top Row: Streak (Left) & Settings (Right)
            HStack {
                // Streak Bubble -> Button to open Streak Detail
                Button {
                    showStreakSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(trainingStore.currentStreakDays())")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.primary.opacity(0.1)))
                }
                
                Spacer()
                
                // Settings Button
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(Circle().fill(Color.primary.opacity(0.1)))
                }
            }
            .padding(.horizontal, 4)

            // 2. Center: Profile Image (Clean & Modern)
            VStack(spacing: 16) {
                // Profile Image & Edit Badge
                ZStack(alignment: .bottomTrailing) {
                     // Main Circle Border (Restored) - REMOVED AS REQUESTED
                    // Circle()
                    //    .stroke(t.palette.primary.opacity(0.8), lineWidth: 3)
                    //    .frame(width: 118, height: 118)
                    
                    profileImageView
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Edit Badge
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(t.palette.primary))
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .offset(x: 0, y: 0)
                }
                .onTapGesture {
                    // Trigger photo picker programmatically if possible or show sheet?
                    // For now, simpler to just use the picker overlay logic or button below.
                }
                .overlay {
                     PhotosPicker(selection: $selectedItem, matching: .images) {
                        Color.clear.frame(width: 118, height: 118)
                    }
                    .clipShape(Circle())
                    .onChange(of: selectedItem) { newItem in
                        handleImageSelection(newItem)
                    }
                }

                
                // Username & Level Badge
                VStack(spacing: 6) {
                    Text("@\(username.isEmpty ? (authService.user?.email?.split(separator: "@").first.map(String.init) ?? "guest") : username)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    // Level Badge
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("Level \(gm.level)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    
                    // Edit Button (Text only)
                    Button {
                        showEditProfileSheet = true
                    } label: {
                        Text(appSettings.localized("profile.edit") ?? "Edit Profile")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(t.palette.primary)
                            .padding(.top, 4)
                    }
                }
            }

            // 3. Stats Row (Clean & Spacious)
            HStack(spacing: 0) {
                // Time
                let totalSeconds = trainingStore.history.reduce(0) { $0 + $1.duration }
                let hours = Int(totalSeconds / 3600)
                let mins = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
                let timeString = hours > 0 ? "\(hours)h" : "\(mins)m"
                
                StatColumn(icon: "clock.fill", value: timeString, label: appSettings.localized("profile.stats.time"))
                
                Spacer()
                
                // Total Weight (Kg/Lbs)
                let totalVolKg = trainingStore.history.reduce(0.0) { sum, entry in
                    sum + entry.exercises.reduce(0.0) { $0 + $1.totalWeight }
                }
                let weightUnitStr = UserDefaults.standard.string(forKey: "units.weight") ?? "kg"
                let isLbs = weightUnitStr == "lbs"
                let displayVal = isLbs ? (totalVolKg * 2.20462) : totalVolKg
                let unitLabel = isLbs ? "lbs" : "kg"
                
                let volString = formatVolume(displayVal)
                StatColumn(icon: "dumbbell.fill", value: volString, label: unitLabel)
                
                Spacer()
                
                // Workouts
                StatColumn(icon: "figure.run", value: "\(trainingStore.history.count)", label: appSettings.localized("profile.stats.workouts"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .padding(.top, 10)
            
        }
        .padding(.bottom, 20)
        .padding(.horizontal, 4) // Align with header padding logic if needed
    }

    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
         Task {
            guard let item = newItem,
                  let raw = try? await item.loadTransferable(type: Data.self),
                  let uid = authService.user?.uid, !authService.isGuest
            else { return }

            let optimized = optimizeImageDataIfNeeded(raw, maxBytes: MAX_INLINE_AVATAR_BYTES)
            customProfileImageData = optimized
            storedProfileImageData = optimized
            didPickNewImage = true 
            
            do {
                try await setInlineAvatar(uid: uid, jpegData: optimized)
            } catch {
                usernameError = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func formatVolume(_ vol: Double) -> String {
        if vol >= 1_000_000 {
             return String(format: "%.1fm", vol/1_000_000)
        }
        if vol >= 1000 {
            return String(format: "%.1fk", vol/1000)
        }
        return String(format: "%.0f", vol)
    }

    private func localizedOrDefault(_ key: String, de: String, en: String) -> String {
        if appSettings.language == "de" { return de }
        return en
    }

    private struct StatColumn: View {
        let icon: String
        let value: String
        let label: String
        
        var body: some View {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .opacity(0.7)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - New Cards

    @ViewBuilder private func weekOverviewCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appSettings.localized("profile.weekOverview") ?? "Wochenübersicht")
                .font(.headline)
            
            HStack(spacing: 0) {
                // Generate current week days
                let weekDays = currentWeekDays()
                ForEach(weekDays, id: \.date) { day in
                    VStack(spacing: 8) {
                        // Day bubble
                        ZStack {
                            Circle()
                                .fill(day.hasWorkout ? t.palette.primary.opacity(0.2) : Color.clear)
                                .frame(width: 36, height: 36)
                            
                            if day.hasWorkout {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(t.palette.primary)
                            } else if day.isToday {
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        
                        Text(day.dayName)
                            .font(.caption.bold())
                            .foregroundStyle(day.isToday ? .primary : .secondary)
                            
                        Text("\(day.dayNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .appElevatedCard()
    }

    @ViewBuilder private func levelProgressCard() -> some View {
        let snapshot = GamificationManager.progressSnapshot(xp: gm.xp, level: gm.level)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appSettings.localized("profile.levelProgress") ?? "Level Progress")
                    .font(.headline)
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundStyle(t.palette.primary)
            }
            
            HStack {
                Text("Lvl \(snapshot.level)")
                    .font(.subheadline.bold())
                Spacer()
                Text("Lvl \(snapshot.level + 1)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                    
                    Capsule()
                        .fill(t.palette.primary)
                        .frame(width: geo.size.width * snapshot.progress)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text("\(snapshot.xpInLevel) / \(snapshot.xpNeededForLevel) XP")
                Spacer()
                Text("\(snapshot.xpToNextLevel) XP fehlen")
            }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        
        .appElevatedCard()
        .background(Color(.secondarySystemGroupedBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Helpers
    private struct DayStatus {
        let date: Date
        let dayName: String
        let dayNumber: String
        let isToday: Bool
        let hasWorkout: Bool
    }
    
    private func currentWeekDays() -> [DayStatus] {
        let cal = Calendar.current
        let today = Date()
        // Get start of week (Monday) based on user locale or default
        var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        let startOfWeek = cal.date(from: components)!
        
        var days: [DayStatus] = []
        let f = DateFormatter()
        f.dateFormat = "EE" // Mo, Di, ...
        f.locale = Locale(identifier: appSettings.language)
        
        for i in 0..<7 {
            if let date = cal.date(byAdding: .day, value: i, to: startOfWeek) {
                let isToday = cal.isDateInToday(date)
                // Check workout in history
                let hasWorkout = trainingStore.history.contains {
                    cal.isDate($0.date, inSameDayAs: date)
                }
                let dayNum = cal.component(.day, from: date)
                
                days.append(DayStatus(
                    date: date,
                    dayName: String(f.string(from: date).prefix(1)), // M, D, M...
                    dayNumber: "\(dayNum)",
                    isToday: isToday,
                    hasWorkout: hasWorkout
                ))
            }
        }
        return days
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
                    let firestoreUsername = (userData["username"] as? String) ?? ""
                    
                    // Check if we should use the onboarding name
                    if firestoreUsername.isEmpty {
                        // Try to load from onboarding
                        if let onboardingName = UserDefaults.standard.string(forKey: "profile.userName"),
                           !onboardingName.isEmpty {
                            self.username = onboardingName
                            // Save to Firestore
                            Task {
                                try? await self.persistProfile(updates: [
                                    "username": onboardingName,
                                    "username_lower": onboardingName.lowercased()
                                ])
                                // Clear the onboarding name after saving
                                UserDefaults.standard.removeObject(forKey: "profile.userName")
                            }
                        } else {
                            self.username = ""
                        }
                    } else {
                        self.username = firestoreUsername
                    }
                    
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
    @Binding var error: String?

    let accent: Color
    let title: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var healthKit: HealthKitManager

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
                        // Use safe wrapper in HealthKitManager
                        Task {
                            let (kg, cm, fat, hr) = await healthKit.fetchLatestProfileMetrics()
                            await MainActor.run {
                                if let kg { weightKg = kg }
                                if let cm { heightCm = cm }
                                if let fat { bodyFatPct = fat }
                                if let hr { restingHR = Int(hr) }
                                
                                if kg == nil && cm == nil && fat == nil && hr == nil {
                                     // Feedback if no data found/auth denied
                                     // Optional: Handle error or just do nothing (silent fail is safer than crash)
                                }
                            }
                        }
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
    @Binding var didPickNewImage: Bool
    var onDeleteImage: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @EnvironmentObject var appSettings: AppSettings
    
    // Onboarding Data State
    @State private var onboardingData = OnboardingData.load()
    // Local state for picker bindings
    @State private var selectedGoal: FitnessGoal = .buildMuscle
    @State private var selectedLevel: ExperienceLevel = .beginner
    @State private var equipmentSelection: Set<Equipment> = []
    
    // Metrics directly from AppStorage (passed via bindings if possible, or loaded here)
    // To simplify, we'll read/write directly to AppStorage via wrapper or access binding in parent?
    // Parent provided bindings for username/displayName/image. Use OnboardingData for others.

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

                // MARK: - Basic Info
                Section(appSettings.localized("profile.info.title") ?? "Profilinformationen") {
                    TextField(appSettings.localized("profile.displayName") ?? "Anzeigename", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)

                    TextField(appSettings.localized("profile.username") ?? "Benutzername", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                
                // MARK: - Personal Stats (Onboarding)
                Section("Personal Details") {
                    Picker("Gender", selection: Binding(get: { onboardingData.gender ?? .preferNotToSay }, set: { onboardingData.gender = $0 })) {
                        ForEach(Gender.allCases) { gender in
                            Text(gender.localizedTitle(appSettings)).tag(gender)
                        }
                    }
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: Binding(get: { onboardingData.age ?? 0 }, set: { onboardingData.age = $0 }), formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // MARK: - Training Goals (Onboarding)
                Section("Training Goal") {
                     Picker("Goal", selection: $selectedGoal) {
                        ForEach(FitnessGoal.allCases) { goal in
                            Text(goal.localizedTitle(appSettings)).tag(goal)
                        }
                    }
                    .onChange(of: selectedGoal) { val in
                        onboardingData.fitnessGoals = [val] // Single selection for simplicity in UI, though model supports Set
                    }
                }
                
                // MARK: - Experience Level
                 Section("Fitness Level") {
                     Picker("Level", selection: $selectedLevel) {
                        ForEach(ExperienceLevel.allCases) { level in
                            Text(level.localizedTitle(appSettings)).tag(level)
                        }
                    }
                    .onChange(of: selectedLevel) { val in
                        onboardingData.experienceLevel = val
                    }
                }
                
                // MARK: - Training Frequency
                Section("Workouts per Week") {
                    Stepper(value: $onboardingData.trainingFrequency, in: 1...7) {
                        HStack {
                            Text("Frequency")
                            Spacer()
                            Text("\(onboardingData.trainingFrequency)x / week")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // MARK: - Equipment (Multi-Select)
                Section("Available Equipment") {
                    ForEach(Equipment.allCases) { item in
                        Button {
                            if equipmentSelection.contains(item) {
                                equipmentSelection.remove(item)
                            } else {
                                equipmentSelection.insert(item)
                            }
                            onboardingData.equipment = equipmentSelection
                        } label: {
                            HStack {
                                Label(item.localizedTitle(appSettings), systemImage: item.icon)
                                Spacer()
                                if equipmentSelection.contains(item) {
                                    Image(systemName: "checkmark").foregroundStyle(accent)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
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
            .onAppear {
                didPickNewImage = false
                // Init local state from OnboardingData
                if let firstGoal = onboardingData.fitnessGoals.first {
                    selectedGoal = firstGoal
                }
                selectedLevel = onboardingData.experienceLevel
                equipmentSelection = onboardingData.equipment
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("training.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("training.save")) {
                        // Save Onboarding Data
                        onboardingData.save()
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
