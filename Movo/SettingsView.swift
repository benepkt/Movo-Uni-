import SwiftUI
import WidgetKit

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let showsDoneButton: Bool
    init(showsDoneButton: Bool = false) { self.showsDoneButton = showsDoneButton }
    
    @State private var confirmLogout = false
    @State private var showAccountSheet = false
    @State private var showLanguageSheet = false
    @State private var showLegalSheet = false
    @State private var showGoalsSheet = false
    @State private var showPrivacyAnalyticsSheet = false
    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Account
                SettingsRow(
                    icon: "key.fill",
                    title: appSettings.localized("settings.account") ?? "Konto",
                    colorScheme: colorScheme
                ) {
                    showAccountSheet = true
                }
                
                Divider().background(Color.primary.opacity(0.1))

                // Language
                SettingsRowWithValue(
                    icon: "globe",
                    title: appSettings.localized("settings.language") ?? "Sprache",
                    value: appSettings.language == "de" ? "Deutsch" : "English",
                    colorScheme: colorScheme
                ) {
                    showLanguageSheet = true
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Units
                SettingsRowWithValue(
                    icon: "ruler.fill",
                    title: appSettings.localized("settings.units") ?? "Einheiten",
                    value: weightUnit == .kg ? "Metric" : "Imperial",
                    colorScheme: colorScheme
                ) {
                    weightUnit = weightUnit == .kg ? .lb : .kg
                }
                
                Divider().background(Color.primary.opacity(0.1))

                SettingsRow(
                    icon: "target",
                    title: appSettings.language.lowercased().hasPrefix("de") ? "Daten & Ziele" : "Data & goals",
                    colorScheme: colorScheme
                ) {
                    showGoalsSheet = true
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Notifications
                SettingsRow(
                    icon: "bell.fill",
                    title: appSettings.localized("settings.notifications") ?? "Benachrichtigungen",
                    colorScheme: colorScheme
                ) {
                    openNotificationSettings()
                }
                
                Divider().background(Color.primary.opacity(0.1))

                SettingsRowWithValue(
                    icon: "hand.raised.fill",
                    title: appSettings.language.lowercased().hasPrefix("de") ? "Datenschutz & Analytics" : "Privacy & analytics",
                    value: appSettings.analyticsEnabled
                        ? (appSettings.language.lowercased().hasPrefix("de") ? "Aktiv" : "On")
                        : (appSettings.language.lowercased().hasPrefix("de") ? "Aus" : "Off"),
                    colorScheme: colorScheme
                ) {
                    showPrivacyAnalyticsSheet = true
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Legal
                SettingsRow(
                    icon: "doc.text.fill",
                    title: appSettings.localized("settings.legal") ?? "Rechtliches",
                    colorScheme: colorScheme
                ) {
                    showLegalSheet = true
                }
                
                Divider().background(Color.primary.opacity(0.1))
                
                // Log Out
                SettingsRow(
                    icon: "arrow.right.square.fill",
                    title: appSettings.localized("settings.logout") ?? "Abmelden",
                    isDestructive: true,
                    colorScheme: colorScheme
                ) {
                    confirmLogout = true
                }
                
                
                // Debug Info Removed
                
                // Version
                Text("Version \(appVersion())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationTitle(appSettings.localized("settings.title") ?? "Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(appSettings.localized("settings.title") ?? "Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("settings.done") ?? "Fertig") {
                        dismiss()
                    }
                }
            }
        }
        
        // Sheets
        .sheet(isPresented: $showAccountSheet) {
            NavigationStack {
                AccountSettingsView()
                    .environmentObject(appSettings)
                    .environmentObject(authService)
            }
        }
        .sheet(isPresented: $showLanguageSheet) {
            LanguagePickerSheet(language: $appSettings.language,
                                title: appSettings.localized("settings.language") ?? "Sprache")
        }
        .sheet(isPresented: $showGoalsSheet) {
            PersonalGoalsSettingsView()
                .environmentObject(appSettings)
        }
        .sheet(isPresented: $showPrivacyAnalyticsSheet) {
            PrivacyAnalyticsSettingsView()
                .environmentObject(appSettings)
        }
        .sheet(isPresented: $showLegalSheet) {
            NavigationStack {
                LegalView()
                    .environmentObject(appSettings)
            }
        }
        
        // Alerts
        .alert(appSettings.localized("settings.logout") ?? "Abmelden", isPresented: $confirmLogout) {
            Button(appSettings.localized("settings.logout") ?? "Abmelden", role: .destructive) {
                authService.signOut()
            }
            Button(appSettings.localized("common.cancel") ?? "Abbrechen", role: .cancel) { }
        } message: {
            Text(appSettings.localized("settings.logout.confirm") ?? "Möchtest du dich wirklich abmelden?")
        }
        
        // Sync changes
        .onChange(of: weightUnit) { newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "units.weight")
            UserDefaults(suiteName: APP_GROUP_ID)?.set(newValue.rawValue, forKey: "units.weight")
            if #available(iOS 16.1, *) {
                LiveActivityManager.shared.refreshUnit(newValue)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: appSettings.language) { newCode in
            let code = normalizeLang(newCode)
            UserDefaults.standard.set(code, forKey: "app.language")
            UserDefaults(suiteName: APP_GROUP_ID)?.set(code, forKey: "app.language")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - Helper Functions
    
    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func normalizeLang(_ code: String) -> String {
        code.lowercased().hasPrefix("de") ? "de" : "en"
    }
}

// MARK: - Settings Row Components

struct SettingsRow: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isDestructive ? .red : .primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(isDestructive ? .red : .primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsRowWithValue: View {
    let icon: String
    let title: String
    let value: String
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PersonalGoalsSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t

    @AppStorage("profile.weightKg") private var weightKg: Double = 70
    @AppStorage("profile.heightCm") private var heightCm: Double = 175
    @AppStorage("profile.goalWeightKg") private var goalWeightKg: Double = 75
    @AppStorage("profile.hasGoalWeight") private var hasGoalWeight: Bool = true
    @AppStorage("steps.goal") private var stepsGoal: Int = 8000

    @State private var onboardingData = OnboardingData.load()

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(colors: [t.palette.primary.opacity(0.32), Color.cyan.opacity(0.12), .clear],
                               center: .topLeading,
                               startRadius: 24,
                               endRadius: 430)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(isDE ? "Deine Daten" : "Your data")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(t.palette.primary)
                                .textCase(.uppercase)
                            Text(isDE ? "Ziele bearbeiten" : "Edit goals")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(isDE ? "Passe Gewicht, Schritte und Trainingsprofil jederzeit an." : "Adjust weight, steps and training profile anytime.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                        }

                        settingsCard(title: isDE ? "Körper" : "Body", icon: "figure") {
                            valueStepper(title: isDE ? "Aktuelles Gewicht" : "Current weight", value: $weightKg, range: 30...250, step: 0.1, suffix: "kg")
                            valueStepper(title: isDE ? "Größe" : "Height", value: $heightCm, range: 120...230, step: 1, suffix: "cm")
                            Toggle(isDE ? "Zielgewicht nutzen" : "Use goal weight", isOn: $hasGoalWeight)
                                .tint(t.palette.primary)
                            if hasGoalWeight {
                                valueStepper(title: isDE ? "Zielgewicht" : "Goal weight", value: $goalWeightKg, range: 30...250, step: 0.1, suffix: "kg")
                            }
                        }

                        settingsCard(title: isDE ? "Aktivität" : "Activity", icon: "figure.walk") {
                            Stepper(value: $stepsGoal, in: 1000...30000, step: 500) {
                                settingsValueRow(title: isDE ? "Schrittziel" : "Step goal", value: "\(stepsGoal.formatted())")
                            }
                            Stepper(value: $onboardingData.trainingFrequency, in: 1...7) {
                                settingsValueRow(title: isDE ? "Trainingstage" : "Training days", value: "\(onboardingData.trainingFrequency)x/Woche")
                            }
                        }

                        settingsCard(title: isDE ? "Trainingsprofil" : "Training profile", icon: "dumbbell.fill") {
                            Picker(isDE ? "Ziel" : "Goal", selection: firstGoalBinding) {
                                ForEach(FitnessGoal.allCases) { goal in
                                    Label(goal.localizedTitle(appSettings), systemImage: goal.icon).tag(goal)
                                }
                            }
                            Picker(isDE ? "Level" : "Level", selection: $onboardingData.experienceLevel) {
                                ForEach(ExperienceLevel.allCases) { level in
                                    Label(level.localizedTitle(appSettings), systemImage: level.icon).tag(level)
                                }
                            }
                            Picker(isDE ? "Trainingsort" : "Training place", selection: $onboardingData.trainingLocation) {
                                ForEach(TrainingLocation.allCases) { location in
                                    Label(location.localizedTitle(appSettings), systemImage: location.icon).tag(location)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("common.cancel")) { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("training.save")) {
                        onboardingData.save()
                        dismiss()
                    }
                    .foregroundStyle(t.palette.primary)
                }
            }
        }
    }

    private var firstGoalBinding: Binding<FitnessGoal> {
        Binding(
            get: { onboardingData.fitnessGoals.first ?? .buildMuscle },
            set: { onboardingData.fitnessGoals = [$0] }
        )
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func valueStepper(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            settingsValueRow(title: title, value: "\(format(value.wrappedValue, step: step)) \(suffix)")
        }
    }

    private func settingsValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private func format(_ value: Double, step: Double) -> String {
        step < 1 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
    }
}

// MARK: - Account Settings View

struct AccountSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @Environment(\.dismiss) private var dismiss
    
    @State private var confirmDelete = false
    @State private var isDeletingAccount = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var lastSyncDate: Date?
    
    
    var body: some View {
        List {
            cloudSection
            deleteSection
        }
        .navigationTitle(appSettings.localized("settings.account") ?? "Konto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(appSettings.localized("settings.done") ?? "Fertig") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadLastSyncDate()
        }
        .alert(appSettings.localized("settings.account.delete") ?? "Konto löschen", isPresented: $confirmDelete) {
            Button(appSettings.localized("settings.account.delete.confirm") ?? "Dauerhaft löschen", role: .destructive) {
                deleteAccount()
            }
            Button(appSettings.localized("common.cancel") ?? "Abbrechen", role: .cancel) { }
        } message: {
            Text(appSettings.localized("settings.account.delete.warning") ?? "Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Daten werden dauerhaft gelöscht.")
        }
        .alert(appSettings.localized("common.error") ?? "Fehler", isPresented: $showError) {
            Button(appSettings.localized("common.ok") ?? "OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Sections

    
    @ViewBuilder
    private var cloudSection: some View {
        Section {
            cloudStatusView
            
            if authService.user != nil {
                cloudSyncButton
            }
        } header: {
            Text(appSettings.localized("cloud.title") ?? "Movo Cloud")
        } footer: {
            Text(appSettings.localized("cloud.subtitle") ?? "Movo synchronisiert NICHT automatisch. Du speicherst & synchronisierst manuell, wenn du möchtest.")
        }
    }
    
    private var cloudStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: authService.user != nil ? "checkmark.icloud.fill" : "icloud.slash")
                    .foregroundStyle(authService.user != nil ? .green : .secondary)
                Text(authService.user != nil ? 
                     (appSettings.localized("cloud.status.active") ?? "Movo Cloud aktiv") : 
                     (appSettings.localized("cloud.status.guest") ?? "Lokaler Modus (Gast)"))
            }
            
            if let user = authService.user {
                Text(user.email ?? (appSettings.localized("cloud.subtitle.noEmail") ?? "ohne E-Mail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let lastSync = lastSyncDate {
                    Text("\(appSettings.localized("cloud.lastSync.prefix") ?? "Stand:"): \(formatDate(lastSync))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(appSettings.localized("cloud.subtitle.guest") ?? "Melde dich an, um Daten mit der Movo Cloud zu synchronisieren.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var cloudSyncButton: some View {
        Button {
            syncNow()
        } label: {
            HStack {
                if isSyncing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(isSyncing ? 
                     (appSettings.localized("cloud.button.syncing") ?? "Synchronisiere") : 
                     (appSettings.localized("cloud.syncNow") ?? "Jetzt synchronisieren"))
            }
        }
        .disabled(isSyncing)
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(appSettings.localized("settings.account.delete") ?? "Konto löschen")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func syncNow() {
        isSyncing = true
        Task {
            // First pull from cloud, then push local changes
            await syncService.uiManualPullMerge()
            await syncService.uiPushAll()
            
            await MainActor.run {
                isSyncing = false
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            }
        }
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func deleteAccount() {
        isDeletingAccount = true
        authService.deleteAccountPermanently { result in
            DispatchQueue.main.async {
                isDeletingAccount = false
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}


// MARK: - Change Password View

struct ChangePasswordView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChanging = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(appSettings.localized("settings.account.currentPassword") ?? "Aktuelles Passwort", text: $currentPassword)
                }
                
                Section {
                    SecureField(appSettings.localized("settings.account.newPassword") ?? "Neues Passwort", text: $newPassword)
                    SecureField(appSettings.localized("settings.account.confirmPassword") ?? "Passwort bestätigen", text: $confirmPassword)
                }
                
                Section {
                    Button {
                        changePassword()
                    } label: {
                        if isChanging {
                            ProgressView()
                        } else {
                            Text(appSettings.localized("settings.account.changePassword") ?? "Passwort ändern")
                        }
                    }
                    .disabled(currentPassword.isEmpty || newPassword.isEmpty || newPassword != confirmPassword || isChanging)
                }
            }
            .navigationTitle(appSettings.localized("settings.account.changePassword") ?? "Passwort ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("common.cancel") ?? "Abbrechen") {
                        dismiss()
                    }
                }
            }
            .alert(appSettings.localized("common.error") ?? "Fehler", isPresented: $showError) {
                Button(appSettings.localized("common.ok") ?? "OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func changePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = appSettings.localized("settings.account.passwordMismatch") ?? "Passwörter stimmen nicht überein"
            showError = true
            return
        }
        
        isChanging = true
        authService.changePassword(currentPassword: currentPassword, newPassword: newPassword) { result in
            DispatchQueue.main.async {
                isChanging = false
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Reset Password View

struct ResetPasswordView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var isResetting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(appSettings.localized("settings.account.email") ?? "E-Mail", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                } header: {
                    Text(appSettings.localized("settings.account.resetPassword.info") ?? "Gib deine E-Mail-Adresse ein, um einen Link zum Zurücksetzen deines Passworts zu erhalten.")
                }
                
                Section {
                    Button {
                        resetPassword()
                    } label: {
                        if isResetting {
                            ProgressView()
                        } else {
                            Text(appSettings.localized("settings.account.sendResetLink") ?? "Link senden")
                        }
                    }
                    .disabled(email.isEmpty || isResetting)
                }
            }
            .navigationTitle(appSettings.localized("settings.account.resetPassword") ?? "Passwort zurücksetzen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("common.cancel") ?? "Abbrechen") {
                        dismiss()
                    }
                }
            }
            .alert(appSettings.localized("common.success") ?? "Erfolg", isPresented: $showSuccess) {
                Button(appSettings.localized("common.ok") ?? "OK") {
                    dismiss()
                }
            } message: {
                Text(appSettings.localized("settings.account.resetPassword.sent") ?? "Ein Link zum Zurücksetzen wurde an deine E-Mail gesendet.")
            }
            .alert(appSettings.localized("common.error") ?? "Fehler", isPresented: $showError) {
                Button(appSettings.localized("common.ok") ?? "OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func resetPassword() {
        isResetting = true
        authService.sendPasswordReset(email: email) { result in
            DispatchQueue.main.async {
                isResetting = false
                switch result {
                case .success:
                    showSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Language Picker Sheet

struct LanguagePickerSheet: View {
    @Binding var language: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    language = "de"
                    dismiss()
                } label: {
                    HStack {
                        Text("Deutsch")
                        Spacer()
                        if language == "de" {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Button {
                    language = "en"
                    dismiss()
                } label: {
                    HStack {
                        Text("English")
                        Spacer()
                        if language == "en" {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Privacy / Analytics

private struct PrivacyAnalyticsSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        t.palette.primary.opacity(0.28),
                        Color.cyan.opacity(0.12),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        settingsCard(title: isDE ? "Produktanalyse" : "Product analytics",
                                     icon: "chart.line.uptrend.xyaxis") {
                            Toggle(isDE ? "Nutzungsanalyse erlauben" : "Allow usage analytics", isOn: $appSettings.analyticsEnabled)
                                .tint(t.palette.primary)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)

                            Text(isDE
                                 ? "Hilft uns zu verstehen, welche Bereiche von Movo genutzt werden, ob Trainings gespeichert werden und wo Funktionen verbessert werden sollten."
                                 : "Helps us understand which parts of Movo are used, whether workouts are saved, and where features should be improved.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        settingsCard(title: isDE ? "Nicht aktiv" : "Not active",
                                     icon: "eye.slash.fill") {
                            privacyStatusRow(
                                title: "Session Replay",
                                value: isDE ? "Aus" : "Off",
                                color: .green
                            )
                            Text(isDE
                                 ? "Bildschirmaufzeichnungen sind in Movo deaktiviert. Es werden keine Session-Replay-Aufnahmen an PostHog gesendet."
                                 : "Screen recordings are disabled in Movo. No session replay recordings are sent to PostHog.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        settingsCard(title: isDE ? "Was erfasst wird" : "What is collected",
                                     icon: "list.bullet.clipboard.fill") {
                            privacyBullet(isDE ? "App-Bereiche, die geöffnet werden" : "App areas that are opened")
                            privacyBullet(isDE ? "Ob ein Training, Plan oder Template erstellt/gespeichert wurde" : "Whether a workout, plan, or template was created/saved")
                            privacyBullet(isDE ? "Technische Nutzungsdaten wie Quelle, Anzahl Übungen oder Dauer" : "Technical usage data like source, exercise count, or duration")
                            privacyBullet(isDE ? "Keine Passwörter und keine Session-Replay-Aufnahmen" : "No passwords and no session replay recordings")
                        }

                        Link(destination: URL(string: "https://www.movobp.de/datenschutz.html")!) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                Text(isDE ? "Datenschutzerklärung öffnen" : "Open privacy policy")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(t.palette.primary))
                        }
                    }
                    .padding(20)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                        .foregroundStyle(t.palette.primary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isDE ? "Datenschutz" : "Privacy")
                .font(.caption.weight(.bold))
                .foregroundStyle(t.palette.primary)
                .textCase(.uppercase)
            Text(isDE ? "Analytics verwalten" : "Manage analytics")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(isDE
                 ? "Du entscheidest, ob Movo Produktdaten zur Verbesserung der App senden darf."
                 : "You decide whether Movo may send product usage data to improve the app.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func privacyStatusRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(color.opacity(0.16)))
        }
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(t.palette.primary)
                .font(.system(size: 16, weight: .bold))
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
        }
    }
}

// MARK: - Legal View

struct LegalView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Link(destination: URL(string: "https://www.movobp.de/datenschutz.html")!) {
                HStack {
                    Text(appSettings.localized("settings.legal.privacy") ?? "Datenschutz")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://www.movobp.de/impressum.html")!) {
                HStack {
                    Text(appSettings.localized("settings.legal.imprint") ?? "Impressum")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://www.movobp.de/agb.html")!) {
                HStack {
                    Text(appSettings.localized("settings.legal.terms") ?? "AGB")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            
            NavigationLink(appSettings.localized("settings.legal.support") ?? "Support") {
                SimpleSupportView()
                    .environmentObject(appSettings)
            }
        }
        .navigationTitle(appSettings.localized("settings.legal") ?? "Rechtliches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(appSettings.localized("settings.done") ?? "Fertig") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Simple Support View (Email Only)

struct SimpleSupportView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    private let supportEmail = "movobp.contact@gmail.com"
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            VStack(spacing: 12) {
                Text(appSettings.localized("settings.support.title") ?? "Support kontaktieren")
                    .font(.title2.bold())
                
                Text(appSettings.localized("settings.support.subtitle") ?? "Schreib uns eine E-Mail und wir helfen dir gerne weiter.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                openSupportEmail()
            } label: {
                Label(appSettings.localized("settings.support.sendEmail") ?? "E-Mail senden", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            
            Text(supportEmail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
        .navigationTitle(appSettings.localized("settings.legal.support") ?? "Support")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func openSupportEmail() {
        let subject = "Movo Support"
        let body = """
        
        
        ---
        App Version: \(appVersion())
        iOS: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
