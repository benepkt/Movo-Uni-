import SwiftUI
import WidgetKit
import UIKit
import HealthKit
import UserNotifications

#if canImport(WebKit)
import WebKit
#endif

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var challengeStore: ChallengeStore
    @Environment(\.dismiss) private var dismiss

    let showsDoneButton: Bool
    init(showsDoneButton: Bool = false) { self.showsDoneButton = showsDoneButton }

    @State private var showLanguageSheet = false
    @State private var showUnitsSheet = false

    @State private var confirmLogout = false
    @State private var confirmDelete = false

    @State private var isDeletingAccount = false
    @State private var deleteErrorMessage: String?

    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                cloudSection
                appearanceSection
                integrationsSection
                generalSection
                aboutSection
                legalSection

                if authService.user != nil {
                    accountSection
                }
            }
            .padding(16)
        }
        .navigationTitle(appSettings.localized("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { doneToolbar }

        .sheet(isPresented: $showLanguageSheet) {
            LanguagePickerSheet(language: $appSettings.language,
                                title: appSettings.localized("settings.language"))
        }
        .sheet(isPresented: $showUnitsSheet) {
            UnitsPickerSheet(
                weightUnit: Binding(get: { weightUnit }, set: { weightUnit = $0 }),
                title: appSettings.localized("settings.units")
            )
        }

        .onAppear {
            syncLanguageAndUnitsToAppGroup()
            WidgetCenter.shared.reloadAllTimelines()
        }

        .onChange(of: appSettings.language) { newCode in
            let code = normalizeLang(newCode)
            UserDefaults.standard.set(code, forKey: "app.language")
            UserDefaults(suiteName: APP_GROUP_ID)?.set(code, forKey: "app.language")
            WidgetCenter.shared.reloadAllTimelines()
        }

        .onChange(of: weightUnit) { newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "units.weight")
            UserDefaults(suiteName: APP_GROUP_ID)?.set(newValue.rawValue, forKey: "units.weight")
            if #available(iOS 16.1, *) {
                LiveActivityManager.shared.refreshUnit(newValue)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }

        .alert(appSettings.localized("settings.logout"), isPresented: $confirmLogout) {
            Button(appSettings.localized("settings.logout"), role: .destructive) {
                authService.signOut()
            }
            Button(appSettings.localized("settings.done"), role: .cancel) { }
        } message: {
            Text(appSettings.localized("alert.logout.message"))
        }

        .alert(appSettings.localized("settings.account.delete"), isPresented: $confirmDelete) {
            Button(appSettings.localized("settings.account.delete.confirm"), role: .destructive) {
                deleteErrorMessage = nil
                isDeletingAccount = true
                authService.deleteAccountPermanently { result in
                    DispatchQueue.main.async {
                        isDeletingAccount = false
                        switch result {
                        case .success:
                            break
                        case .failure(let err):
                            deleteErrorMessage = err.localizedDescription
                        }
                    }
                }
            }
            Button(appSettings.localized("settings.done"), role: .cancel) { }
        } message: {
            Text(appSettings.localized("settings.account.delete.message"))
        }

        .alert(appSettings.localized("settings.account.delete.failed"),
               isPresented: Binding(get: { deleteErrorMessage != nil },
                                   set: { if !$0 { deleteErrorMessage = nil } })) {
            Button("OK", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }

        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView(appSettings.localized("settings.account.delete.progress"))
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var cloudSection: some View {
        sectionHeader(appSettings.localized("settings.cloudSync"))
        MovoCloudRow()
    }

    @ViewBuilder private var appearanceSection: some View {
        sectionHeader(appSettings.localized("settings.appearance"))
        SettingNavChip(
            title: appSettings.localized("settings.design.title"),
            subtitle: appSettings.localized("settings.design.subtitle"),
            systemImage: "paintbrush.pointed.fill"
        ) { DesignSettingsView() }
    }

    @ViewBuilder private var integrationsSection: some View {
        sectionHeader(appSettings.language.lowercased().hasPrefix("de") ? "Integrationen" : "Integrations")

        SettingNavChip(
            title: "Apple Health",
            subtitle: appSettings.language.lowercased().hasPrefix("de")
                ? "Neu verknüpfen & Berechtigungen"
                : "Relink & permissions",
            systemImage: "heart.text.square.fill"
        ) {
            AppleHealthSettingsView()
        }

        SettingNavChip(
            title: appSettings.localized("settings.notifications"),
            subtitle: notificationsSubtitle,
            systemImage: "bell.badge.fill"
        ) {
            NotificationsSettingsView()
        }
    }

    @ViewBuilder
    private var generalSection: some View {
        sectionHeader(appSettings.localized("settings.general"))

        let languageDisplay = appSettings.language.lowercased().hasPrefix("de") ? "Deutsch" : "English"

        SettingValueChip(
            title: appSettings.localized("settings.language"),
            value: languageDisplay,
            systemImage: "globe"
        ) { showLanguageSheet = true }

        SettingValueChip(
            title: appSettings.localized("settings.units"),
            value: weightUnit.localizedShort,
            systemImage: "scalemass"
        ) { showUnitsSheet = true }
    }


    @ViewBuilder private var aboutSection: some View {
        sectionHeader(appSettings.localized("settings.about"))

        SettingValueChip(
            title: appSettings.localized("settings.version"),
            value: Bundle.main.appVersionDisplay,
            systemImage: "info.circle"
        ) { }

        SettingNavChip(
            title: appSettings.localized("settings.aboutApp.title"),
            subtitle: appSettings.localized("settings.aboutApp.subtitle"),
            systemImage: "sparkles"
        ) { AboutAppView() }

        SettingNavChip(
            title: appSettings.localized("settings.support.title"),
            subtitle: appSettings.localized("settings.support.subtitle"),
            systemImage: "envelope"
        ) { SupportView() }
    }

    @ViewBuilder private var legalSection: some View {
        sectionHeader(appSettings.localized("settings.legal"))

        SettingLinkChip(
            title: appSettings.localized("settings.legal.imprint.title"),
            subtitle: appSettings.localized("settings.legal.imprint.subtitle"),
            systemImage: "doc.text.magnifyingglass",
            urlString: "https://www.movobp.de/impressum.html"
        )

        SettingLinkChip(
            title: "AGB",
            subtitle: appSettings.localized("settings.legal.imprint.subtitle"),
            systemImage: "doc.text",
            urlString: "https://www.movobp.de/agb.html"
        )

        SettingLinkChip(
            title: appSettings.localized("settings.legal.privacy.title"),
            subtitle: appSettings.localized("settings.legal.privacy.subtitle"),
            systemImage: "hand.raised.fill",
            urlString: "https://www.movobp.de/datenschutz.html"
        )

        SettingNavChip(
            title: appSettings.localized("settings.legal.consent.title"),
            subtitle: appSettings.localized("settings.legal.consent.subtitle"),
            systemImage: "switch.2"
        ) { ConsentCenterView() }
    }

    @ViewBuilder private var accountSection: some View {
        sectionHeader(appSettings.localized("settings.account"))

        SettingActionChip(
            title: appSettings.localized("settings.logout"),
            systemImage: "rectangle.portrait.and.arrow.right",
            role: .destructive
        ) { confirmLogout = true }

        SettingActionChip(
            title: appSettings.localized("settings.account.delete"),
            systemImage: "trash",
            role: .destructive
        ) { confirmDelete = true }
    }

    // MARK: - Small helpers

    private var notificationsSubtitle: String {
        let isDE = appSettings.language.lowercased().hasPrefix("de")
        return appSettings.notificationsEnabled
            ? (isDE ? "Aktiviert" : "Enabled")
            : (isDE ? "Deaktiviert" : "Disabled")
    }

    @ToolbarContentBuilder private var doneToolbar: some ToolbarContent {
        if showsDoneButton {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(appSettings.localized("settings.done")) { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 2)
    }
}

// MARK: - Helpers für App-Group-Sync
private func normalizeLang(_ s: String) -> String {
    s.lowercased().hasPrefix("de") ? "de" : "en"
}

private func syncLanguageAndUnitsToAppGroup() {
    // Sprache
    let code = normalizeLang(UserDefaults.standard.string(forKey: "app.language") ?? "de")
    UserDefaults.standard.set(code, forKey: "app.language")
    UserDefaults(suiteName: APP_GROUP_ID)?.set(code, forKey: "app.language")
    // Einheiten
    let unitRaw = UserDefaults.standard.string(forKey: "units.weight") ?? "kg"
    UserDefaults(suiteName: APP_GROUP_ID)?.set(unitRaw, forKey: "units.weight")
}



private struct SettingLinkChip: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let urlString: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: urlString) {
                openURL(url)
            }
        } label: {
            ChipBase {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.body)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
// MARK: - Movo Cloud (Detailseite)
struct MovoCloudView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService

    let robotImageName: String
    private var isGuest: Bool { authService.isGuest || authService.user == nil }

    // Relativ-Formatter nutzt App-Sprache ("de"/"en")
    private var relFmt: RelativeDateTimeFormatter {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: normalizeLang(appSettings.language))
        return f
    }

    private var lastSyncRelative: String {
        guard let d = syncService.lastSyncAt, !isGuest else { return "—" }
        return relFmt.localizedString(for: d, relativeTo: Date())
    }

    private var statusTitle: String {
        if isGuest { return appSettings.localized("cloud.status.guest") }
        if syncService.isSyncing { return appSettings.localized("cloud.status.syncing") }
        return appSettings.localized("cloud.status.ready")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                CloudHeroCard(
                    title: appSettings.localized("cloud.title"),
                    subtitle: appSettings.localized("cloud.subtitle"),
                    robotImageName: "fitness_robot_blue"
                )

                SyncStatusCard(
                    title: statusTitle,
                    rightTime: isGuest ? "" : lastSyncRelative,
                    isSyncing: syncService.isSyncing,
                    isGuest: isGuest
                )

                PrimarySyncButton(
                    disabled: isGuest || syncService.isSyncing,
                    title: appSettings.localized("cloud.syncNow")
                ) {
                    Task { await syncService.uiPushAll() }
                }
                .padding(.horizontal, 6)

                Text(appSettings.localized("cloud.explainer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .navigationTitle(appSettings.localized("cloud.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}





private struct BetaBadgeBlue: View {
    var body: some View {
        Text("BETA")
            .font(.caption2.weight(.heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.accentColor) // blau
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .baselineOffset(2)
    }
}

// Blaues BETA-Badge
struct BetaTag: View {
    var body: some View {
        Text("BETA")
            .font(.caption2.bold())
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .foregroundStyle(.white)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
private struct SyncStatusCard: View {
    let title: String
    let rightTime: String
    let isSyncing: Bool
    let isGuest: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)         // kleiner
                if isSyncing {
                    ProgressView()
                } else {
                    Image(systemName: isGuest ? "icloud.slash" : "icloud")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            Text(title)                                   // „Bereit zum Synchronisieren“
                .font(.subheadline.weight(.semibold))     // etwas kleiner
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            if !isGuest && !rightTime.isEmpty {
                Text(rightTime)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }
}


struct MovoCloudRow: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService

    var body: some View {
        NavigationLink {
            MovoCloudView(robotImageName: "movo_robot")
        } label: {
            ChipBase {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.fill")
                        .font(.body)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(appSettings.localized("cloud.title")).font(.subheadline)
                            BetaTag()
                        }
                        Text(appSettings.localized("cloud.row.subtitle"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName:
                          syncService.isSyncing
                          ? "arrow.triangle.2.circlepath"
                          : (authService.isGuest || authService.user == nil
                             ? "icloud.slash" : "icloud"))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero-Karte (mit Roboter)
struct CloudHeroCard: View {
    let title: String
    let subtitle: String
    let robotImageName: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // Roboter LINKS
            Image(uiImage: UIImage(named: robotImageName) ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .accessibilityHidden(true)

            // Titel + BETA + Untertitel RECHTS
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.title2.bold())
                    BetaBadgeBlue()                   // blaues BETA-Tag
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08),
                         Color.accentColor.opacity(0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .background(.thinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Status-Pill (Structured-Style)
private struct SyncStatusPill: View {
    let title: String
    let trailing: String?
    let isSyncing: Bool
    let isGuest: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                if isSyncing {
                    ProgressView().controlSize(.regular)
                } else {
                    Image(systemName: isGuest ? "icloud.slash" : "cloud.fill") // sicheres Symbol
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if let t = trailing, !t.isEmpty {
                Text(t)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    }
}

// MARK: - Primärer Sync-Button (schlanker)
private struct PrimarySyncButton: View {
    var disabled: Bool
    var title: String
    var action: () -> Void
    private let syncSymbol = "arrow.clockwise"

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: syncSymbol)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .clipShape(Capsule())
        .disabled(disabled)
    }
}



// MARK: - Chips & Picker
private struct ChipBase<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct SettingValueChip: View {
    let title: String
    let value: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ChipBase {
                HStack(spacing: 12) {
                    Image(systemName: systemImage).font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline)
                        Text(value).font(.footnote).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct SettingToggleChip: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        ChipBase {
            HStack(spacing: 12) {
                Image(systemName: systemImage).font(.body)
                Text(title).font(.subheadline)
                Spacer()
                Toggle("", isOn: $isOn).labelsHidden()
            }
        }
        .accessibilityLabel(title)
    }
}

private struct SettingActionChip: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            ChipBase {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.body)
                        .foregroundColor(role == .destructive ? .red : .primary)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(role == .destructive ? .red : .primary)
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Apple Health Settings

private struct AppleHealthSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var healthKit = HealthKitManager()

    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var isWorking = false

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    // gleiche Read-Types wie in deinem Onboarding requestPermissions() :contentReference[oaicite:1]{index=1}
    private var onboardingReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.workoutType()
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L(
                    "Hier kannst du Apple Health und (falls nötig) Benachrichtigungen erneut verknüpfen – genau wie im Onboarding.",
                    "Here you can relink Apple Health and (if needed) notifications — just like in onboarding."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                SettingActionChip(
                    title: L("Alles neu verknüpfen", "Relink everything"),
                    systemImage: "link.circle.fill"
                ) {
                    Task { await relinkAll() }
                }
                .disabled(isWorking)

                SettingActionChip(
                    title: L("Health-App öffnen", "Open Health app"),
                    systemImage: "heart.fill"
                ) {
                    openHealthApp()
                }

                SettingActionChip(
                    title: L("App-Einstellungen öffnen", "Open App settings"),
                    systemImage: "gearshape.fill"
                ) {
                    openAppSettings()
                }

                if notifStatus == .denied {
                    Text(L(
                        "Hinweis: Benachrichtigungen sind in iOS aktuell deaktiviert. Bitte in den App-Einstellungen aktivieren.",
                        "Note: Notifications are currently disabled in iOS. Please enable them in App Settings."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                }
            }
            .padding(16)
        }
        .background(bgGradient)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshNotifStatus() }
    }

    private func relinkAll() async {
        isWorking = true
        defer { isWorking = false }

        // Notifications neu anfragen (über deinen NotificationManager1) :contentReference[oaicite:2]{index=2}
        await NotificationManager1.shared.requestAuthorization()
        await refreshNotifStatus()

        // HealthKit neu anfragen (wie Onboarding) :contentReference[oaicite:3]{index=3}
        await healthKit.requestReadAuthorizationIfNeeded(
            readTypes: onboardingReadTypes,
            forcePrompt: true
        )
    }

    private func refreshNotifStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notifStatus = settings.authorizationStatus }
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func openHealthApp() {
        #if canImport(UIKit)
        guard let url = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Notifications Settings
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Notifications Settings

private struct NotificationsSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings

    // MARK: Scheduled reminders (mit Uhrzeit)
    @AppStorage("notif.training.enabled") private var trainingEnabled: Bool = true
    @AppStorage("notif.training.hour") private var trainingHour: Int = 18
    @AppStorage("notif.training.minute") private var trainingMinute: Int = 0

    @AppStorage("notif.morning.enabled") private var morningEnabled: Bool = true
    @AppStorage("notif.morning.hour") private var morningHour: Int = 8
    @AppStorage("notif.morning.minute") private var morningMinute: Int = 0

    @AppStorage("notif.water.enabled") private var waterEnabled: Bool = false
    @AppStorage("notif.water.hour") private var waterHour: Int = 12
    @AppStorage("notif.water.minute") private var waterMinute: Int = 0
    @AppStorage("notif.water.identifier") private var waterIdentifier: String = ""

    // MARK: “Mehr” Notifications (ohne Uhrzeit – werden aus App-Logik getriggert)
    @AppStorage("notif.postWorkoutHydration.enabled") private var postWorkoutHydrationEnabled: Bool = true
    @AppStorage("notif.workoutSummary.enabled") private var workoutSummaryEnabled: Bool = true

    @AppStorage("notif.weightMilestones.enabled") private var weightMilestonesEnabled: Bool = true
    @AppStorage("notif.streakMilestones.enabled") private var streakMilestonesEnabled: Bool = true
    @AppStorage("notif.personalRecord.enabled") private var personalRecordEnabled: Bool = true

    @AppStorage("notif.challengeProgress.enabled") private var challengeProgressEnabled: Bool = true
    @AppStorage("notif.restDay.enabled") private var restDayEnabled: Bool = true
    @AppStorage("notif.comeback.enabled") private var comebackEnabled: Bool = true
    @AppStorage("notif.weeklySummary.enabled") private var weeklySummaryEnabled: Bool = true

    // MARK: UI state
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var showTrainingTime = false
    @State private var showMorningTime = false
    @State private var showWaterTime = false

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }

    // ✅ stabil (kein $appSettings.dynamicMember)
    private var masterBinding: Binding<Bool> {
        Binding(
            get: { appSettings.notificationsEnabled },
            set: { newValue in
                appSettings.notificationsEnabled = newValue
                NotificationManager1.shared.setMasterEnabled(newValue) // ✅ Master AUS => cancelAllNotifications()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                sectionTitle(L("Benachrichtigungen", "Notifications"))

                SettingToggleChip(
                    title: L("Benachrichtigungen aktivieren", "Enable notifications"),
                    systemImage: "bell.fill",
                    isOn: masterBinding
                )
                .onChange(of: appSettings.notificationsEnabled) { _, _ in
                    Task { await handleMasterChanged() }
                }

                permissionArea

                // MARK: - Erinnerungen (scheduled)
                sectionTitle(L("Erinnerungen", "Reminders"))

                SettingToggleChip(
                    title: L("Trainingserinnerung", "Training reminder"),
                    systemImage: "figure.strengthtraining.traditional",
                    isOn: $trainingEnabled
                )
                .disabled(!appSettings.notificationsEnabled)
                .onChange(of: trainingEnabled) { _, _ in applySchedules() }

                SettingValueChip(
                    title: L("Uhrzeit", "Time"),
                    value: timeString(trainingHour, trainingMinute),
                    systemImage: "clock"
                ) { showTrainingTime = true }
                .disabled(!(appSettings.notificationsEnabled && trainingEnabled))
                .opacity((appSettings.notificationsEnabled && trainingEnabled) ? 1 : 0.5)

                SettingToggleChip(
                    title: L("Morgen-Motivation", "Morning motivation"),
                    systemImage: "sunrise.fill",
                    isOn: $morningEnabled
                )
                .disabled(!appSettings.notificationsEnabled)
                .onChange(of: morningEnabled) { _, _ in applySchedules() }

                SettingValueChip(
                    title: L("Uhrzeit", "Time"),
                    value: timeString(morningHour, morningMinute),
                    systemImage: "clock"
                ) { showMorningTime = true }
                .disabled(!(appSettings.notificationsEnabled && morningEnabled))
                .opacity((appSettings.notificationsEnabled && morningEnabled) ? 1 : 0.5)

                sectionTitle(L("Hydration", "Hydration"))

                SettingToggleChip(
                    title: L("Trink-Erinnerung", "Water reminder"),
                    systemImage: "drop.fill",
                    isOn: $waterEnabled
                )
                .disabled(!appSettings.notificationsEnabled)
                .onChange(of: waterEnabled) { _, _ in applySchedules() }

                SettingValueChip(
                    title: L("Uhrzeit", "Time"),
                    value: timeString(waterHour, waterMinute),
                    systemImage: "clock"
                ) { showWaterTime = true }
                .disabled(!(appSettings.notificationsEnabled && waterEnabled))
                .opacity((appSettings.notificationsEnabled && waterEnabled) ? 1 : 0.5)

                // MARK: - Aktivität
                sectionTitle(L("Aktivität", "Activity"))

                SettingToggleChip(
                    title: L("Workout-Zusammenfassung", "Workout summary"),
                    systemImage: "figure.run",
                    isOn: $workoutSummaryEnabled
                )
                .disabled(!appSettings.notificationsEnabled)

                SettingToggleChip(
                    title: L("Nach dem Workout: Trinken", "Post-workout hydration"),
                    systemImage: "drop.triangle.fill",
                    isOn: $postWorkoutHydrationEnabled
                )
                .disabled(!appSettings.notificationsEnabled)

                // MARK: - Erfolge
                sectionTitle(L("Erfolge", "Milestones"))

                SettingToggleChip(
                    title: L("Gewicht-Updates & Meilensteine", "Weight updates & milestones"),
                    systemImage: "scalemass",
                    isOn: $weightMilestonesEnabled
                )
                .disabled(!appSettings.notificationsEnabled)

                SettingToggleChip(
                    title: L("Streak-Meilensteine", "Streak milestones"),
                    systemImage: "flame.fill",
                    isOn: $streakMilestonesEnabled
                )
                .disabled(!appSettings.notificationsEnabled)

                SettingToggleChip(
                    title: L("Persönliche Rekorde", "Personal records"),
                    systemImage: "trophy.fill",
                    isOn: $personalRecordEnabled
                )
                .disabled(!appSettings.notificationsEnabled)

                // MARK: - Fortschritt / Reaktivierung
                sectionTitle(L("Fortschritt", "Progress"))

                SettingToggleChip(
                    title: L("Challenge-Fortschritt", "Challenge progress"),
                    systemImage: "target",
                    isOn: $challengeProgressEnabled
                )
                .disabled(!appSettings.notificationsEnabled)

                SettingToggleChip(
                    title: L("Restday-Reminder", "Rest day reminder"),
                    systemImage: "bed.double.fill",
                    isOn: $restDayEnabled
                )
                .disabled(!appSettings.notificationsEnabled)

                SettingToggleChip(
                    title: L("Comeback-Reminder", "Comeback reminder"),
                    systemImage: "arrow.uturn.left.circle.fill",
                    isOn: $comebackEnabled
                )
                .disabled(!appSettings.notificationsEnabled)

                SettingToggleChip(
                    title: L("Wöchentliche Zusammenfassung", "Weekly summary"),
                    systemImage: "calendar",
                    isOn: $weeklySummaryEnabled
                )
                .disabled(!appSettings.notificationsEnabled)
            }
            .padding(16)
        }
        .navigationTitle(L("Benachrichtigungen", "Notifications"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // ✅ sorgt dafür, dass Master wirklich wirkt
            NotificationManager1.shared.setMasterEnabled(appSettings.notificationsEnabled)
            await refreshNotifStatus()
            applySchedules()
        }
        .sheet(isPresented: $showTrainingTime) {
            TimePickerSheet(
                title: L("Training", "Training"),
                hour: $trainingHour,
                minute: $trainingMinute,
                doneTitle: L("Fertig", "Done")
            ) { applySchedules() }
        }
        .sheet(isPresented: $showMorningTime) {
            TimePickerSheet(
                title: L("Morgen", "Morning"),
                hour: $morningHour,
                minute: $morningMinute,
                doneTitle: L("Fertig", "Done")
            ) { applySchedules() }
        }
        .sheet(isPresented: $showWaterTime) {
            TimePickerSheet(
                title: L("Trinken", "Hydration"),
                hour: $waterHour,
                minute: $waterMinute,
                doneTitle: L("Fertig", "Done")
            ) { applySchedules() }
        }
    }

    // MARK: - Permission UI

    @ViewBuilder
    private var permissionArea: some View {
        if appSettings.notificationsEnabled {
            if notifStatus == .notDetermined {
                SettingActionChip(
                    title: L("Berechtigung anfragen", "Request permission"),
                    systemImage: "hand.raised.fill"
                ) {
                    Task {
                        await NotificationManager1.shared.requestAuthorization()
                        await refreshNotifStatus()
                        applySchedules()
                    }
                }
            } else if notifStatus == .denied {
                SettingActionChip(
                    title: L("In Einstellungen aktivieren", "Enable in Settings"),
                    systemImage: "gearshape.fill"
                ) { openAppSettings() }
            }
        }
    }

    // MARK: - Logic

    private func handleMasterChanged() async {
        await refreshNotifStatus()

        if appSettings.notificationsEnabled {
            if notifStatus == .notDetermined {
                await NotificationManager1.shared.requestAuthorization()
                await refreshNotifStatus()
            }
            applySchedules()
        } else {
            // ✅ Master AUS -> wirklich alles weg
            NotificationManager1.shared.cancelAllNotifications()
        }
    }

    private func applySchedules() {
        guard appSettings.notificationsEnabled else {
            NotificationManager1.shared.cancelAllNotifications()
            return
        }
        guard notifStatus != .denied else { return }

        // Training (fixe ID im Manager)
        if trainingEnabled {
            NotificationManager1.shared.scheduleDailyTrainingReminder(hour: trainingHour, minute: trainingMinute)
        } else {
            NotificationManager1.shared.cancelNotification(withIdentifier: "movo.dailyTrainingReminder")
        }

        // Morning Motivation (fixe ID im Manager)
        if morningEnabled {
            NotificationManager1.shared.scheduleMorningMotivation(hour: morningHour, minute: morningMinute)
        } else {
            NotificationManager1.shared.cancelNotification(withIdentifier: "movo.morningMotivation")
        }

        // General Water (ID enthält hour/minute)
        let newWaterId = "movo.generalWater.\(waterHour).\(waterMinute)"

        if waterEnabled {
            if !waterIdentifier.isEmpty, waterIdentifier != newWaterId {
                NotificationManager1.shared.cancelNotification(withIdentifier: waterIdentifier)
            }
            waterIdentifier = newWaterId
            NotificationManager1.shared.scheduleGeneralWaterReminder(hour: waterHour, minute: waterMinute)
        } else {
            if !waterIdentifier.isEmpty {
                NotificationManager1.shared.cancelNotification(withIdentifier: waterIdentifier)
            }
            waterIdentifier = ""
        }
    }

    private func refreshNotifStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notifStatus = settings.authorizationStatus }
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func timeString(_ h: Int, _ m: Int) -> String {
        let hh = h < 10 ? "0\(h)" : "\(h)"
        let mm = m < 10 ? "0\(m)" : "\(m)"
        return "\(hh):\(mm)"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}


// MARK: - Time Picker Sheet (Wheel)

private struct TimePickerSheet: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int
    let doneTitle: String
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "",
                    selection: dateBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneTitle) {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let cal = Calendar.current
                let base = Date()
                return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour = c.hour ?? hour
                minute = c.minute ?? minute
            }
        )
    }
}

private struct SettingNavChip<Destination: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    private let destination: Destination

    init(title: String, subtitle: String? = nil, systemImage: String,
         @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            ChipBase {
                HStack(spacing: 12) {
                    Image(systemName: systemImage).font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline)
                        if let subtitle {
                            Text(subtitle).font(.footnote).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct LanguagePickerSheet: View {
    @Binding var language: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Picker(title, selection: $language) {
                    Text("Deutsch").tag("de")
                    Text("English").tag("en")
                }
                .pickerStyle(.inline)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("common.ok")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct UnitsPickerSheet: View {
    @Binding var weightUnit: WeightUnit
    let title: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Picker(appSettings.localized("common.weight"), selection: $weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.localizedLong).tag(unit)
                    }
                }
                .pickerStyle(.inline)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("common.ok")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Imprint + AGB
struct ImprintAGBView: View {
    @EnvironmentObject var appSettings: AppSettings
    enum Tab: String, CaseIterable, Identifiable {
        case impressum = "Impressum"
        case agb       = "AGB"
        var id: String { rawValue }
    }
    @State private var tab: Tab = .impressum

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: appSettings.localized("imprint.header.title"),
                       subtitle: appSettings.localized("imprint.header.subtitle"))

                Picker("", selection: $tab) {
                    Text(appSettings.localized("imprint.tab.impressum")).tag(Tab.impressum)
                    Text(appSettings.localized("imprint.tab.agb")).tag(Tab.agb)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                
              
                
                
                LegalCard {
                    switch tab {
                    case .impressum:
                        LegalMarkdownView(
                            title: appSettings.localized("imprint.tab.impressum"),
                            bundleBaseName: "impressum",
                            fallbackDE: LegalFallback.impressumFull_de,
                            fallbackEN: LegalFallback.impressumFull_en
                        )
                    case .agb:
                        LegalMarkdownView(
                            title: appSettings.localized("imprint.tab.agb"),
                            bundleBaseName: "agb",
                            fallbackDE: LegalFallback.agb_de,
                            fallbackEN: LegalFallback.agb_en
                        )
                    }
                }

                LegalCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(appSettings.localized("imprint.contact"), systemImage: "envelope").font(.headline)
                        // FIX: proper mailto:
                        Link("movobp.contact@gmail.com",
                             destination: URL(string: "mailto:movobp.contact@gmail.com")!)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
            }
            .padding(.top, 16)
        }
        .background(bgGradient)
        .navigationTitle(appSettings.localized("imprint.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Datenschutz
struct PrivacyPolicyView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var htmlHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: appSettings.localized("privacy.header.title"),
                       subtitle: appSettings.localized("privacy.header.subtitle"))

                // Datenschutz-Erklärung (HTML in beiden Sprachen)
                LegalCard {
                    let lang = normalizeLang(appSettings.language)
                    LegalHTMLView(
                        html: (lang == "de" ? LegalFallback.privacy_de_html
                                            : LegalFallback.privacy_en_html),
                        height: $htmlHeight
                    )
                    .frame(height: htmlHeight)
                    .id("privacy_\(lang)_html")
                }

                // Quick-Links
                LegalCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(appSettings.localized("privacy.quick"), systemImage: "link")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            NavigationLink(destination: ConsentCenterView()) {
                                Label(appSettings.localized("privacy.manageConsents"),
                                      systemImage: "hand.raised")
                            }
                            Link(
                                destination: URL(string:
                                    "mailto:movobp.contact@gmail.com?subject=movo%20Support&body=Hallo%20Benedikt%2C%0A"
                                )!
                            ) {
                                Label(appSettings.localized("privacy.contact"),
                                      systemImage: "envelope")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)
            }
            .padding(.top, 16)
        }
        .background(bgGradient)
        .navigationTitle(appSettings.localized("privacy.header.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}



// MARK: - Consent Center
final class ConsentStore: ObservableObject {
    @AppStorage("consent.analytics") var analytics = false
    @AppStorage("consent.ads")       var ads = false
    @AppStorage("consent.crash")     var crash = true
    @AppStorage("consent.personal")  var personalization = false
    @AppStorage("consent.timestamp") var timestamp: Double = 0

    func acceptAll() {
        analytics = true; ads = true; crash = true; personalization = true
        timestamp = Date().timeIntervalSince1970
        objectWillChange.send()
    }
    func denyAll() {
        analytics = false; ads = false; crash = false; personalization = false
        timestamp = Date().timeIntervalSince1970
        objectWillChange.send()
    }
}

struct ConsentCenterView: View {
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var store = ConsentStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: appSettings.localized("consent.title"),
                       subtitle: appSettings.localized("consent.subtitle"))

                LegalCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(appSettings.localized("privacy.quick"), systemImage: "info.circle").font(.headline)
                        Text(appSettings.localized("consent.notice"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                LegalCard {
                    VStack(alignment: .leading, spacing: 14) {
                        ToggleRow(title: appSettings.localized("consent.analytics.title"),
                                  subtitle: appSettings.localized("consent.analytics.subtitle"),
                                  isOn: $store.analytics)
                        ToggleRow(title: appSettings.localized("consent.ads.title"),
                                  subtitle: appSettings.localized("consent.ads.subtitle"),
                                  isOn: $store.ads)
                        ToggleRow(title: appSettings.localized("consent.crash.title"),
                                  subtitle: appSettings.localized("consent.crash.subtitle"),
                                  isOn: $store.crash)
                        ToggleRow(title: appSettings.localized("consent.personal.title"),
                                  subtitle: appSettings.localized("consent.personal.subtitle"),
                                  isOn: $store.personalization)
                    }
                }

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        store.denyAll()
                    } label: {
                        Label(appSettings.localized("consent.rejectAll"), systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.acceptAll()
                    } label: {
                        Label(appSettings.localized("consent.acceptAll"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                if store.timestamp > 0 {
                    Text(String(format: appSettings.localized("consent.lastUpdated"),
                                Date(timeIntervalSince1970: store.timestamp)
                                    .formatted(date: .abbreviated, time: .shortened)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)
            }
            .padding(.top, 16)
        }
        .background(bgGradient)
        .navigationTitle(appSettings.localized("consent.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bausteine / Styles
private var bgGradient: some View {
    LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                   startPoint: .top, endPoint: .bottom)
}

@ViewBuilder private func header(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.largeTitle.bold())
        Text(subtitle).font(.callout).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal)
}

private struct LegalCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            .padding(.horizontal)
    }
}

// MARK: - HTML Renderer (WKWebView) für Rechtstexte
#if canImport(WebKit)
private struct LegalHTMLView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat
    var baseURL: URL? = nil

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.backgroundColor = .clear
        wv.loadHTMLString(wrapHTML(html), baseURL: baseURL)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Neu laden nur, wenn sich der Inhalt verändert hat
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            uiView.loadHTMLString(wrapHTML(html), baseURL: baseURL)
        } else {
            // Höhe neu bestimmen (z. B. bei Rotation/Dark Mode)
            evaluateHeight(webView: uiView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LegalHTMLView
        var lastHTML: String = ""
        init(parent: LegalHTMLView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.evaluateHeight(webView: webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }

    private func evaluateHeight(webView: WKWebView) {
        webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
            if let h = result as? CGFloat, h > 0 {
                DispatchQueue.main.async {
                    self.height = h
                }
            }
        }
    }

    /// Systemnahes Stylesheet inkl. Dark Mode
    private func wrapHTML(_ bodyHTML: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <style>
            :root { color-scheme: light dark; -webkit-text-size-adjust: 100%; }
            body {
              margin: 0; padding: 0;
              background: transparent;
              color: rgb(28,28,30);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              line-height: 1.45;
              font-size: 16px;
            }
            @media (prefers-color-scheme: dark) {
              body { color: rgb(242,242,247); }
              a { color: #7dbcff; }
            }
            .container { padding: 2px 2px; }
            h1 { font-size: 28px; margin: 0 0 12px; }
            h2 { font-size: 22px; margin: 22px 0 10px; }
            h3 { font-size: 18px; margin: 18px 0 8px; }
            p, li { line-height: 1.45; font-size: 16px; }
            ul, ol { padding-left: 1.2em; }
            a { color: #007aff; text-decoration: none; }
            a:hover { text-decoration: underline; }
            .index { list-style: none; padding-left: 0; }
            .index-link { text-decoration: none; }
            .seal { margin-top: 20px; font-size: 14px; opacity: 0.8; }
          </style>
        </head>
        <body>
          <div class="container">
            \(bodyHTML)
          </div>
        </body>
        </html>
        """
    }
}
#endif

// REPLACE THIS VIEW in SettingsView.swift

private struct LegalMarkdownView: View {
    @EnvironmentObject var appSettings: AppSettings
    let title: String
    let bundleBaseName: String
    let fallbackDE: String
    let fallbackEN: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.bold())
            // IM VIEW LegalMarkdownView – erzwinge Fallback, ignoriere Bundle:
            if true {
                // Fallback immer verwenden
                Text(selectedFallback)
                    .font(.body)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let attr = loadLocalizedMarkdown(base: bundleBaseName) {
                Text(attr)
                    .font(.body)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedFallback: String {
        normalizeLang(appSettings.language) == "de" ? fallbackDE : fallbackEN
    }

    // NEW: Markdown „schön machen“, damit Absätze wirklich getrennt sind
    private func prettify(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "\r\n", with: "\n")
                 .replacingOccurrences(of: "\r", with: "\n")

        // Vor Überschriften/Blocktiteln eine Leerzeile erzwingen
        let blockStarts = [
            "\n**Kontakt**", "\n**Hinweis", "\n**Haftung", "\n**Availability",
            "\n**Liability", "\n**Note on", "\n**Provider", "\n**Anbieter",
            "\n# " // falls weitere H1/H2 im Text auftauchen
        ]
        for key in blockStarts {
            t = t.replacingOccurrences(of: key, with: "\n\n" + key.dropFirst())
        }

        // Nach Adressblöcken/Zeilen mit E-Mail zusätzlichen Absatz
        t = t.replacingOccurrences(of: "Deutschland\n", with: "Deutschland\n\n")
        t = t.replacingOccurrences(of: "Germany\n", with: "Germany\n\n")
        t = t.replacingOccurrences(of: "\nE-Mail:", with: "\n\nE-Mail:")
        t = t.replacingOccurrences(of: "\nEmail:", with: "\n\nEmail:")

        // Horizontal rules (---) entfernen, falls noch vorhanden
        t = t.replacingOccurrences(of: "\n---\n", with: "\n\n")

        return t
    }

    private func loadLocalizedMarkdown(base: String) -> AttributedString? {
        let lang = normalizeLang(appSettings.language)
        let candidates = ["\(base)_\(lang)", "\(base)-\(lang)", "\(base).\(lang)", base]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "md"),
               let raw = try? String(contentsOf: url, encoding: .utf8) {
                let md = prettify(raw)
                if let attr = try? AttributedString(
                    markdown: md,
                    options: .init(interpretedSyntax: .full)
                ) { return attr }
            }
        }
        let fb = prettify(selectedFallback)
        return try? AttributedString(markdown: fb, options: .init(interpretedSyntax: .full))
    }
}


private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Fallback Inhalte (KEINE horizontalen Linien, nur Absätze)
private enum LegalFallback {
    // MARK: - IMPRESSUM / IMPRINT
    static let impressumFull_de: String = """
Impressum (Anbieterkennzeichnung)

Anbieter / Verantwortlicher gemäß § 5 TMG und § 18 MStV
Benedikt Purkott
c/o Block Services
Stuttgarter Str. 106
70736 Fellbach
Deutschland


Kontakt
E-Mail: movobp.contact@gmail.com

Für telefonische Anfragen nutzen Sie bitte das Kontaktformular in der App
oder schreiben Sie uns eine E-Mail an: movobp.contact@gmail.com

Hinweis zur Erreichbarkeit
Dieses Impressum ist in der App jederzeit über Einstellungen → „Impressum & AGB“ abrufbar.

Haftung für Inhalte
Die Inhalte dieser App wurden mit größter Sorgfalt erstellt.
Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte kann jedoch keine Gewähr übernommen werden.

Haftung für Links
Diese App kann Links zu externen Webseiten Dritter enthalten,
auf deren Inhalte wir keinen Einfluss haben.
Für die Inhalte der verlinkten Seiten ist stets der jeweilige Anbieter oder Betreiber der Seiten verantwortlich.

Hinweis zu KI-Inhalten
Einige Texte, Beschreibungen und Hinweise in dieser App wurden mit Unterstützung künstlicher Intelligenz (KI) erstellt oder überarbeitet (z. B. mittels ChatGPT).
Alle Inhalte wurden vor Veröffentlichung manuell geprüft und redaktionell angepasst.

Stand: Oktober 2025
"""

    static let impressumFull_en: String = """
Imprint (Legal Notice)

Provider / Responsible Person according to § 5 TMG and § 18 MStV
Benedikt Purkott
c/o Block Services
Stuttgarter Str. 106
70736 Fellbach
Deutschland


Contact
Email: movobp.contact@gmail.com

For telephone inquiries, please use the contact form in the app
or send an email to: movobp.contact@gmail.com

Availability
This legal notice is available in the app at any time under Settings → “Imprint & Terms”.

Liability for Content
The content of this app was created with great care.
However, we cannot guarantee the accuracy, completeness, or timeliness of the information provided.

Liability for Links
This app may contain links to external websites of third parties, over whose content we have no control.
The respective provider or operator of those sites is always responsible for their content.

Note on AI-Generated Content
Some texts, descriptions and information in this app were created or refined with the assistance of artificial intelligence (for example, ChatGPT).
All content has been manually reviewed and edited before publication.

Last updated: October 2025
"""

    // MARK: - AGB / TERMS
    static let agb_de: String = """
    Allgemeine Geschäftsbedingungen (AGB) – movo
    Stand: 25.10.2025

    1. Anbieter, Geltungsbereich
    Diese AGB regeln die weltweite Nutzung der App „movo“ und der zugehörigen Dienste zwischen dem Anbieter („wir“) und dir als Nutzer:in („du“). Abweichende Bedingungen gelten nicht, es sei denn, wir stimmen ihnen ausdrücklich zu.
    
    2. Leistungen, Lizenz, technische Voraussetzungen
    2.1 Die App bietet u. a. Trainingspläne, Challenges, Auswertungen, Schritte-/Aktivitätsdaten, Benachrichtigungen, Community- und Gamification-Funktionen. Funktionen können sich ändern oder erweitert werden.
    2.2 Wir gewähren dir eine persönliche, widerrufliche, nicht exklusive und nicht übertragbare Lizenz zur Nutzung der App gemäß diesen AGB.
    2.3 Für die Nutzung sind ein kompatibles Endgerät und Internetzugang erforderlich; daraus entstehende Kosten trägst du selbst. Es können Drittanbieter-Konten (z. B. Apple, Google) nötig sein.

    3. Registrierung, Alter, Konto
    3.1 Für bestimmte Funktionen ist ein Konto erforderlich. Anmeldung via E-Mail/Passwort sowie „Mit Apple/Google anmelden“ ist möglich. Du machst wahrheitsgemäße Angaben und hältst sie aktuell.
    3.2 Du bist mindestens 16 Jahre alt. Jüngere Personen dürfen die App nur mit Einwilligung der Erziehungsberechtigten nutzen.
    3.3 Zugangsdaten sind geheim zu halten. Du informierst uns unverzüglich über eine unbefugte Nutzung. Wir dürfen Konten bei begründetem Verdacht vorübergehend sperren.

    4. Gesundheitshinweise (keine Medizinprodukte-/Arzt-Leistungen)
    Die Nutzung erfolgt auf eigenes Risiko. Konsultiere vor Trainingsbeginn eine Ärztin/einen Arzt, insbesondere bei Vorerkrankungen. Die App bietet keine medizinische Beratung, Diagnose oder Therapie und ist kein Ersatz für ärztliche Behandlung. In Notfällen wähle die örtliche Notrufnummer.

    5. Entgelte, In-App-Käufe und Abonnements (inkl. „Lifetime“, Testphase, Beta)
    5.1 Beta-Zugang: Während einer Beta-Phase können einzelne oder alle Pro-Funktionen kostenfrei freigeschaltet sein. Der Beta-Zugang kann jederzeit beendet, geändert oder auf entgeltliche Nutzung umgestellt werden; hieraus entsteht kein Anspruch auf zukünftige unentgeltliche Nutzung. Wir bemühen uns, bestehende Daten zu erhalten; ein Anspruch hierauf besteht nicht.
    5.2 Abonnements: Wir bieten u. a. Monats- und Jahresabos an. Abos verlängern sich automatisch, sofern du nicht mindestens 24 Stunden vor Ablauf der jeweiligen Laufzeit im Apple App Store bzw. Google Play kündigst. Abrechnung und Verwaltung (Kündigung, Pausierung, Erstattungen) erfolgen ausschließlich über deinen Store-Account. Nach Kündigung läuft das Abo bis zum Ende des bereits bezahlten Zeitraums weiter; eine anteilige Erstattung erfolgt grundsätzlich nicht, soweit zwingendes Recht oder Store-Regeln nichts anderes vorsehen.
    5.3 Kostenlose Probezeit (falls angeboten): Eine Probezeit (z. B. 7 Tage) geht – wenn sie nicht rechtzeitig gekündigt wird – in ein kostenpflichtiges Abo über. Nicht genutzte Anteile einer Probezeit verfallen beim Abschluss eines Abos. Pro Person/Account/Haushalt können Probezeiten begrenzt sein.
    5.4 Einmalige In-App-Käufe / „Lifetime“: Einmalzahlungen (z. B. „Lifetime“) schalten bestimmte Funktionen dauerhaft für die Lebensdauer des Dienstes frei, nicht für die Lebensdauer der nutzenden Person. Wir bemühen uns um den fortgesetzten Betrieb, können ihn jedoch nicht garantieren (siehe §11). Gesetzliche Gewährleistungs- und Verbraucherschutzrechte bleiben unberührt.
    5.5 Preise & Steuern: Aktuelle Preise werden in der App/im Store angezeigt und können je nach Region, Währung, Steuern, Promotions und Store variieren. Preis-/Leistungsänderungen gelten – soweit zulässig – ab der nächsten Aboperiode; wir informieren dich vorab, sofern erforderlich.
    5.6 Erstattungen/Fehlkäufe: Erstattungen richten sich nach den Bedingungen des jeweiligen App-Stores; wende dich hierfür bitte an Apple bzw. Google. Sofern wir ausnahmsweise selbst Vertragspartner sind, gilt §6.

    6. Widerrufsrecht für Verbraucher:innen in der EU
    6.1 Bei Käufen über Apple App Store/Google Play erfolgt der Vertragsschluss mit dem jeweiligen Store; Widerruf/Erstattung werden nach den Store-Regeln abgewickelt. Bitte nutze die Store-Funktionen für Widerruf/Rückerstattung.
    6.2 Sofern wir ausnahmsweise selbst Vertragspartner eines digitalen Inhalts/Services sind, stimmst du zu, dass wir vor Ablauf der Widerrufsfrist mit der Ausführung beginnen, und du dein Widerrufsrecht mit vollständiger Vertragserfüllung verlierst (§ 356 Abs. 5 BGB). Im Übrigen gilt die gesetzliche Widerrufsbelehrung.

    7. Nutzerpflichten, verbotene Inhalte und Verhaltensregeln
    7.1 Verboten sind rechtswidrige, beleidigende, diskriminierende, pornografische, extremistische, irreführende oder sonst unzulässige Inhalte, das Umgehen technischer Schutzmaßnahmen, Reverse Engineering, Scraping sowie missbräuchliche Nutzung von Schnittstellen.
    7.2 Community: Respektvoller Umgang ist Pflicht. Wir können Inhalte moderieren, sperren oder entfernen, wenn ein Verstoß vorliegt oder begründet zu befürchten ist.

    8. Nutzerinhalte (UGC) und Rechte
    8.1 Du bleibst Inhaber:in deiner Inhalte. Durch das Bereitstellen von Inhalten räumst du uns eine weltweite, nicht exklusive, unentgeltliche, übertragbare, unterlizenzierbare Lizenz ein, diese Inhalte zum Betrieb, zur Bereitstellung und Verbesserung der App (einschließlich Speicherung, Vervielfältigung, technischer Verarbeitung, Anzeige und Verbreitung innerhalb der App) zu nutzen. Eine werbliche Nutzung außerhalb der App erfolgt nur mit deiner gesonderten Einwilligung.
    8.2 Du sicherst zu, über erforderliche Rechte zu verfügen und dass deine Inhalte keine Rechte Dritter verletzen.

    9. Drittanbieter, Links, Open-Source
    9.1 Die App kann auf Dienste Dritter verweisen (Websites, Inhalte, Geräte-Integrationen). Für deren Inhalte/Datenschutzpraktiken sind ausschließlich die jeweiligen Dritten verantwortlich.
    9.2 Wir nutzen ggf. Open-Source-Software; Hinweise/Lizenzen stellen wir in der App bereit.

    10. Health-Integrationen (Apple HealthKit/Google Fit u. ä.)
    10.1 Eine Verbindung erfolgt nur mit deiner ausdrücklichen Einwilligung; du kannst sie jederzeit widerrufen.
    10.2 Aus Health-Integrationen stammende Daten verwenden wir ausschließlich zur Bereitstellung der App-Funktionen (z. B. Schritte, Trainingsauswertung). Wir verkaufen diese Daten nicht und verwenden sie nicht für Werbung oder ähnliche Zwecke. Eine Weitergabe an Dritte erfolgt nur, soweit zur Leistungserbringung erforderlich und in unserer Datenschutzerklärung beschrieben.
    10.3 Du kannst das Schreiben/Lesen in den Systemeinstellungen steuern.

    11. Verfügbarkeit, Updates und Änderungen
    11.1 Es besteht kein Anspruch auf ununterbrochene Verfügbarkeit. Wartung, Sicherheit und Weiterentwicklung können zu Unterbrechungen führen.
    11.2 Wir stellen während eines Abos erforderliche Sicherheits- und Funktions-Updates bereit und informieren dich, wenn deren Installation erforderlich ist. Unterbleibt sie, kann dies die Funktionsfähigkeit beeinträchtigen.
    11.3 Wir dürfen Funktionen in zumutbarem Umfang ändern. Wesentliche Änderungen der AGB teilen wir rechtzeitig (z. B. 30 Tage) mit. Widersprichst du nicht oder nutzt du die App weiter, gelten die Änderungen als akzeptiert; wir weisen in der Mitteilung darauf hin.

    12. Gewährleistung und Haftung
    12.1 Es gilt die gesetzliche Haftung: unbegrenzt bei Vorsatz und grober Fahrlässigkeit sowie bei Verletzung von Leben, Körper oder Gesundheit. Ebenfalls unberührt bleiben Ansprüche nach dem Produkthaftungsgesetz.
    12.2 Bei leichter Fahrlässigkeit haften wir nur für die Verletzung wesentlicher Vertragspflichten (Kardinalpflichten) und beschränkt auf den vertragstypisch vorhersehbaren Schaden.
    12.3 Bei unentgeltlicher Nutzung haften wir nur bei Vorsatz/grober Fahrlässigkeit.
    12.4 Zwingende Verbraucherschutzrechte bleiben unberührt.

    13. Laufzeit, Kündigung, Sperrung
    13.1 Das Nutzungsverhältnis läuft auf unbestimmte Zeit und kann jederzeit durch Löschen des Kontos beendet werden.
    13.2 Abonnements kündigst du im jeweiligen App-Store; dort gelten die Kündigungsfristen und Verlängerungen.
    13.3 Wir können die Bereitstellung aus wichtigem Grund aussetzen oder kündigen (z. B. wiederholte Verstöße, Missbrauch, Zahlungsverzug), unter angemessener Berücksichtigung deiner Interessen.

    14. Datenschutz
    Es gilt unsere Datenschutzerklärung unter [URL zur Datenschutzerklärung]. Sie erläutert, welche Daten wir verarbeiten, zu welchen Zwecken und welche Rechte du (Art. 12–22 DSGVO) hast.

    15. Geistiges Eigentum und Feedback
    15.1 Die App, ihre Inhalte (außer UGC), Marken und Kennzeichen sind durch Urheber-, Marken- und sonstige Schutzrechte zugunsten des Anbieters bzw. seiner Lizenzgeber geschützt.
    15.2 Übermitteltes Feedback dürfen wir unentgeltlich, zeitlich und räumlich unbeschränkt zur Verbesserung der App nutzen.

    16. Online-Streitbeilegung, Verbraucherstreitbeilegung
    Die EU-Kommission stellt eine Plattform zur Online-Streitbeilegung bereit: https://ec.europa.eu/consumers/odr/ .
    Wir sind nicht bereit und nicht verpflichtet, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen.

    17. Anwendbares Recht, Gerichtsstand, Vertragssprache
    Es gilt das Recht der Bundesrepublik Deutschland, wobei für Verbraucher:innen mit gewöhnlichem Aufenthalt im EWR zwingende Bestimmungen ihres Aufenthaltsstaates unberührt bleiben. Gerichtsstand ist – soweit zulässig – der Sitz des Anbieters. Vertragssprache ist Deutsch; etwaige Übersetzungen (z. B. Englisch) dienen der Information. Bei Abweichungen hat die deutsche Fassung Vorrang.

    18. Salvatorische Klausel
    Sollten einzelne Bestimmungen unwirksam sein, bleibt der Vertrag im Übrigen wirksam.
    """


    static let agb_en: String = """
    Terms and Conditions – movo
    Effective: Oct 25, 2025

    1. Provider; Scope
    These Terms govern the worldwide use of the “movo” app and related services between the Provider (“we”) and you as the user (“you”). Deviating or conflicting terms do not apply unless we expressly agree.

    2. Services, License, Technical Requirements
    2.1 The app offers training plans, challenges, analytics, step/activity data, notifications, and community/gamification features. Features may change or be expanded.
    2.2 We grant you a personal, revocable, non-exclusive, non-transferable license to use the app in accordance with these Terms.
    2.3 A compatible device and internet access are required and at your own cost. Third-party accounts (e.g., Apple, Google) may be necessary.

    3. Registration, Age, Account
    3.1 Certain features require an account. Sign-in via email/password or “Sign in with Apple/Google” is available. You provide accurate information and keep it up to date.
    3.2 You are at least 16 years old. Younger users may only use the app with parental consent.
    3.3 Keep credentials confidential and notify us immediately of any unauthorized use. We may temporarily suspend accounts upon reasonable suspicion of misuse.

    4. Health Notice (No Medical Services)
    Use is at your own risk. Consult a physician before starting any training, especially if you have pre-existing conditions. The app does not provide medical advice, diagnosis, or treatment and is not a substitute for professional care. In emergencies, call local emergency services.

    5. Fees, In-App Purchases and Subscriptions (incl. “Lifetime”, trials, beta)
    5.1 Beta access: During a beta phase, some or all Pro features may be available free of charge. Beta access may be ended, changed, or transitioned to paid access at any time; this creates no entitlement to future free use. We aim to preserve existing data, but this cannot be guaranteed.
    5.2 Subscriptions: We offer, among others, monthly and yearly subscriptions. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current term in the Apple App Store or Google Play. Billing and management (cancellation, pause, refunds) are handled solely via your store account. After cancellation, access continues until the end of the paid period; partial refunds are generally not provided unless required by law or store rules.
    5.3 Free trial (if offered): A trial period (e.g., 7 days) converts into a paid subscription unless cancelled in time. Any unused portion of a trial is forfeited when you purchase a subscription. Trials may be limited per person/account/household.
    5.4 One-time in-app purchases / “Lifetime”: One-time payments (e.g., “Lifetime”) unlock features for the lifetime of the service, not the lifetime of the user. We strive to keep the service running but cannot guarantee perpetual availability (see §11). Statutory warranty and consumer rights remain unaffected.
    5.5 Pricing & taxes: Current prices are shown in-app/in-store and may vary by region, currency, taxes, promotions, and store. Price/feature changes apply—where permitted—from the next subscription period; we will inform you in advance where required.
    5.6 Refunds/accidental purchases: Refunds follow the applicable store policies; please contact Apple or Google. If we are the contracting party in exceptional cases, §6 applies.

    6. Right of Withdrawal for EU Consumers
    6.1 For purchases via Apple App Store/Google Play, the contract is with the respective store; withdrawals/refunds are handled under the store rules. Please use the store tools to request a withdrawal/refund.
    6.2 If, in exceptional cases, we are the contracting party for digital content/services, you consent to immediate performance and acknowledge that your statutory right of withdrawal lapses upon full performance. Statutory instructions on withdrawal apply otherwise.

    7. User Obligations, Prohibited Conduct
    7.1 Prohibited: illegal, offensive, discriminatory, pornographic, extremist, misleading or otherwise impermissible content; bypassing security, reverse engineering, scraping, or abusing interfaces.
    7.2 Community rules: Be respectful. We may moderate, restrict, or remove content if violations occur or are reasonably suspected.

    8. User-Generated Content (UGC) and Rights
    8.1 You retain ownership of your content. By providing content, you grant us a worldwide, non-exclusive, royalty-free, transferable, sublicensable license to use it as necessary to operate, provide, and improve the app (including storing, reproducing, technical processing, displaying, and distributing within the app). Any advertising use outside the app requires your separate consent.
    8.2 You warrant that you hold the necessary rights and that your content does not infringe third-party rights.

    9. Third Parties, Links, Open Source
    9.1 The app may reference third-party services. We are not responsible for their content or privacy practices.
    9.2 We may use open-source software; notices/licenses are provided in-app.

    10. Health Integrations (Apple HealthKit/Google Fit, etc.)
    10.1 Connections are enabled only with your explicit consent and can be revoked at any time.
    10.2 Data from health integrations is used solely to provide app features (e.g., steps, training analytics). We do not sell such data and do not use it for advertising. Sharing with third parties occurs only as necessary for service provision and as described in our Privacy Policy.
    10.3 You can control read/write permissions in system settings.

    11. Availability, Updates, Changes
    11.1 No guarantee of uninterrupted availability. Maintenance, security, and development may cause interruptions.
    11.2 During a subscription we provide necessary security/functional updates and may inform you when installation is required. Failure to install may impair functionality.
    11.3 We may modify features to a reasonable extent. Material changes to these Terms will be announced in advance (e.g., 30 days). If you do not object or continue using the app, the changes are deemed accepted; we will highlight this in the notice.

    12. Warranty and Liability
    12.1 Statutory liability applies: unlimited for intent and gross negligence and for injury to life, body, or health. Mandatory product liability remains unaffected.
    12.2 For slight negligence, liability is limited to breaches of essential contractual duties (cardinal duties) and to typical, foreseeable damages.
    12.3 For free-of-charge use, we are liable only for intent/gross negligence.
    12.4 Mandatory consumer rights remain unaffected.

    13. Term, Termination, Suspension
    13.1 The agreement runs for an indefinite term and may be terminated at any time by deleting the account.
    13.2 Subscriptions must be cancelled in the respective app store; its renewal and cancellation terms apply.
    13.3 We may suspend or terminate for cause (e.g., repeated violations, abuse, payment default) with due regard to your legitimate interests.

    14. Privacy
    Our Privacy Policy at [Privacy Policy URL] explains what data we process, for what purposes, and your rights (Arts. 12–22 GDPR).

    15. Intellectual Property and Feedback
    15.1 The app and its content (excluding UGC), trademarks and trade dress are protected and remain the property of the Provider or its licensors.
    15.2 You grant us a free, perpetual, worldwide right to use feedback for improving the app.

    16. Online Dispute Resolution, Consumer ADR
    The EU platform for Online Dispute Resolution is available at https://ec.europa.eu/consumers/odr/ .
    We are not willing and no obliged to participate in consumer ADR before a dispute resolution body.

    17. Governing Law, Venue, Language
    German law applies; for consumers habitually resident in the EEA, mandatory consumer protection provisions of their country remain unaffected. Venue, where permissible, is the Provider’s registered seat. The contract language is German; translations (e.g., English) are for convenience only. In case of discrepancies, the German version prevails.

    18. Severability
    If any provision is invalid, the remainder remains in force.
    """
  



    // MARK: - DATENSCHUTZ / PRIVACY (Markdown-Fallbacks)
  
    // MARK: - DATENSCHUTZ (HTML, DE) – vollständiger HTML-Text
    static let privacy_de_html: String = """
<h1>Datenschutzerklärung</h1>
<h2 id="m716">Präambel</h2>
<p>Mit der folgenden Datenschutzerklärung möchten wir Sie darüber aufklären, welche Arten Ihrer personenbezogenen Daten (nachfolgend auch kurz als "Daten" bezeichnet) wir zu welchen Zwecken und in welchem Umfang verarbeiten. Die Datenschutzerklärung gilt für alle von uns durchgeführten Verarbeitungen personenbezogener Daten, sowohl im Rahmen der Erbringung unserer Leistungen als auch insbesondere auf unseren Webseiten, in mobilen Applikationen sowie innerhalb externer Onlinepräsenzen, wie z.&nbsp;B. unserer Social-Media-Profile (nachfolgend zusammenfassend bezeichnet als "Onlineangebot").</p>
<p>Die verwendeten Begriffe sind nicht geschlechtsspezifisch.</p>

<p>Stand: 25. Oktober 2025</p><h2>Inhaltsübersicht</h2> <ul class="index"><li><a class="index-link" href="#m716">Präambel</a></li><li><a class="index-link" href="#m3">Verantwortlicher</a></li><li><a class="index-link" href="#mOverview">Übersicht der Verarbeitungen</a></li><li><a class="index-link" href="#m2427">Maßgebliche Rechtsgrundlagen</a></li><li><a class="index-link" href="#m25">Übermittlung von personenbezogenen Daten</a></li><li><a class="index-link" href="#m24">Internationale Datentransfers</a></li><li><a class="index-link" href="#m12">Allgemeine Informationen zur Datenspeicherung und Löschung</a></li><li><a class="index-link" href="#m10">Rechte der betroffenen Personen</a></li><li><a class="index-link" href="#m317">Geschäftliche Leistungen</a></li><li><a class="index-link" href="#m225">Bereitstellung des Onlineangebots und Webhosting</a></li><li><a class="index-link" href="#m134">Einsatz von Cookies</a></li><li><a class="index-link" href="#m367">Registrierung, Anmeldung und Nutzerkonto</a></li><li><a class="index-link" href="#m451">Single-Sign-On-Anmeldung</a></li><li><a class="index-link" href="#m182">Kontakt- und Anfrageverwaltung</a></li><li><a class="index-link" href="#m1643">Push-Nachrichten</a></li><li><a class="index-link" href="#m15">Änderung und Aktualisierung</a></li><li><a class="index-link" href="#m42">Begriffsdefinitionen</a></li></ul><h2 id="m3">Verantwortlicher</h2><p>Benedikt Purkott<br>c/o Block Services<br>Stuttgarter Str. 106<br>70736 Fellbach<br>Deutschland</p>
<p>E-Mail-Adresse: <a href="mailto:movobp.contact@gmail.com">movobp.contact@gmail.com</a></p>

<h2 id="mOverview">Übersicht der Verarbeitungen</h2><p>Die nachfolgende Übersicht fasst die Arten der verarbeiteten Daten und die Zwecke ihrer Verarbeitung zusammen und verweist auf die betroffenen Personen.</p><h3>Arten der verarbeiteten Daten</h3>
<ul><li>Bestandsdaten.</li><li>Zahlungsdaten.</li><li>Kontaktdaten.</li><li>Inhaltsdaten.</li><li>Vertragsdaten.</li><li>Nutzungsdaten.</li><li>Meta-, Kommunikations- und Verfahrensdaten.</li><li>Protokolldaten.</li></ul><h3>Kategorien betroffener Personen</h3><ul><li>Leistungsempfänger und Auftraggeber.</li><li>Interessenten.</li><li>Kommunikationspartner.</li><li>Nutzer.</li><li>Geschäfts- und Vertragspartner.</li></ul><h3>Zwecke der Verarbeitung</h3><ul><li>Erbringung vertraglicher Leistungen und Erfüllung vertraglicher Pflichten.</li><li>Kommunikation.</li><li>Sicherheitsmaßnahmen.</li><li>Büro- und Organisationsverfahren.</li><li>Organisations- und Verwaltungsverfahren.</li><li>Feedback.</li><li>Anmeldeverfahren.</li><li>Bereitstellung unseres Onlineangebotes und Nutzerfreundlichkeit.</li><li>Informationstechnische Infrastruktur.</li><li>Geschäftsprozesse und betriebswirtschaftliche Verfahren.</li></ul><h2 id="m2427">Maßgebliche Rechtsgrundlagen</h2><p><strong>Maßgebliche Rechtsgrundlagen nach der DSGVO: </strong>Im Folgenden erhalten Sie eine Übersicht der Rechtsgrundlagen der DSGVO, auf deren Basis wir personenbezogene Daten verarbeiten. Bitte nehmen Sie zur Kenntnis, dass neben den Regelungen der DSGVO nationale Datenschutzvorgaben in Ihrem bzw. unserem Wohn- oder Sitzland gelten können. Sollten ferner im Einzelfall speziellere Rechtsgrundlagen maßgeblich sein, teilen wir Ihnen diese in der Datenschutzerklärung mit.</p>
 <ul><li><strong>Einwilligung (Art. 6 Abs. 1 S. 1 lit. a) DSGVO)</strong> - Die betroffene Person hat ihre Einwilligung in die Verarbeitung der sie betreffenden personenbezogenen Daten für einen spezifischen Zweck oder mehrere bestimmte Zwecke gegeben.</li><li><strong>Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO)</strong> - Die Verarbeitung ist für die Erfüllung eines Vertrags, dessen Vertragspartei die betroffene Person ist, oder zur Durchführung vorvertraglicher Maßnahmen erforderlich, die auf Anfrage der betroffenen Person erfolgen.</li><li><strong>Rechtliche Verpflichtung (Art. 6 Abs. 1 S. 1 lit. c) DSGVO)</strong> - Die Verarbeitung ist zur Erfüllung einer rechtlichen Verpflichtung erforderlich, der der Verantwortliche unterliegt.</li><li><strong>Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO)</strong> - die Verarbeitung ist zur Wahrung der berechtigten Interessen des Verantwortlichen oder eines Dritten notwendig, vorausgesetzt, dass die Interessen, Grundrechte und Grundfreiheiten der betroffenen Person, die den Schutz personenbezogener Daten verlangen, nicht überwiegen.</li></ul><p><strong>Nationale Datenschutzregelungen in Deutschland: </strong>Zusätzlich zu den Datenschutzregelungen der DSGVO gelten nationale Regelungen zum Datenschutz in Deutschland. Hierzu gehört insbesondere das Gesetz zum Schutz vor Missbrauch personenbezogener Daten bei der Datenverarbeitung (Bundesdatenschutzgesetz – BDSG). Das BDSG enthält insbesondere Spezialregelungen zum Recht auf Auskunft, zum Recht auf Löschung, zum Widerspruchsrecht, zur Verarbeitung besonderer Kategorien personenbezogener Daten, zur Verarbeitung für andere Zwecke und zur Übermittlung sowie automatisierten Entscheidungsfindung im Einzelfall einschließlich Profiling. Ferner können Landesdatenschutzgesetze der einzelnen Bundesländer zur Anwendung gelangen.</p>
<p><strong>Hinweis auf Geltung DSGVO und Schweizer DSG: </strong>Diese Datenschutzhinweise dienen sowohl der Informationserteilung nach dem Schweizer DSG als auch nach der Datenschutzgrundverordnung (DSGVO). Aus diesem Grund bitten wir Sie zu beachten, dass aufgrund der breiteren räumlichen Anwendung und Verständlichkeit die Begriffe der DSGVO verwendet werden. Insbesondere statt der im Schweizer DSG verwendeten Begriffe „Bearbeitung" von „Personendaten", "überwiegendes Interesse" und "besonders schützenswerte Personendaten" werden die in der DSGVO verwendeten Begriffe „Verarbeitung" von „personenbezogenen Daten" sowie "berechtigtes Interesse" und "besondere Kategorien von Daten" verwendet. Die gesetzliche Bedeutung der Begriffe wird jedoch im Rahmen der Geltung des Schweizer DSG weiterhin nach dem Schweizer DSG bestimmt.</p>

<h2 id="m25">Übermittlung von personenbezogenen Daten</h2><p>Im Rahmen unserer Verarbeitung von personenbezogenen Daten kommt es vor, dass diese an andere Stellen, Unternehmen, rechtlich selbstständige Organisationseinheiten oder Personen übermittelt beziehungsweise ihnen gegenüber offengelegt werden. Zu den Empfängern dieser Daten können z.&nbsp;B. mit IT-Aufgaben beauftragte Dienstleister gehören oder Anbieter von Diensten und Inhalten, die in eine Website eingebunden sind. In solchen Fällen beachten wir die gesetzlichen Vorgaben und schließen insbesondere entsprechende Verträge bzw. Vereinbarungen, die dem Schutz Ihrer Daten dienen, mit den Empfängern Ihrer Daten ab.</p>

<h2 id="m24">Internationale Datentransfers</h2><p>Datenverarbeitung in Drittländern: Sofern wir Daten in ein Drittland (d. h. außerhalb der Europäischen Union (EU) oder des Europäischen Wirtschaftsraums (EWR)) übermitteln oder dies im Rahmen der Nutzung von Diensten Dritter oder der Offenlegung bzw. Übermittlung von Daten an andere Personen, Stellen oder Unternehmen geschieht (was erkennbar wird anhand der Postadresse des jeweiligen Anbieters oder wenn in der Datenschutzerklärung ausdrücklich auf den Datentransfer in Drittländer hingewiesen wird), erfolgt dies stets im Einklang mit den gesetzlichen Vorgaben.</p>
<p>Für Datenübermittlungen in die USA stützen wir uns vorrangig auf das Data Privacy Framework (DPF), welches durch einen Angemessenheitsbeschluss der EU-Kommission vom 10.07.2023 als sicherer Rechtsrahmen anerkannt wurde. Zusätzlich haben wir mit den jeweiligen Anbietern Standardvertragsklauseln abgeschlossen, die den Vorgaben der EU-Kommission entsprechen und vertragliche Verpflichtungen zum Schutz Ihrer Daten festlegen.</p>
<p>Diese zweifache Absicherung gewährleistet einen umfassenden Schutz Ihrer Daten: Das DPF bildet die primäre Schutzebene, während die Standardvertragsklauseln als zusätzliche Sicherheit dienen. Sollten sich Änderungen im Rahmen des DPF ergeben, greifen die Standardvertragsklauseln als zuverlässige Rückfalloption ein. So stellen wir sicher, dass Ihre Daten auch bei etwaigen politischen oder rechtlichen Veränderungen stets angemessen geschützt bleiben.</p>
<p>Bei den einzelnen Diensteanbietern informieren wir Sie darüber, ob sie nach dem DPF zertifiziert sind und ob Standardvertragsklauseln vorliegen. Weitere Informationen zum DPF und eine Liste der zertifizierten Unternehmen finden Sie auf der Website des US-Handelsministeriums unter <a href="https://www.dataprivacyframework.gov/" target="_blank">https://www.dataprivacyframework.gov/</a> (in englischer Sprache).</p>
<p>Für Datenübermittlungen in andere Drittländer gelten entsprechende Sicherheitsmaßnahmen, insbesondere Standardvertragsklauseln, ausdrückliche Einwilligungen oder gesetzlich erforderliche Übermittlungen. Informationen zu Drittlandtransfers und geltenden Angemessenheitsbeschlüssen können Sie dem Informationsangebot der EU-Kommission entnehmen: <a href="https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection_en?prefLang=de" target="_blank">https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection_en?prefLang=de.</a></p>

<h2 id="m12">Allgemeine Informationen zur Datenspeicherung und Löschung</h2><p>Wir löschen personenbezogene Daten, die wir verarbeiten, gemäß den gesetzlichen Bestimmungen, sobald die zugrundeliegenden Einwilligungen widerrufen werden oder keine weiteren rechtlichen Grundlagen für die Verarbeitung bestehen. Dies betrifft Fälle, in denen der ursprüngliche Verarbeitungszweck entfällt oder die Daten nicht mehr benötigt werden. Ausnahmen von dieser Regelung bestehen, wenn gesetzliche Pflichten oder besondere Interessen eine längere Aufbewahrung oder Archivierung der Daten erfordern.</p>
<p>Insbesondere müssen Daten, die aus handels- oder steuerrechtlichen Gründen aufbewahrt werden müssen oder deren Speicherung notwendig ist zur Rechtsverfolgung oder zum Schutz der Rechte anderer natürlicher oder juristischer Personen, entsprechend archiviert werden.</p>
<p>Unsere Datenschutzhinweise enthalten zusätzliche Informationen zur Aufbewahrung und Löschung von Daten, die speziell für bestimmte Verarbeitungsprozesse gelten.</p>
<p>Bei mehreren Angaben zur Aufbewahrungsdauer oder Löschungsfristen eines Datums, ist stets die längste Frist maßgeblich. Daten, die nicht mehr für den ursprünglich vorgesehenen Zweck, sondern aufgrund gesetzlicher Vorgaben oder anderer Gründe aufbewahrt werden, verarbeiten wir ausschließlich zu den Gründen, die ihre Aufbewahrung rechtfertigen.</p>
<p>Aufbewahrung und Löschung von Daten: Die folgenden allgemeinen Fristen gelten für die Aufbewahrung und Archivierung nach deutschem Recht:</p><ul> <li>10 Jahre - Aufbewahrungsfrist für Bücher und Aufzeichnungen, Jahresabschlüsse, Inventare, Lageberichte, Eröffnungsbilanz sowie die zu ihrem Verständnis erforderlichen Arbeitsanweisungen und sonstigen Organisationsunterlagen (§ 147 Abs. 1 Nr. 1 i.V.m. Abs. 3 AO, § 14b Abs. 1 UStG, § 257 Abs. 1 Nr. 1 i.V.m. Abs. 4 HGB).</li><li>8 Jahre - Buchungsbelege, wie z.&nbsp;B. Rechnungen und Kostenbelege (§ 147 Abs. 1 Nr. 4 und 4a i.V.m. Abs. 3 Satz 1 AO sowie § 257 Abs. 1 Nr. 4 i.V.m. Abs. 4 HGB).</li><li>6 Jahre - Übrige Geschäftsunterlagen: empfangene Handels- oder Geschäftsbriefe, Wiedergaben der abgesandten Handels- oder Geschäftsbriefe, sonstige Unterlagen, soweit sie für die Besteuerung von Bedeutung sind, z.&nbsp;B. Stundenlohnzettel, Betriebsabrechnungsbögen, Kalkulationsunterlagen, Preisauszeichnungen, aber auch Lohnabrechnungsunterlagen, soweit sie nicht bereits Buchungsbelege sind und Kassenstreifen (§ 147 Abs. 1 Nr. 2, 3, 5 i.V.m. Abs. 3 AO, § 257 Abs. 1 Nr. 2 u. 3 i.V.m. Abs. 4 HGB).</li><li>3 Jahre - Daten, die erforderlich sind, um potenzielle Gewährleistungs- und Schadensersatzansprüche oder ähnliche vertragliche Ansprüche und Rechte zu berücksichtigen sowie damit verbundene Anfragen zu bearbeiten, basierend auf früheren Geschäftserfahrungen und üblichen Branchenpraktiken, werden für die Dauer der regulären gesetzlichen Verjährungsfrist von drei Jahren gespeichert (§§ 195, 199 BGB).</li> </ul>
<p>Fristbeginn mit Ablauf des Jahres: Beginnt eine Frist nicht ausdrücklich zu einem bestimmten Datum und beträgt sie mindestens ein Jahr, so startet sie automatisch am Ende des Kalenderjahres, in dem das fristauslösende Ereignis eingetreten ist. Im Fall laufender Vertragsverhältnisse, in deren Rahmen Daten gespeichert werden, ist das fristauslösende Ereignis der Zeitpunkt des Wirksamwerdens der Kündigung oder sonstige Beendigung des Rechtsverhältnisses.</p>

<h2 id="m10">Rechte der betroffenen Personen</h2><p>Rechte der betroffenen Personen aus der DSGVO: Ihnen stehen als Betroffene nach der DSGVO verschiedene Rechte zu, die sich insbesondere aus Art. 15 bis 21 DSGVO ergeben:</p><ul><li><strong>Widerspruchsrecht: Sie haben das Recht, aus Gründen, die sich aus Ihrer besonderen Situation ergeben, jederzeit gegen die Verarbeitung der Sie betreffenden personenbezogenen Daten, die aufgrund von Art. 6 Abs. 1 lit. e oder f DSGVO erfolgt, Widerspruch einzulegen; dies gilt auch für ein auf diese Bestimmungen gestütztes Profiling. Werden die Sie betreffenden personenbezogenen Daten verarbeitet, um Direktwerbung zu betreiben, haben Sie das Recht, jederzeit Widerspruch gegen die Verarbeitung der Sie betreffenden personenbezogenen Daten zum Zwecke derartiger Werbung einzulegen; dies gilt auch für das Profiling, soweit es mit solcher Direktwerbung in Verbindung steht.</strong></li><li><strong>Widerrufsrecht bei Einwilligungen:</strong> Sie haben das Recht, erteilte Einwilligungen jederzeit zu widerrufen.</li><li><strong>Auskunftsrecht:</strong> Sie haben das Recht, eine Bestätigung darüber zu verlangen, ob betreffende Daten verarbeitet werden und auf Auskunft über diese Daten sowie auf weitere Informationen und Kopie der Daten entsprechend den gesetzlichen Vorgaben.</li><li><strong>Recht auf Berichtigung:</strong> Sie haben entsprechend den gesetzlichen Vorgaben das Recht, die Vervollständigung der Sie betreffenden Daten oder die Berichtigung der Sie betreffenden unrichtigen Daten zu verlangen.</li><li><strong>Recht auf Löschung und Einschränkung der Verarbeitung:</strong> Sie haben nach Maßgabe der gesetzlichen Vorgaben das Recht, zu verlangen, dass Sie betreffende Daten unverzüglich gelöscht werden, bzw. alternativ nach Maßgabe der gesetzlichen Vorgaben eine Einschränkung der Verarbeitung der Daten zu verlangen.</li><li><strong>Recht auf Datenübertragbarkeit:</strong> Sie haben das Recht, Sie betreffende Daten, die Sie uns bereitgestellt haben, nach Maßgabe der gesetzlichen Vorgaben in einem strukturierten, gängigen und maschinenlesbaren Format zu erhalten oder deren Übermittlung an einen anderen Verantwortlichen zu fordern.</li><li><strong>Beschwerde bei Aufsichtsbehörde:</strong> Sie haben unbeschadet eines anderweitigen verwaltungsrechtlichen oder gerichtlichen Rechtsbehelfs das Recht auf Beschwerde bei einer Aufsichtsbehörde, insbesondere in dem Mitgliedstaat ihres gewöhnlichen Aufenthaltsorts, ihres Arbeitsplatzes oder des Orts des mutmaßlichen Verstoßes, wenn Sie der Ansicht sind, dass die Verarbeitung der Sie betreffenden personenbezogenen Daten gegen die Vorgaben der DSGVO verstößt.</li></ul>

<h2 id="m317">Geschäftliche Leistungen</h2><p>Wir verarbeiten Daten unserer Vertrags- und Geschäftspartner, z.&nbsp;B. Kunden und Interessenten (zusammenfassend als „Vertragspartner" bezeichnet), im Rahmen von vertraglichen und vergleichbaren Rechtsverhältnissen sowie damit verbundenen Maßnahmen und im Hinblick auf die Kommunikation mit den Vertragspartnern (oder vorvertraglich), etwa zur Beantwortung von Anfragen.</p>
<p>Wir verwenden diese Daten, um unsere vertraglichen Verpflichtungen zu erfüllen. Dazu gehören insbesondere die Pflichten zur Erbringung der vereinbarten Leistungen, etwaige Aktualisierungspflichten und Abhilfe bei Gewährleistungs- und sonstigen Leistungsstörungen. Darüber hinaus verwenden wir die Daten zur Wahrung unserer Rechte und zum Zwecke der mit diesen Pflichten verbundenen Verwaltungsaufgaben sowie der Unternehmensorganisation. Zudem verarbeiten wir die Daten auf Grundlage unserer berechtigten Interessen sowohl an einer ordnungsgemäßen und betriebswirtschaftlichen Geschäftsführung als auch an Sicherheitsmaßnahmen zum Schutz unserer Vertragspartner und unseres Geschäftsbetriebs vor Missbrauch, Gefährdung ihrer Daten, Geheimnisse, Informationen und Rechte (z.&nbsp;B. zur Beteiligung von Telekommunikations-, Transport- und sonstigen Hilfsdiensten sowie Subunternehmern, Banken, Steuer- und Rechtsberatern, Zahlungsdienstleistern oder Finanzbehörden). Im Rahmen des geltenden Rechts geben wir die Daten von Vertragspartnern nur insoweit an Dritte weiter, als dies für die vorgenannten Zwecke oder zur Erfüllung gesetzlicher Pflichten erforderlich ist. Über weitere Formen der Verarbeitung, etwa zu Marketingzwecken, werden die Vertragspartner im Rahmen dieser Datenschutzerklärung informiert.</p>
<p>Welche Daten für die vorgenannten Zwecke erforderlich sind, teilen wir den Vertragspartnern vor oder im Rahmen der Datenerhebung, z.&nbsp;B. in Onlineformularen, durch besondere Kennzeichnung (z.&nbsp;B. Farben) bzw. Symbole (z.&nbsp;B. Sternchen o. Ä.), oder persönlich mit.</p>
<p>Wir löschen die Daten nach Ablauf gesetzlicher Gewährleistungs- und vergleichbarer Pflichten, d. h. grundsätzlich nach vier Jahren, es sei denn, dass die Daten in einem Kundenkonto gespeichert werden, z.&nbsp;B., solange sie aus gesetzlichen Gründen der Archivierung aufbewahrt werden müssen (etwa für Steuerzwecke im Regelfall zehn Jahre). Daten, die uns im Rahmen eines Auftrags durch den Vertragspartner offengelegt wurden, löschen wir entsprechend den Vorgaben und grundsätzlich nach Ende des Auftrags.</p>
<ul class="m-elements"><li><strong>Verarbeitete Datenarten:</strong> Bestandsdaten (z.&nbsp;B. der vollständige Name, Wohnadresse, Kontaktinformationen, Kundennummer, etc.); Zahlungsdaten (z.&nbsp;B. Bankverbindungen, Rechnungen, Zahlungshistorie); Kontaktdaten (z.&nbsp;B. Post- und E-Mail-Adressen oder Telefonnummern). Vertragsdaten (z.&nbsp;B. Vertragsgegenstand, Laufzeit, Kundenkategorie).</li><li><strong>Betroffene Personen:</strong> Leistungsempfänger und Auftraggeber; Interessenten. Geschäfts- und Vertragspartner.</li><li><strong>Zwecke der Verarbeitung:</strong> Erbringung vertraglicher Leistungen und Erfüllung vertraglicher Pflichten; Kommunikation; Büro- und Organisationsverfahren; Organisations- und Verwaltungsverfahren. Geschäftsprozesse und betriebswirtschaftliche Verfahren.</li><li><strong>Aufbewahrung und Löschung:</strong> Löschung entsprechend Angaben im Abschnitt "Allgemeine Informationen zur Datenspeicherung und Löschung".</li><li class=""><strong>Rechtsgrundlagen:</strong> Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO); Rechtliche Verpflichtung (Art. 6 Abs. 1 S. 1 lit. c) DSGVO). Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO).</li></ul><p><strong>Weitere Hinweise zu Verarbeitungsprozessen, Verfahren und Diensten:</strong></p><ul class="m-elements"><li><strong>Angebot von Software- und Plattformleistungen: </strong>Wir verarbeiten die Daten unserer Nutzer, angemeldeter und etwaiger Testnutzer (nachfolgend einheitlich als "Nutzer" bezeichnet), um ihnen gegenüber unsere vertraglichen Leistungen erbringen zu können sowie auf Grundlage berechtigter Interessen, um die Sicherheit unseres Angebotes gewährleisten und es weiterentwickeln zu können. Die erforderlichen Angaben sind als solche im Rahmen des Auftrags-, Bestell- bzw. vergleichbaren Vertragsschlusses gekennzeichnet und umfassen die zur Leistungserbringung und Abrechnung benötigten Angaben sowie Kontaktinformationen, um etwaige Rücksprachen halten zu können; <span class=""><strong>Rechtsgrundlagen:</strong> Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO).</span></li></ul>
<h2 id="m225">Bereitstellung des Onlineangebots und Webhosting</h2><p>Wir verarbeiten die Daten der Nutzer, um ihnen unsere Online-Dienste zur Verfügung stellen zu können. Zu diesem Zweck verarbeiten wir die IP-Adresse des Nutzers, die notwendig ist, um die Inhalte und Funktionen unserer Online-Dienste an den Browser oder das Endgerät der Nutzer zu übermitteln.</p>
<ul class="m-elements"><li><strong>Verarbeitete Datenarten:</strong> Nutzungsdaten (z. B. Seitenaufrufe und Verweildauer, Klickpfade, Nutzungsintensität und -frequenz, verwendete Gerätetypen und Betriebssysteme, Interaktionen mit Inhalten und Funktionen); Meta-, Kommunikations- und Verfahrensdaten (z. B. IP-Adressen, Zeitangaben, Identifikationsnummern, beteiligte Personen). Protokolldaten (z.&nbsp;B. Logfiles betreffend Logins oder den Abruf von Daten oder Zugriffszeiten.).</li><li><strong>Betroffene Personen:</strong> Nutzer (z.&nbsp;B. Webseitenbesucher, Nutzer von Onlinediensten).</li><li><strong>Zwecke der Verarbeitung:</strong> Bereitstellung unseres Onlineangebotes und Nutzerfreundlichkeit; Informationstechnische Infrastruktur (Betrieb und Bereitstellung von Informationssystemen und technischen Geräten (Computer, Server etc.)). Sicherheitsmaßnahmen.</li><li><strong>Aufbewahrung und Löschung:</strong> Löschung entsprechend Angaben im Abschnitt "Allgemeine Informationen zur Datenspeicherung und Löschung".</li><li class=""><strong>Rechtsgrundlagen:</strong> Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO).</li></ul><p><strong>Weitere Hinweise zu Verarbeitungsprozessen, Verfahren und Diensten:</strong></p><ul class="m-elements"><li><strong>Bereitstellung Onlineangebot auf gemietetem Speicherplatz: </strong>Für die Bereitstellung unseres Onlineangebotes nutzen wir Speicherplatz, Rechenkapazität und Software, die wir von einem entsprechenden Serveranbieter (auch "Webhoster" genannt) mieten oder anderweitig beziehen; <span class=""><strong>Rechtsgrundlagen:</strong> Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO).</span></li><li><strong>Erhebung von Zugriffsdaten und Logfiles: </strong>Der Zugriff auf unser Onlineangebot wird in Form von sogenannten "Server-Logfiles" protokolliert. Zu den Serverlogfiles können die Adresse und der Name der abgerufenen Webseiten und Dateien, Datum und Uhrzeit des Abrufs, übertragene Datenmengen, Meldung über erfolgreichen Abruf, Browsertyp nebst Version, das Betriebssystem des Nutzers, Referrer URL (die zuvor besuchte Seite) und im Regelfall IP-Adressen und der anfragende Provider gehören. Die Serverlogfiles können zum einen zu Sicherheitszwecken eingesetzt werden, z.&nbsp;B. um eine Überlastung der Server zu vermeiden (insbesondere im Fall von missbräuchlichen Angriffen, sogenannten DDoS-Attacken), und zum anderen, um die Auslastung der Server und ihre Stabilität sicherzustellen; <span class=""><strong>Rechtsgrundlagen:</strong> Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO). </span><strong>Löschung von Daten:</strong> Logfile-Informationen werden für die Dauer von maximal 30 Tagen gespeichert und danach gelöscht oder anonymisiert. Daten, deren weitere Aufbewahrung zu Beweiszwecken erforderlich ist, sind bis zur endgültigen Klärung des jeweiligen Vorfalls von der Löschung ausgenommen.</li></ul>
<h2 id="m134">Einsatz von Cookies</h2><p>Unter dem Begriff „Cookies" werden Funktionen, die Informationen auf Endgeräten der Nutzer speichern und aus ihnen auslesen, verstanden. Cookies können ferner in Bezug auf unterschiedliche Anliegen Einsatz finden, etwa zu Zwecken der Funktionsfähigkeit, der Sicherheit und des Komforts von Onlineangeboten sowie der Erstellung von Analysen der Besucherströme. Wir verwenden Cookies gemäß den gesetzlichen Vorschriften. Dazu holen wir, wenn erforderlich, vorab die Zustimmung der Nutzer ein. Ist eine Zustimmung nicht notwendig, setzen wir auf unsere berechtigten Interessen. Dies gilt, wenn das Speichern und Auslesen von Informationen unerlässlich ist, um ausdrücklich angeforderte Inhalte und Funktionen bereitstellen zu können. Dazu zählen etwa die Speicherung von Einstellungen sowie die Sicherstellung der Funktionalität und Sicherheit unseres Onlineangebots. Die Einwilligung kann jederzeit widerrufen werden. Wir informieren klar über deren Umfang und welche Cookies genutzt werden.</p>
<p><strong>Hinweise zu datenschutzrechtlichen Rechtsgrundlagen: </strong>Ob wir personenbezogene Daten mithilfe von Cookies verarbeiten, hängt von einer Einwilligung ab. Liegt eine Einwilligung vor, dient sie als Rechtsgrundlage. Ohne Einwilligung stützen wir uns auf unsere berechtigten Interessen, die vorstehend in diesem Abschnitt und im Kontext der jeweiligen Dienste und Verfahren erläutert sind.</p>
<p><strong>Speicherdauer:&nbsp;</strong>Im Hinblick auf die Speicherdauer werden die folgenden Arten von Cookies unterschieden:</p><ul><li><strong>Temporäre Cookies (auch: Session- oder Sitzungscookies):</strong> Temporäre Cookies werden spätestens gelöscht, nachdem ein Nutzer ein Onlineangebot verlassen und sein Endgerät (z.&nbsp;B. Browser oder mobile Applikation) geschlossen hat.</li><li><strong>Permanente Cookies:</strong> Permanente Cookies bleiben auch nach dem Schließen des Endgeräts gespeichert. So können beispielsweise der Log-in-Status gespeichert und bevorzugte Inhalte direkt angezeigt werden, wenn der Nutzer eine Website erneut besucht. Ebenso können die mithilfe von Cookies erhobenen Nutzerdaten zur Reichweitenmessung Verwendung finden. Sofern wir Nutzern keine expliziten Angaben zur Art und Speicherdauer von Cookies mitteilen (z.&nbsp;B. im Rahmen der Einholung der Einwilligung), sollten sie davon ausgehen, dass diese permanent sind und die Speicherdauer bis zu zwei Jahre betragen kann.</li></ul><p><strong>Allgemeine Hinweise zum Widerruf und Widerspruch (Opt-out):&nbsp;</strong>Nutzer können die von ihnen abgegebenen Einwilligungen jederzeit widerrufen und zudem einen Widerspruch gegen die Verarbeitung entsprechend den gesetzlichen Vorgaben, auch mittels der Privatsphäre-Einstellungen ihres Browsers, erklären.</p>
<ul class="m-elements"><li><strong>Verarbeitete Datenarten:</strong> Meta-, Kommunikations- und Verfahrensdaten (z. B. IP-Adressen, Zeitangaben, Identifikationsnummern, beteiligte Personen).</li><li><strong>Betroffene Personen:</strong> Nutzer (z.&nbsp;B. Webseitenbesucher, Nutzer von Onlinediensten).</li><li class=""><strong>Rechtsgrundlagen:</strong> Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO). Einwilligung (Art. 6 Abs. 1 S. 1 lit. a) DSGVO).</li></ul><p><strong>Weitere Hinweise zu Verarbeitungsprozessen, Verfahren und Diensten:</strong></p><ul class="m-elements"><li><strong>Verarbeitung von Cookie-Daten auf Grundlage einer Einwilligung: </strong>Wir setzen eine Einwilligungs-Management-Lösung ein, bei der die Einwilligung der Nutzer zur Verwendung von Cookies oder zu den im Rahmen der Einwilligungs-Management-Lösung genannten Verfahren und Anbietern eingeholt wird. Dieses Verfahren dient der Einholung, Protokollierung, Verwaltung und dem Widerruf von Einwilligungen, insbesondere bezogen auf den Einsatz von Cookies und vergleichbaren Technologien, die zur Speicherung, zum Auslesen und zur Verarbeitung von Informationen auf den Endgeräten der Nutzer eingesetzt werden. Im Rahmen dieses Verfahrens werden die Einwilligungen der Nutzer für die Nutzung von Cookies und die damit verbundenen Verarbeitungen von Informationen, einschließlich der im Einwilligungs-Management-Verfahren genannten spezifischen Verarbeitungen und Anbieter, eingeholt. Die Nutzer haben zudem die Möglichkeit, ihre Einwilligungen zu verwalten und zu widerrufen. Die Einwilligungserklärungen werden gespeichert, um eine erneute Abfrage zu vermeiden und den Nachweis der Einwilligung gemäß der gesetzlichen Anforderungen führen zu können. Die Speicherung erfolgt serverseitig und/oder in einem Cookie (sogenanntes Opt-In-Cookie) oder mittels vergleichbarer Technologien, um die Einwilligung einem spezifischen Nutzer oder dessen Gerät zuordnen zu können. Sofern keine spezifischen Angaben zu den Anbietern von Einwilligungs-Management-Diensten vorliegen, gelten folgende allgemeine Hinweise: Die Dauer der Speicherung der Einwilligung beträgt bis zu zwei Jahre. Dabei wird ein pseudonymer Nutzer-Identifikator erstellt, der zusammen mit dem Zeitpunkt der Einwilligung, den Angaben zum Umfang der Einwilligung (z.&nbsp;B. betreffende Kategorien von Cookies und/oder Diensteanbieter) sowie Informationen über den Browser, das System und das verwendete Endgerät gespeichert wird; <span class=""><strong>Rechtsgrundlagen:</strong> Einwilligung (Art. 6 Abs. 1 S. 1 lit. a) DSGVO).</span></li></ul>
<h2 id="m367">Registrierung, Anmeldung und Nutzerkonto</h2><p>Nutzer können ein Nutzerkonto anlegen. Im Rahmen der Registrierung werden den Nutzern die erforderlichen Pflichtangaben mitgeteilt und zu Zwecken der Bereitstellung des Nutzerkontos auf Grundlage vertraglicher Pflichterfüllung verarbeitet. Zu den verarbeiteten Daten gehören insbesondere die Login-Informationen (Nutzername, Passwort sowie eine E-Mail-Adresse).</p>
<p>Im Rahmen der Inanspruchnahme unserer Registrierungs- und Anmeldefunktionen sowie der Nutzung des Nutzerkontos speichern wir die IP-Adresse und den Zeitpunkt der jeweiligen Nutzerhandlung. Die Speicherung erfolgt auf Grundlage unserer berechtigten Interessen als auch jener der Nutzer an einem Schutz vor Missbrauch und sonstiger unbefugter Nutzung. Eine Weitergabe dieser Daten an Dritte erfolgt grundsätzlich nicht, es sei denn, sie ist zur Verfolgung unserer Ansprüche erforderlich oder es besteht eine gesetzliche Verpflichtung hierzu.</p>
<p>Die Nutzer können über Vorgänge, die für deren Nutzerkonto relevant sind, wie z.&nbsp;B. technische Änderungen, per E-Mail informiert werden.</p>
<ul class="m-elements"><li><strong>Verarbeitete Datenarten:</strong> Bestandsdaten (z.&nbsp;B. der vollständige Name, Wohnadresse, Kontaktinformationen, Kundennummer, etc.); Kontaktdaten (z.&nbsp;B. Post- und E-Mail-Adressen oder Telefonnummern); Inhaltsdaten (z. B. textliche oder bildliche Nachrichten und Beiträge sowie die sie betreffenden Informationen, wie z. B. Angaben zur Autorenschaft oder Zeitpunkt der Erstellung); Nutzungsdaten (z. B. Seitenaufrufe und Verweildauer, Klickpfade, Nutzungsintensität und -frequenz, verwendete Gerätetypen und Betriebssysteme, Interaktionen mit Inhalten und Funktionen). Protokolldaten (z.&nbsp;B. Logfiles betreffend Logins oder den Abruf von Daten oder Zugriffszeiten.).</li><li><strong>Betroffene Personen:</strong> Nutzer (z.&nbsp;B. Webseitenbesucher, Nutzer von Onlinediensten).</li><li><strong>Zwecke der Verarbeitung:</strong> Erbringung vertraglicher Leistungen und Erfüllung vertraglicher Pflichten; Sicherheitsmaßnahmen; Organisations- und Verwaltungsverfahren. Bereitstellung unseres Onlineangebotes und Nutzerfreundlichkeit.</li><li><strong>Aufbewahrung und Löschung:</strong> Löschung entsprechend Angaben im Abschnitt "Allgemeine Informationen zur Datenspeicherung und Löschung". Löschung nach Kündigung.</li><li class=""><strong>Rechtsgrundlagen:</strong> Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO). Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO).</li></ul><p><strong>Weitere Hinweise zu Verarbeitungsprozessen, Verfahren und Diensten:</strong></p><ul class="m-elements"><li><strong>Profile der Nutzer sind nicht öffentlich: </strong>Die Profile der Nutzer sind öffentlich nicht sichtbar und nicht zugänglich.</li><li><strong>Löschung von Daten nach Kündigung: </strong>Wenn Nutzer ihr Nutzerkonto gekündigt haben, werden deren Daten im Hinblick auf das Nutzerkonto, vorbehaltlich einer gesetzlichen Erlaubnis, Pflicht oder Einwilligung der Nutzer, gelöscht; <span class=""><strong>Rechtsgrundlagen:</strong> Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO).</span></li><li><strong>Keine Aufbewahrungspflicht für Daten: </strong>Es obliegt den Nutzern, ihre Daten bei erfolgter Kündigung vor dem Vertragsende zu sichern. Wir sind berechtigt, sämtliche während der Vertragsdauer gespeicherte Daten des Nutzers unwiederbringlich zu löschen; <span class=""><strong>Rechtsgrundlagen:</strong> Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO).</span></li></ul>
<h2 id="m451">Single-Sign-On-Anmeldung</h2><p>Als "Single-Sign-On" oder "Single-Sign-On-Anmeldung bzw. "-Authentifizierung" werden Verfahren bezeichnet, die es Nutzern erlauben, sich mit Hilfe eines Nutzerkontos bei einem Anbieter von Single-Sign-On-Verfahren (z.&nbsp;B. einem sozialen Netzwerk), auch bei unserem Onlineangebot, anzumelden. Voraussetzung der Single-Sign-On-Authentifizierung ist, dass die Nutzer bei dem jeweiligen Single-Sign-On-Anbieter registriert sind und die erforderlichen Zugangsdaten in dem dafür vorgesehenen Onlineformular eingeben, bzw. schon bei dem Single-Sign-On-Anbieter angemeldet sind und die Single-Sign-On-Anmeldung via Schaltfläche bestätigen.</p>
<p>Die Authentifizierung erfolgt direkt bei dem jeweiligen Single-Sign-On-Anbieter. Im Rahmen einer solchen Authentifizierung erhalten wir eine Nutzer-ID mit der Information, dass der Nutzer unter dieser Nutzer-ID beim jeweiligen Single-Sign-On-Anbieter eingeloggt ist und eine für uns für andere Zwecke nicht weiter nutzbare ID (sog "User Handle"). Ob uns zusätzliche Daten übermittelt werden, hängt allein von dem genutzten Single-Sign-On-Verfahren ab, von den gewählten Datenfreigaben im Rahmen der Authentifizierung und zudem davon, welche Daten Nutzer in den Privatsphäre- oder sonstigen Einstellungen des Nutzerkontos beim Single-Sign-On-Anbieter freigegeben haben. Es können je nach Single-Sign-On-Anbieter und der Wahl der Nutzer verschiedene Daten sein, in der Regel sind es die E-Mail-Adresse und der Benutzername. Das im Rahmen des Single-Sign-On-Verfahrens eingegebene Passwort bei dem Single-Sign-On-Anbieter ist für uns weder einsehbar, noch wird es von uns gespeichert. </p>
<p>Die Nutzer werden gebeten, zu beachten, dass deren bei uns gespeicherte Angaben automatisch mit ihrem Nutzerkonto beim Single-Sign-On-Anbieter abgeglichen werden können, dies jedoch nicht immer möglich ist oder tatsächlich erfolgt. Ändern sich z.&nbsp;B. die E-Mail-Adressen der Nutzer, müssen sie diese manuell in ihrem Nutzerkonto bei uns ändern.</p>
<p>Die Single-Sign-On-Anmeldung können wir, sofern mit den Nutzern vereinbart, im Rahmen der oder vor der Vertragserfüllung einsetzen, soweit die Nutzer darum gebeten wurden, im Rahmen einer Einwilligung verarbeiten und setzen sie ansonsten auf Grundlage der berechtigten Interessen unsererseits und der Interessen der Nutzer an einem effektiven und sicheren Anmeldesystem ein.</p>
<p>Sollten Nutzer sich einmal entscheiden, die Verknüpfung ihres Nutzerkontos beim Single-Sign-On-Anbieter nicht mehr für das Single-Sign-On-Verfahren nutzen zu wollen, müssen sie diese Verbindung innerhalb ihres Nutzerkontos beim Single-Sign-On-Anbieter aufheben. Möchten Nutzer deren Daten bei uns löschen, müssen sie ihre Registrierung bei uns kündigen.</p>
<ul class="m-elements"><li><strong>Verarbeitete Datenarten:</strong> Bestandsdaten (z.&nbsp;B. der vollständige Name, Wohnadresse, Kontaktinformationen, Kundennummer, etc.); Kontaktdaten (z.&nbsp;B. Post- und E-Mail-Adressen oder Telefonnummern); Nutzungsdaten (z. B. Seitenaufrufe und Verweildauer, Klickpfade, Nutzungsintensität und -frequenz, verwendete Gerätetypen und Betriebssysteme, Interaktionen mit Inhalten und Funktionen). Meta-, Kommunikations- und Verfahrensdaten (z. B. IP-Adressen, Zeitangaben, Identifikationsnummern, beteiligte Personen).</li><li><strong>Betroffene Personen:</strong> Nutzer (z.&nbsp;B. Webseitenbesucher, Nutzer von Onlinediensten).</li><li><strong>Zwecke der Verarbeitung:</strong> Erbringung vertraglicher Leistungen und Erfüllung vertraglicher Pflichten; Sicherheitsmaßnahmen; Anmeldeverfahren. Bereitstellung unseres Onlineangebotes und Nutzerfreundlichkeit.</li><li><strong>Aufbewahrung und Löschung:</strong> Löschung entsprechend Angaben im Abschnitt "Allgemeine Informationen zur Datenspeicherung und Löschung". Löschung nach Kündigung.</li><li class=""><strong>Rechtsgrundlagen:</strong> Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO). Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO).</li></ul><p><strong>Weitere Hinweise zu Verarbeitungsprozessen, Verfahren und Diensten:</strong></p><ul class="m-elements"><li><strong>Apple Single-Sign-On: </strong>Authentifizierungsdienste für Nutzeranmeldungen, Bereitstellung von Single Sign-On-Funktionen, Verwaltung von Identitätsinformationen und Anwendungsintegrationen; <strong>Dienstanbieter:</strong> Apple Inc., Infinite Loop, Cupertino, CA 95014, USA; <span class=""><strong>Rechtsgrundlagen:</strong> Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO); </span><strong>Website:</strong> <a href="https://www.apple.com/de/" target="_blank">https://www.apple.com/de/</a>. <strong>Datenschutzerklärung:</strong> <a href="https://www.apple.com/legal/privacy/de-ww/" target="_blank">https://www.apple.com/legal/privacy/de-ww/</a>.</li><li><strong>Google Single-Sign-On: </strong>Authentifizierungsdienste für Nutzeranmeldungen, Bereitstellung von Single Sign-On-Funktionen, Verwaltung von Identitätsinformationen und Anwendungsintegrationen; <strong>Dienstanbieter:</strong> Google Ireland Limited, Gordon House, Barrow Street, Dublin 4, Irland; <span class=""><strong>Rechtsgrundlagen:</strong> Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO); </span><strong>Website:</strong> <a href="https://www.google.de" target="_blank">https://www.google.de</a>; <strong>Datenschutzerklärung:</strong> <a href="https://policies.google.com/privacy" target="_blank">https://policies.google.com/privacy</a>; <strong>Grundlage Drittlandtransfers:</strong> Data Privacy Framework (DPF). <strong>Widerspruchsmöglichkeit (Opt-Out):</strong> Einstellungen für die Darstellung von Werbeeinblendungen: <a href="https://myadcenter.google.com/" target="_blank">https://myadcenter.google.com/</a>.</li></ul>
<h2 id="m182">Kontakt- und Anfrageverwaltung</h2><p>Bei der Kontaktaufnahme mit uns (z.&nbsp;B. per Post, Kontaktformular, E-Mail, Telefon oder via soziale Medien) sowie im Rahmen bestehender Nutzer- und Geschäftsbeziehungen werden die Angaben der anfragenden Personen verarbeitet, soweit dies zur Beantwortung der Kontaktanfragen und etwaiger angefragter Maßnahmen erforderlich ist.</p>
<ul class="m-elements"><li><strong>Verarbeitete Datenarten:</strong> Bestandsdaten (z.&nbsp;B. der vollständige Name, Wohnadresse, Kontaktinformationen, Kundennummer, etc.); Kontaktdaten (z.&nbsp;B. Post- und E-Mail-Adressen oder Telefonnummern); Inhaltsdaten (z. B. textliche oder bildliche Nachrichten und Beiträge sowie die sie betreffenden Informationen, wie z. B. Angaben zur Autorenschaft oder Zeitpunkt der Erstellung); Nutzungsdaten (z. B. Seitenaufrufe und Verweildauer, Klickpfade, Nutzungsintensität und -frequenz, verwendete Gerätetypen und Betriebssysteme, Interaktionen mit Inhalten und Funktionen). Meta-, Kommunikations- und Verfahrensdaten (z. B. IP-Adressen, Zeitangaben, Identifikationsnummern, beteiligte Personen).</li><li><strong>Betroffene Personen:</strong> Kommunikationspartner.</li><li><strong>Zwecke der Verarbeitung:</strong> Kommunikation; Organisations- und Verwaltungsverfahren; Feedback (z.&nbsp;B. Sammeln von Feedback via Online-Formular). Bereitstellung unseres Onlineangebotes und Nutzerfreundlichkeit.</li><li><strong>Aufbewahrung und Löschung:</strong> Löschung entsprechend Angaben im Abschnitt "Allgemeine Informationen zur Datenspeicherung und Löschung".</li><li class=""><strong>Rechtsgrundlagen:</strong> Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO). Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO).</li></ul><p><strong>Weitere Hinweise zu Verarbeitungsprozessen, Verfahren und Diensten:</strong></p><ul class="m-elements"><li><strong>Kontaktformular: </strong>Bei Kontaktaufnahme über unser Kontaktformular, per E-Mail oder anderen Kommunikationswegen, verarbeiten wir die uns übermittelten personenbezogenen Daten zur Beantwortung und Bearbeitung des jeweiligen Anliegens. Dies umfasst in der Regel Angaben wie Name, Kontaktinformationen und gegebenenfalls weitere Informationen, die uns mitgeteilt werden und zur angemessenen Bearbeitung erforderlich sind. Wir nutzen diese Daten ausschließlich für den angegebenen Zweck der Kontaktaufnahme und Kommunikation; <span class=""><strong>Rechtsgrundlagen:</strong> Vertragserfüllung und vorvertragliche Anfragen (Art. 6 Abs. 1 S. 1 lit. b) DSGVO), Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO).</span></li></ul>
<h2 id="m1643">Push-Nachrichten</h2><p>Mit der Zustimmung der Nutzer, können wir den Nutzern so genannte "Push-Benachrichtigungen" zusenden. Dabei handelt es sich um Nachrichten, die auf den Bildschirmen, Endgeräten oder in Browsern der Nutzer angezeigt werden, auch wenn unser Onlinedienst gerade nicht aktiv genutzt wird. </p>
<p>Um sich für die Push-Nachrichten anzumelden, müssen Nutzer die Abfrage ihres Browsers bzw. Endgerätes zum Erhalt der Push-Nachrichten bestätigen. Dieser Zustimmungsprozess wird dokumentiert und gespeichert. Die Speicherung ist erforderlich, um zu erkennen, ob Nutzer dem Empfang der Push-Nachrichten zugestimmt haben sowie um die Zustimmung nachweisen zu können. Zu diesen Zwecken wird ein pseudonymer Identifikator des Browsers (sog. "Push-Token") oder die Geräte-ID eines Endgerätes gespeichert.</p>
<p>Die Push-Nachrichten können zum einen für die Erfüllung von vertraglichen Pflichten erforderlich sein (z.&nbsp;B. für die Nutzung unseres Onlineangebotes relevante technische und organisatorische Informationen) und<span class="dsg-license-content-blurred de dsg-ttip-activate" title="Bitte erwerben Sie eine Lizenz, um die Texte freizuschalten."> - Dieser Textbereich muss mit einer Premium Lizenz freischaltet werden. - premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext </span></p>
<ul class="m-elements"><li><strong>Verarbeitete Datenarten:</strong> Nutzungsdaten (z. B. Seitenaufrufe und Verweildauer, Klickpfade, Nutzungsintensität und -frequenz, verwendete Gerätetypen und Betriebssysteme, Interaktionen mit<span class="dsg-license-content-blurred de dsg-ttip-activate" title="Bitte erwerben Sie eine Lizenz, um die Texte freizuschalten."> - Dieser Textbereich muss mit einer Premium Lizenz freischaltet werden. - premiumtext premiumtext premiumtext premiumtext premiumtext </span>). Meta-, Kommunikations- und Verfahrensdaten (z. B. IP-Adressen, Zeitangaben, Identifikationsnummern, beteiligte<span class="dsg-license-content-blurred de dsg-ttip-activate" title="Bitte erwerben Sie eine Lizenz, um die Texte freizuschalten."> - Dieser Textbereich muss mit einer Premium Lizenz freischaltet werden. - premiumtext premiumtext premiumtext </span>).</li><li><strong>Betroffene Personen:</strong> Kommunikationspartner.</li><li><strong>Zwecke der Verarbeitung:</strong> Kommunikation. Bereitstellung unseres Onlineangebotes und Nutzerfreundlichkeit.</li><li><strong>Aufbewahrung und Löschung:</strong> Löschung entsprechend Angaben im Abschnitt "Allgemeine Informationen zur Datenspeicherung und Löschung". Löschung nach Kündigung.</li><li class=""><strong>Rechtsgrundlagen:</strong> Einwilligung (Art. 6 Abs. 1 S. 1 lit. a) DSGVO). Berechtigte Interessen (Art. 6 Abs. 1 S. 1 lit. f) DSGVO).</li></ul>
<h2 id="m15">Änderung und Aktualisierung</h2><p>Wir bitten Sie, sich regelmäßig über den Inhalt unserer Datenschutzerklärung zu informieren. Wir passen die Datenschutzerklärung an, sobald die Änderungen der von uns durchgeführten Datenverarbeitungen dies erforderlich machen. Wir informieren Sie, sobald durch die Änderungen eine Mitwirkungshandlung Ihrerseits (z.&nbsp;B. Einwilligung) oder eine sonstige individuelle Benachrichtigung erforderlich wird.</p>
<p>Sofern wir in dieser Datenschutzerklärung Adressen und Kontaktinformationen von Unternehmen und Organisationen angeben, bitten wir zu beachten, dass die Adressen sich über die Zeit ändern können und bitten die Angaben vor Kontaktaufnahme zu prüfen.</p>

<h2 id="m42">Begriffsdefinitionen</h2><p>In diesem Abschnitt erhalten Sie eine Übersicht über die in dieser Datenschutzerklärung verwendeten Begrifflichkeiten. Soweit die Begrifflichkeiten gesetzlich definiert sind, gelten deren gesetzliche Definitionen. Die nachfolgenden Erläuterungen sollen dagegen vor allem dem Verständnis dienen.</p>
 <ul class="glossary"><li><strong>Bestandsdaten:</strong> Bestandsdaten umfassen wesentliche Informationen, die für die Identifikation und Verwaltung von Vertragspartnern, Benutzerkonten, Profilen und ähnlichen Zuordnungen notwendig sind. Diese Daten können u.a. persönliche und demografische Angaben wie Namen, Kontaktinformationen (Adressen, Telefonnummern, E-Mail-Adressen), Geburtsdaten und spezifische Identifikatoren (Benutzer-IDs) beinhalten. Bestandsdaten bilden die Grundlage für jegliche formelle Interaktion zwischen Personen und Diensten, Einrichtungen oder Systemen, indem sie eine eindeutige Zuordnung und Kommunikation ermöglichen. </li><li><strong>Inhaltsdaten:</strong> Inhaltsdaten umfassen Informationen, die im Zuge der Erstellung, Bearbeitung und Veröffentlichung von Inhalten aller Art generiert werden. Diese Kategorie von Daten kann Texte, Bilder, Videos, Audiodateien und andere multimediale Inhalte einschließen, die auf verschiedenen Plattformen und Medien veröffentlicht werden. Inhaltsdaten sind nicht nur auf den eigentlichen Inhalt beschränkt, sondern beinhalten auch Metadaten, die Informationen über den Inhalt selbst liefern, wie Tags, Beschreibungen, Autoreninformationen und Veröffentlichungsdaten </li><li><strong>Kontaktdaten:</strong> Kontaktdaten sind essentielle Informationen, die die Kommunikation mit Personen oder Organisationen ermöglichen. Sie umfassen u.a. Telefonnummern, postalische Adressen und E-Mail-Adressen, sowie Kommunikationsmittel wie soziale Medien-Handles und Instant-Messaging-Identifikatoren. </li><li><strong>Meta-, Kommunikations- und Verfahrensdaten:</strong> Meta-, Kommunikations- und Verfahrensdaten sind Kategorien, die Informationen über die Art und Weise enthalten, wie Daten verarbeitet, übermittelt und verwaltet werden. Meta-Daten, auch bekannt als Daten über Daten, umfassen Informationen, die den Kontext, die Herkunft und die Struktur anderer Daten beschreiben. Sie können Angaben zur Dateigröße, dem Erstellungsdatum, dem Autor eines Dokuments und den Änderungshistorien beinhalten. Kommunikationsdaten erfassen den Austausch von Informationen zwischen Nutzern über verschiedene Kanäle, wie E-Mail-Verkehr, Anrufprotokolle, Nachrichten in sozialen Netzwerken und Chat-Verläufe, inklusive der beteiligten Personen, Zeitstempel und Übertragungswege. Verfahrensdaten beschreiben die Prozesse und Abläufe innerhalb von Systemen oder Organisationen, einschließlich Workflow-Dokumentationen, Protokolle von Transaktionen und Aktivitäten, sowie Audit-Logs, die zur Nachverfolgung und Überprüfung von Vorgängen verwendet werden. </li><li><strong>Nutzungsdaten:</strong> Nutzungsdaten beziehen sich auf Informationen, die erfassen, wie Nutzer mit digitalen Produkten, Dienstleistungen oder Plattformen interagieren. Diese Daten umfassen eine breite Palette von Informationen, die aufzeigen, wie Nutzer Anwendungen nutzen, welche Funktionen sie bevorzugen, wie lange sie auf bestimmten Seiten verweilen und über welche Pfade sie durch eine Anwendung navigieren. Nutzungsdaten können auch die Häufigkeit der Nutzung, Zeitstempel von Aktivitäten, IP-Adressen, Geräteinformationen und Standortdaten einschließen. Sie sind besonders wertvoll für die Analyse des Nutzerverhaltens, die Optimierung von Benutzererfahrungen, das Personalisieren von Inhalten und das Verbessern von Produkten oder Dienstleistungen. Darüber hinaus spielen Nutzungsdaten eine entscheidende Rolle beim Erkennen von Trends, Vorlieben und möglichen Problembereichen innerhalb digitaler Angebote </li><li><strong>Personenbezogene Daten:</strong> "Personenbezogene Daten" sind alle Informationen, die sich auf eine identifizierte oder identifizierbare natürliche Person (im Folgenden "betroffene Person") beziehen; als identifizierbar wird eine natürliche Person angesehen, die direkt oder indirekt, insbesondere mittels Zuordnung zu einer Kennung wie einem Namen, zu einer Kennnummer, zu Standortdaten, zu einer Online-Kennung (z.&nbsp;B. Cookie) oder zu einem oder mehreren besonderen Merkmalen identifiziert werden kann, die Ausdruck der physischen, physiologischen, genetischen, psychischen, wirtschaftlichen, kulturellen oder sozialen Identität dieser natürlichen Person sind. </li><li><strong>Protokolldaten:</strong> Protokolldaten sind Informationen über Ereignisse oder Aktivitäten, die in einem System oder Netzwerk protokolliert wurden. Diese Daten enthalten typischerweise Informationen wie Zeitstempel, IP-Adressen, Benutzeraktionen, Fehlermeldungen und andere Details über die Nutzung oder den Betrieb eines Systems. Protokolldaten werden oft zur Analyse von Systemproblemen, zur Sicherheitsüberwachung oder zur Erstellung von Leistungsberichten verwendet. </li><li><strong>Verantwortlicher:</strong> Als "Verantwortlicher" wird die natürliche oder juristische Person, Behörde, Einrichtung oder andere Stelle, die allein oder gemeinsam mit anderen über die Zwecke und Mittel der Verarbeitung von personenbezogenen Daten entscheidet, bezeichnet. </li><li><strong>Verarbeitung:</strong> "Verarbeitung" ist jeder mit oder ohne Hilfe automatisierter Verfahren ausgeführte Vorgang oder jede solche Vorgangsreihe im Zusammenhang mit personenbezogenen Daten. Der Begriff reicht weit und umfasst praktisch jeden Umgang mit Daten, sei es das Erheben, das Auswerten, das Speichern, das Übermitteln oder das Löschen. </li><li><strong>Vertragsdaten:</strong> Vertragsdaten sind spezifische Informationen, die sich auf die Formalisierung einer Vereinbarung zwischen zwei oder mehr Parteien beziehen. Sie dokumentieren die Bedingungen, unter denen Dienstleistungen oder Produkte bereitgestellt, getauscht oder verkauft werden. Diese Datenkategorie ist wesentlich für die Verwaltung und Erfüllung vertraglicher Verpflichtungen und umfasst sowohl die Identifikation der Vertragsparteien als auch die spezifischen Bedingungen und Konditionen der Vereinbarung. Vertragsdaten können Start- und Enddaten des Vertrages, die Art der vereinbarten Leistungen oder Produkte, Preisvereinbarungen, Zahlungsbedingungen, Kündigungsrechte, Verlängerungsoptionen und spezielle Bedingungen oder Klauseln umfassen. Sie dienen als rechtliche Grundlage für die Beziehung zwischen den Parteien und sind entscheidend für die Klärung von Rechten und Pflichten, die Durchsetzung von Ansprüchen und die Lösung von Streitigkeiten. </li><li><strong>Zahlungsdaten:</strong> Zahlungsdaten umfassen sämtliche Informationen, die zur Abwicklung von Zahlungstransaktionen zwischen Käufern und Verkäufern benötigt werden. Diese Daten sind von entscheidender Bedeutung für den elektronischen Handel, das Online-Banking und jede andere Form der finanziellen Transaktion. Sie beinhalten Details wie Kreditkartennummern, Bankverbindungen, Zahlungsbeträge, Transaktionsdaten, Verifizierungsnummern und Rechnungsinformationen. Zahlungsdaten können auch Informationen über den Zahlungsstatus, Rückbuchungen, Autorisierungen und Gebühren enthalten. </li></ul><p class="seal"><a href="https://datenschutz-generator.de/" title="Rechtstext von Dr. Schwenke - für weitere Informationen bitte anklicken." target="_blank" rel="noopener noreferrer nofollow">Erstellt mit kostenlosem Datenschutz-Generator.de von Dr. Thomas Schwenke</a></p>
"""
    

    static let privacy_en_html: String = """
    <h1>Privacy Policy</h1>
    <h2 id="m716">Preamble</h2>
    <p>With the following Privacy Policy, we would like to inform you which types of your personal data (hereinafter also referred to simply as “data”) we process for which purposes and to what extent. This Privacy Policy applies to all processing of personal data carried out by us, both in the context of providing our services and—in particular—on our websites, in mobile applications, and within external online presences, such as our social media profiles (collectively referred to as the “online offering”).</p>
    <p>The terms used are intended to be gender-neutral.</p>

    <p>Last updated: 25 October 2025</p>
    <h2>Table of contents</h2>
    <ul class="index">
      <li><a class="index-link" href="#m716">Preamble</a></li>
      <li><a class="index-link" href="#m3">Controller</a></li>
      <li><a class="index-link" href="#mOverview">Overview of Processing</a></li>
      <li><a class="index-link" href="#m2427">Relevant Legal Bases</a></li>
      <li><a class="index-link" href="#m25">Disclosure of Personal Data</a></li>
      <li><a class="index-link" href="#m24">International Data Transfers</a></li>
      <li><a class="index-link" href="#m12">General Information on Data Retention and Deletion</a></li>
      <li><a class="index-link" href="#m10">Rights of Data Subjects</a></li>
      <li><a class="index-link" href="#m317">Business Services</a></li>
      <li><a class="index-link" href="#m225">Provision of the Online Offering and Web Hosting</a></li>
      <li><a class="index-link" href="#m134">Use of Cookies</a></li>
      <li><a class="index-link" href="#m367">Registration, Login and User Account</a></li>
      <li><a class="index-link" href="#m451">Single-Sign-On Login</a></li>
      <li><a class="index-link" href="#m182">Contact and Request Management</a></li>
      <li><a class="index-link" href="#m1643">Push Notifications</a></li>
      <li><a class="index-link" href="#m15">Changes and Updates</a></li>
      <li><a class="index-link" href="#m42">Definitions</a></li>
    </ul>

    <h2 id="m3">Controller</h2>
    <p>Benedikt Purkott<br>c/o Block Services<br>Stuttgarter Str. 106<br>70736 Fellbach<br>Germany</p>
    <p>Email: <a href="mailto:movobp.contact@gmail.com">movobp.contact@gmail.com</a></p>

    <h2 id="mOverview">Overview of Processing</h2>
    <p>The following overview summarizes the types of data processed and the purposes of processing, and refers to the categories of data subjects.</p>

    <h3>Types of Data Processed</h3>
    <ul>
      <li>Inventory data.</li>
      <li>Payment data.</li>
      <li>Contact data.</li>
      <li>Content data.</li>
      <li>Contract data.</li>
      <li>Usage data.</li>
      <li>Meta, communication and procedural data.</li>
      <li>Log data.</li>
    </ul>

    <h3>Categories of Data Subjects</h3>
    <ul>
      <li>Service recipients and clients.</li>
      <li>Prospective parties.</li>
      <li>Communication partners.</li>
      <li>Users.</li>
      <li>Business and contractual partners.</li>
    </ul>

    <h3>Purposes of Processing</h3>
    <ul>
      <li>Provision of contractual services and performance of contractual obligations.</li>
      <li>Communication.</li>
      <li>Security measures.</li>
      <li>Office and organizational procedures.</li>
      <li>Organizational and administrative procedures.</li>
      <li>Feedback.</li>
      <li>Login procedures.</li>
      <li>Provision of our online offering and user-friendliness.</li>
      <li>Information technology infrastructure.</li>
      <li>Business processes and commercial procedures.</li>
    </ul>

    <h2 id="m2427">Relevant Legal Bases</h2>
    <p><strong>Legal bases under the GDPR:</strong> The following provides an overview of the legal bases of the GDPR on which we process personal data. Please note that, in addition to the GDPR, national data protection provisions may apply in your or our country of residence or domicile. If, in an individual case, more specific legal bases are relevant, we will inform you of these in this Privacy Policy.</p>
    <ul>
      <li><strong>Consent (Art. 6(1)(a) GDPR)</strong> – The data subject has given consent to the processing of their personal data for one or more specific purposes.</li>
      <li><strong>Performance of a contract and pre-contractual inquiries (Art. 6(1)(b) GDPR)</strong> – Processing is necessary for the performance of a contract to which the data subject is party, or in order to take steps at the request of the data subject prior to entering into a contract.</li>
      <li><strong>Legal obligation (Art. 6(1)(c) GDPR)</strong> – Processing is necessary for compliance with a legal obligation to which the controller is subject.</li>
      <li><strong>Legitimate interests (Art. 6(1)(f) GDPR)</strong> – Processing is necessary for the purposes of the legitimate interests pursued by the controller or by a third party, except where such interests are overridden by the interests or fundamental rights and freedoms of the data subject which require protection of personal data.</li>
    </ul>
    <p><strong>National data protection rules in Germany:</strong> In addition to the GDPR, national data protection rules apply in Germany, particularly the Federal Data Protection Act (BDSG). The BDSG contains special provisions on the right of access, the right to erasure, the right to object, the processing of special categories of data, processing for other purposes, and transfers as well as automated decision-making including profiling. State data protection laws of the individual German federal states may also apply.</p>
    <p><strong>Note on applicability of the GDPR and the Swiss FADP:</strong> These privacy notices serve both to provide information under the Swiss Federal Act on Data Protection (FADP) and under the GDPR. For broader applicability and clarity, GDPR terminology is used (e.g., “processing” of “personal data”, “legitimate interest”, “special categories of data”) instead of the FADP terms. The legal meaning of the terms remains determined by the FADP where it applies.</p>

    <h2 id="m25">Disclosure of Personal Data</h2>
    <p>In the course of processing personal data, it may occur that such data are disclosed to or transferred to other entities, companies, legally independent organizational units, or persons. Recipients of this data may include, for example, service providers commissioned with IT tasks, or providers of services and content that are embedded in a website. In such cases, we comply with legal requirements and, in particular, conclude contracts or agreements with the recipients of your data that serve to protect your data.</p>

    <h2 id="m24">International Data Transfers</h2>
    <p><strong>Processing in third countries:</strong> If we transfer data to a third country (i.e., outside the European Union (EU) or the European Economic Area (EEA)) or this occurs in the context of using services of third parties or disclosure/transfer of data to other persons, bodies, or companies (recognizable, for example, from the provider’s postal address or an explicit note in this Privacy Policy), such transfer is always in compliance with legal requirements.</p>
    <p>For transfers to the United States, we primarily rely on the Data Privacy Framework (DPF), recognized by an EU Commission adequacy decision on 10 July 2023. In addition, we have concluded Standard Contractual Clauses (SCCs) with the respective providers that meet the EU Commission’s requirements and set contractual obligations to protect your data.</p>
    <p>This dual approach ensures comprehensive protection of your data: the DPF forms the primary safeguard, while the SCCs provide an additional safety net. Should changes affect the DPF, the SCCs act as a reliable fallback to ensure your data remain adequately protected despite any political or legal developments.</p>
    <p>For each provider, we indicate whether they are certified under the DPF and whether SCCs are in place. Further information on the DPF and a list of certified companies can be found on the U.S. Department of Commerce website at <a href="https://www.dataprivacyframework.gov/" target="_blank">https://www.dataprivacyframework.gov/</a> (in English).</p>
    <p>For transfers to other third countries, appropriate safeguards apply, in particular SCCs, explicit consent, or transfers required by law. Information on third-country transfers and adequacy decisions can be found on the European Commission’s website: <a href="https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection_en?prefLang=de" target="_blank">international dimension of data protection</a>.</p>

    <h2 id="m12">General Information on Data Retention and Deletion</h2>
    <p>We delete personal data we process in accordance with legal requirements as soon as the underlying consents are withdrawn or there is no other legal basis for processing. This includes cases where the original purpose of processing no longer applies or the data are no longer needed. Exceptions exist if statutory obligations or specific interests require longer storage or archiving.</p>
    <p>In particular, data that must be retained for commercial or tax reasons, or whose storage is necessary for legal prosecution or to protect the rights of other natural or legal persons, must be archived accordingly.</p>
    <p>Our privacy notices may contain additional information on retention and deletion that applies to specific processing operations.</p>
    <p>If multiple retention or deletion periods are stated for a data item, the longest period applies. Data that are no longer processed for the original purpose but are stored due to legal requirements or other reasons are processed solely for the reasons that justify their retention.</p>
    <p><strong>Retention and deletion periods under German law (general guide):</strong></p>
    <ul>
      <li><strong>10 years</strong> – Retention for books and records, annual financial statements, inventories, management reports, opening balance sheet, and related organizational documents (§ 147(1) no. 1 in conjunction with (3) AO, § 14b(1) UStG, § 257(1) no. 1 in conjunction with (4) HGB).</li>
      <li><strong>8 years</strong> – Accounting vouchers such as invoices and cost receipts (§ 147(1) nos. 4 and 4a in conjunction with (3) sentence 1 AO; § 257(1) no. 4 in conjunction with (4) HGB).</li>
      <li><strong>6 years</strong> – Other business documents: received and sent business letters, other documents relevant for taxation (e.g., timesheets, cost accounting sheets, calculation documents, price labels), as well as payroll documents where not already accounting vouchers, and cash register strips (§ 147(1) nos. 2, 3, 5 in conjunction with (3) AO; § 257(1) nos. 2 and 3 in conjunction with (4) HGB).</li>
      <li><strong>3 years</strong> – Data needed to consider potential warranty and damage claims or similar contractual claims and rights and to handle related inquiries, based on prior experience and industry practice; standard limitation period (§§ 195, 199 BGB).</li>
    </ul>
    <p><strong>Commencement of periods at year-end:</strong> If a period does not explicitly begin on a certain date and is at least one year, it begins automatically at the end of the calendar year in which the triggering event occurred. For ongoing contractual relationships, the triggering event is the effective date of termination or other end of the legal relationship.</p>

    <h2 id="m10">Rights of Data Subjects</h2>
    <p><strong>Rights under the GDPR:</strong> As a data subject, you have various rights under the GDPR, in particular those arising from Articles 15 to 21 GDPR:</p>
    <ul>
      <li><strong>Right to object:</strong> You have the right, on grounds relating to your particular situation, to object at any time to the processing of personal data concerning you based on Article 6(1)(e) or (f) GDPR; this also applies to profiling based on these provisions. Where personal data are processed for direct marketing purposes, you have the right to object at any time to processing for such marketing, including profiling related to such direct marketing.</li>
      <li><strong>Right to withdraw consent:</strong> You have the right to withdraw consent at any time.</li>
      <li><strong>Right of access:</strong> You have the right to obtain confirmation as to whether or not personal data concerning you are being processed, and access to the data and further information and a copy of the data as provided by law.</li>
      <li><strong>Right to rectification:</strong> You have the right to request completion of data concerning you or rectification of inaccurate data in accordance with legal requirements.</li>
      <li><strong>Right to erasure and restriction of processing:</strong> You have the right to request that data concerning you be erased without undue delay, or alternatively to request restriction of processing in accordance with legal requirements.</li>
      <li><strong>Right to data portability:</strong> You have the right to receive the data concerning you which you have provided to us, in a structured, commonly used and machine-readable format, or to request transmission to another controller, as provided by law.</li>
      <li><strong>Right to lodge a complaint with a supervisory authority:</strong> Without prejudice to any other administrative or judicial remedy, you have the right to lodge a complaint with a supervisory authority, in particular in the Member State of your habitual residence, place of work or place of the alleged infringement, if you consider that the processing of personal data relating to you infringes the GDPR.</li>
    </ul>

    <h2 id="m317">Business Services</h2>
    <p>We process data of our contractual and business partners, e.g., customers and prospects (collectively “contracting partners”), within the scope of contractual and comparable legal relationships, including related measures and communication (including pre-contractual), for example to respond to inquiries.</p>
    <p>We use this data to fulfill our contractual obligations. This includes, in particular, the duty to provide the agreed services, any update duties, and remedying warranty and performance issues. We also use the data to safeguard our rights and for associated administrative tasks and corporate organization. In addition, we process the data based on our legitimate interests in proper and efficient business management and in security measures to protect our contracting partners and our operations against misuse and risks to their data, secrets, information and rights (e.g., involving telecommunications, transport and other auxiliary services, subcontractors, banks, tax and legal advisors, payment service providers, or tax authorities). In accordance with applicable law, we only disclose contracting partner data to third parties to the extent necessary for the aforementioned purposes or to meet legal obligations. We inform contracting partners about further forms of processing, such as for marketing, within this Privacy Policy.</p>
    <p>We inform contracting partners which data are required before or during collection, e.g., in online forms, via specific labels (e.g., colors) or symbols (e.g., asterisks), or personally.</p>
    <p>We delete the data after expiry of statutory warranty and comparable obligations, generally after four years, unless the data are stored in a customer account (e.g., where they must be retained for statutory reasons—typically ten years for tax). Data disclosed to us by a contracting partner within an order are deleted in accordance with the specifications and generally after the end of the order.</p>
    <ul class="m-elements">
      <li><strong>Data types processed:</strong> Inventory data; payment data; contact data; contract data.</li>
      <li><strong>Data subjects:</strong> Service recipients and clients; prospects; business and contractual partners.</li>
      <li><strong>Purposes of processing:</strong> Provision of contractual services and obligations; communication; office and organizational procedures; organizational and administrative procedures; business processes and commercial procedures.</li>
      <li><strong>Retention and deletion:</strong> Deletion as stated in “General Information on Data Retention and Deletion”.</li>
      <li><strong>Legal bases:</strong> Contract performance and pre-contractual inquiries (Art. 6(1)(b) GDPR); legal obligation (Art. 6(1)(c) GDPR); legitimate interests (Art. 6(1)(f) GDPR).</li>
    </ul>
    <p><strong>Further notes on processes, procedures and services:</strong></p>
    <ul class="m-elements">
      <li><strong>Provision of software and platform services:</strong> We process data of our users, registered and test users (“users”) to provide our contractual services and, based on legitimate interests, to ensure security and further develop our offering. Required information is identified as such during ordering/contract conclusion and includes data necessary for service provision and billing, as well as contact details for follow-up; <strong>Legal basis:</strong> Art. 6(1)(b) GDPR.</li>
    </ul>

    <h2 id="m225">Provision of the Online Offering and Web Hosting</h2>
    <p>We process users’ data to provide our online services. For this purpose, we process users’ IP addresses, which are necessary to transmit the content and functions of our online services to the users’ browser or device.</p>
    <ul class="m-elements">
      <li><strong>Data types processed:</strong> Usage data; meta, communication and procedural data; log data.</li>
      <li><strong>Data subjects:</strong> Users (e.g., website visitors, users of online services).</li>
      <li><strong>Purposes of processing:</strong> Provision of our online offering and user-friendliness; IT infrastructure (operation and provision of information systems and technical equipment); security measures.</li>
      <li><strong>Retention and deletion:</strong> Deletion as stated in “General Information on Data Retention and Deletion”.</li>
      <li><strong>Legal basis:</strong> Legitimate interests (Art. 6(1)(f) GDPR).</li>
    </ul>
    <p><strong>Further notes on processes, procedures and services:</strong></p>
    <ul class="m-elements">
      <li><strong>Online offering on rented infrastructure:</strong> We use storage, computing capacity and software from a server provider (“web host”) to provide our online offering; <strong>Legal basis:</strong> Art. 6(1)(f) GDPR.</li>
      <li><strong>Access data and log files:</strong> Access to our online offering is logged in server log files (e.g., addresses and names of pages/files retrieved, date and time, transferred data volumes, retrieval success, browser type/version, operating system, referrer URL, IP address, and requesting provider). Server log files serve security purposes (e.g., preventing server overload from DDoS attacks) and ensuring server utilization and stability; <strong>Legal basis:</strong> Art. 6(1)(f) GDPR. <strong>Deletion of data:</strong> Log information is stored for up to 30 days and then deleted or anonymized. Data needed as evidence are excluded from deletion until the incident is finally clarified.</li>
    </ul>

    <h2 id="m134">Use of Cookies</h2>
    <p>“Cookies” refers to functions that store and read information on users’ end devices. Cookies can serve different purposes, e.g., functionality, security and convenience of online offerings, as well as analytics of visitor flows. We use cookies in accordance with legal requirements. Where required, we obtain users’ prior consent. If consent is not necessary, we rely on legitimate interests—especially where storage and reading of information are essential to provide expressly requested content and functions (e.g., storing settings and ensuring functionality and security). Consent can be withdrawn at any time. We clearly inform about the scope and which cookies are used.</p>
    <p><strong>Notes on legal bases:</strong> Whether we process personal data via cookies depends on consent. If consent is given, it is the legal basis. Without consent, we rely on our legitimate interests as outlined here and in the context of the respective services and procedures.</p>
    <p><strong>Retention:</strong> Regarding storage duration, the following types are distinguished:</p>
    <ul>
      <li><strong>Temporary (session) cookies:</strong> Deleted at the latest after a user leaves an online offering and closes their device (e.g., browser or app).</li>
      <li><strong>Persistent cookies:</strong> Remain stored after closing the device (e.g., to retain login status or show preferred content on return). Unless we provide explicit details, assume persistence up to two years.</li>
    </ul>
    <p><strong>General notes on withdrawal and objection (opt-out):</strong> Users may withdraw consent at any time and may object to processing as provided by law, including via their browser’s privacy settings.</p>
    <ul class="m-elements">
      <li><strong>Data types processed:</strong> Meta, communication and procedural data.</li>
      <li><strong>Data subjects:</strong> Users (e.g., website visitors, users of online services).</li>
      <li><strong>Legal bases:</strong> Legitimate interests (Art. 6(1)(f) GDPR); consent (Art. 6(1)(a) GDPR).</li>
    </ul>
    <p><strong>Further notes on processes, procedures and services:</strong></p>
    <ul class="m-elements">
      <li><strong>Consent management for cookies:</strong> We use a consent management solution to obtain, log, manage and enable withdrawal of users’ consent for cookies and comparable technologies. Consents are stored to avoid repeated prompts and to provide proof in line with legal requirements, server-side and/or in an “opt-in” cookie or similar technology to associate consent with a specific user/device. Unless otherwise stated, the storage period for consent is up to two years. A pseudonymous user identifier is created and stored with time of consent, scope (e.g., cookie categories/providers), and browser/system/device information; <strong>Legal basis:</strong> Art. 6(1)(a) GDPR.</li>
    </ul>

    <h2 id="m367">Registration, Login and User Account</h2>
    <p>Users can create an account. During registration, we inform users of the required fields, and process them to provide the account on the basis of contractual necessity. Data include, in particular, login information (username, password, and an email address).</p>
    <p>In connection with our registration and login functions and use of the account, we store the IP address and the time of each user action. This is based on our and users’ legitimate interests in preventing misuse and unauthorized use. Data are generally not passed to third parties unless necessary to pursue claims or required by law.</p>
    <p>Users may be informed by email about processes relevant to their account, e.g., technical changes.</p>
    <ul class="m-elements">
      <li><strong>Data types processed:</strong> Inventory data; contact data; content data; usage data; log data.</li>
      <li><strong>Data subjects:</strong> Users.</li>
      <li><strong>Purposes of processing:</strong> Provision of contractual services and obligations; security measures; organizational and administrative procedures; provision of our online offering and user-friendliness.</li>
      <li><strong>Retention and deletion:</strong> Deletion as stated in “General Information on Data Retention and Deletion”. Deletion upon termination.</li>
      <li><strong>Legal bases:</strong> Contract performance and pre-contractual inquiries (Art. 6(1)(b) GDPR); legitimate interests (Art. 6(1)(f) GDPR).</li>
    </ul>
    <p><strong>Further notes on processes, procedures and services:</strong></p>
    <ul class="m-elements">
      <li><strong>User profiles are not public:</strong> User profiles are not publicly visible or accessible.</li>
      <li><strong>Deletion after termination:</strong> If users terminate their account, related data are deleted unless a legal permission/obligation applies or users have consented; <strong>Legal basis:</strong> Art. 6(1)(b) GDPR.</li>
      <li><strong>No retention obligation for user data:</strong> It is the user’s responsibility to back up their data before the contract ends. We may irretrievably delete all data stored during the contract term; <strong>Legal basis:</strong> Art. 6(1)(b) GDPR.</li>
    </ul>

    <h2 id="m451">Single-Sign-On Login</h2>
    <p>“Single-Sign-On” (SSO) refers to procedures enabling users to log in to our online offering using an account with an SSO provider (e.g., a social network). Users must be registered with the SSO provider and enter the required credentials in the designated online form or confirm the SSO login via button when already logged in at the provider.</p>
    <p>Authentication occurs directly at the SSO provider. In this process, we receive a user ID indicating that the user is logged in at the SSO provider and a non-reusable ID for us (the “user handle”). Whether additional data are transmitted depends solely on the SSO procedure used, the consents granted during authentication, and the privacy/account settings at the SSO provider. Typically, the email address and username are shared. The password entered at the SSO provider is neither visible to us nor stored by us.</p>
    <p>Please note that data stored with us may be synchronized with the user’s account at the SSO provider, but this is not always possible or actually carried out. For example, if email addresses change, users must update them in their account with us.</p>
    <p>Where agreed with users, we may use SSO in the context of or prior to contract performance; otherwise we use it based on our and users’ legitimate interests in an effective and secure login system.</p>
    <p>If users later decide not to use their SSO link for login, they must disconnect it within their account at the SSO provider. To delete their data with us, users must terminate their registration with us.</p>
    <ul class="m-elements">
      <li><strong>Data types processed:</strong> Inventory data; contact data; usage data; meta, communication and procedural data.</li>
      <li><strong>Data subjects:</strong> Users.</li>
      <li><strong>Purposes of processing:</strong> Provision of contractual services and obligations; security measures; login procedures; provision of our online offering and user-friendliness.</li>
      <li><strong>Retention and deletion:</strong> Deletion as stated in “General Information on Data Retention and Deletion”. Deletion upon termination.</li>
      <li><strong>Legal bases:</strong> Contract performance and pre-contractual inquiries (Art. 6(1)(b) GDPR); legitimate interests (Art. 6(1)(f) GDPR).</li>
    </ul>
    <p><strong>Further notes on providers:</strong></p>
    <ul class="m-elements">
      <li><strong>Apple Single-Sign-On:</strong> Authentication services for user logins, SSO features, identity information management and app integrations; <strong>Provider:</strong> Apple Inc., Infinite Loop, Cupertino, CA 95014, USA; <strong>Legal basis:</strong> Art. 6(1)(f) GDPR; <strong>Website:</strong> <a href="https://www.apple.com/de/" target="_blank">https://www.apple.com/de/</a>; <strong>Privacy Policy:</strong> <a href="https://www.apple.com/legal/privacy/de-ww/" target="_blank">https://www.apple.com/legal/privacy/de-ww/</a>.</li>
      <li><strong>Google Single-Sign-On:</strong> Authentication services for user logins, SSO features, identity management and app integrations; <strong>Provider:</strong> Google Ireland Limited, Gordon House, Barrow Street, Dublin 4, Ireland; <strong>Legal basis:</strong> Art. 6(1)(f) GDPR; <strong>Website:</strong> <a href="https://www.google.de" target="_blank">https://www.google.de</a>; <strong>Privacy Policy:</strong> <a href="https://policies.google.com/privacy" target="_blank">https://policies.google.com/privacy</a>; <strong>Third-country transfer basis:</strong> Data Privacy Framework (DPF). <strong>Opt-out (ads):</strong> <a href="https://myadcenter.google.com/" target="_blank">https://myadcenter.google.com/</a>.</li>
    </ul>

    <h2 id="m182">Contact and Request Management</h2>
    <p>When contacting us (e.g., by post, contact form, email, phone or via social media) and within existing user and business relationships, we process the information of inquiring persons to the extent necessary to respond to contact requests and any requested actions.</p>
    <ul class="m-elements">
      <li><strong>Data types processed:</strong> Inventory data; contact data; content data; usage data; meta, communication and procedural data.</li>
      <li><strong>Data subjects:</strong> Communication partners.</li>
      <li><strong>Purposes of processing:</strong> Communication; organizational and administrative procedures; feedback (e.g., collecting feedback via online form); provision of our online offering and user-friendliness.</li>
      <li><strong>Retention and deletion:</strong> Deletion as stated in “General Information on Data Retention and Deletion”.</li>
      <li><strong>Legal bases:</strong> Legitimate interests (Art. 6(1)(f) GDPR); contract performance and pre-contractual inquiries (Art. 6(1)(b) GDPR).</li>
    </ul>
    <p><strong>Further notes:</strong></p>
    <ul class="m-elements">
      <li><strong>Contact form:</strong> When contacting us via form, email or other channels, we process the personal data provided to answer and handle the request (typically name, contact information and any details necessary to process the inquiry). We use these data exclusively for communication regarding the request; <strong>Legal bases:</strong> Art. 6(1)(b) GDPR; Art. 6(1)(f) GDPR.</li>
    </ul>

    <h2 id="m1643">Push Notifications</h2>
    <p>With users’ consent, we may send “push notifications”—messages that appear on users’ screens, devices or in browsers even when our online service is not actively in use.</p>
    <p>To subscribe, users must confirm their browser’s/device’s prompt. This consent process is logged and stored to recognize whether users have agreed to receive push notifications and to prove consent. For these purposes, a pseudonymous browser identifier (“push token”) or the device ID is stored.</p>
    <p>Push notifications may, on the one hand, be required to fulfill contractual duties (e.g., technical and organizational information relevant to our online offering) and <span class="dsg-license-content-blurred de dsg-ttip-activate" title="Please purchase a license to unlock these passages.">— This text area must be unlocked with a premium license. — premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext premiumtext </span></p>
    <ul class="m-elements">
      <li><strong>Data types processed:</strong> Usage data (e.g., page views, dwell time, click paths, usage frequency and intensity, device types and OS, interactions with <span class="dsg-license-content-blurred de dsg-ttip-activate" title="Please purchase a license to unlock these passages.">— This text area must be unlocked with a premium license. — premiumtext premiumtext premiumtext premiumtext premiumtext </span>); meta, communication and procedural data (e.g., IP addresses, timestamps, identifiers, involved <span class="dsg-license-content-blurred de dsg-ttip-activate" title="Please purchase a license to unlock these passages.">— This text area must be unlocked with a premium license. — premiumtext premiumtext premiumtext </span>).</li>
      <li><strong>Data subjects:</strong> Communication partners.</li>
      <li><strong>Purposes of processing:</strong> Communication; provision of our online offering and user-friendliness.</li>
      <li><strong>Retention and deletion:</strong> Deletion as stated in “General Information on Data Retention and Deletion”. Deletion upon termination.</li>
      <li><strong>Legal bases:</strong> Consent (Art. 6(1)(a) GDPR); legitimate interests (Art. 6(1)(f) GDPR).</li>
    </ul>

    <h2 id="m15">Changes and Updates</h2>
    <p>Please review the content of our Privacy Policy regularly. We will adapt the Privacy Policy as soon as changes in our data processing make this necessary. We will inform you when your cooperation (e.g., consent) or other individual notification is required due to changes.</p>
    <p>If we provide addresses and contact details of companies and organizations in this Privacy Policy, please note that addresses may change over time. Please verify the information before contacting them.</p>

    <h2 id="m42">Definitions</h2>
    <p>This section provides an overview of the terms used in this Privacy Policy. Where terms are legally defined, those definitions apply. The explanations below are intended primarily to aid understanding.</p>
    <ul class="glossary">
      <li><strong>Inventory data:</strong> Key information necessary to identify and manage contracting partners, accounts, profiles and similar assignments (e.g., names, contact details, birth dates, identifiers). They enable unique assignment and communication.</li>
      <li><strong>Content data:</strong> Information generated during creation, editing and publication of any content (texts, images, videos, audio, and metadata such as tags, descriptions, authorship, publication dates).</li>
      <li><strong>Contact data:</strong> Core information enabling communication with persons or organizations (phone numbers, postal addresses, email addresses, social media handles, messaging IDs).</li>
      <li><strong>Meta, communication and procedural data:</strong> Information on how data are processed, transmitted and managed (metadata describing context, origin and structure; communication data covering exchanges incl. participants and timestamps; procedural data describing workflows, transactions and audit logs).</li>
      <li><strong>Usage data:</strong> Information on how users interact with digital products/services (features used, dwell time, navigation paths, frequency, timestamps, IPs, device and location data) used to analyze behavior, improve UX, personalize content and detect issues.</li>
      <li><strong>Personal data:</strong> Any information relating to an identified or identifiable natural person (a “data subject”). A person is identifiable if they can be identified, directly or indirectly, in particular by reference to an identifier such as a name, ID number, location data, an online identifier (e.g., cookie), or to one or more factors specific to the physical, physiological, genetic, mental, economic, cultural or social identity.</li>
      <li><strong>Log data:</strong> Information about events or activities recorded by a system or network (timestamps, IPs, user actions, error messages) used for problem analysis, security monitoring, or performance reporting.</li>
      <li><strong>Controller:</strong> The natural or legal person, public authority, agency or other body which, alone or jointly with others, determines the purposes and means of processing of personal data.</li>
      <li><strong>Processing:</strong> Any operation performed on personal data, whether or not by automated means (collection, analysis, storage, transmission, deletion, etc.).</li>
      <li><strong>Contract data:</strong> Information that formalizes agreements between parties (e.g., terms, start/end dates, services/products, prices, payment terms, termination rights, renewal options, special conditions).</li>
      <li><strong>Payment data:</strong> Information needed to process payments (card numbers, bank details, amounts, transaction data, verification numbers, invoices, payment status, chargebacks, authorizations, fees).</li>
    </ul>
    <p class="seal"><a href="https://datenschutz-generator.de/" title="Legal text by Dr. Schwenke – click for more information." target="_blank" rel="noopener noreferrer nofollow">Created with the free privacy generator by Dr. Thomas Schwenke</a></p>
    """
}





// MARK: - App-Info Helpers
extension Bundle {
    /// z.B. "1.0 (12)"
    var appVersionReadable: String {
        let v = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    /// Anzeige mit automatischem "• Beta" in Debug oder TestFlight (Sandbox-Receipt)
    var appVersionDisplay: String {
        let base = appVersionReadable
        let isTestFlight = appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #if DEBUG
        return "\(base) • Beta"
        #else
        return isTestFlight ? "\(base) • Beta" : base
        #endif
    }

    var appDisplayName: String {
        if let name = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String { return name }
        if let name = object(forInfoDictionaryKey: "CFBundleName") as? String { return name }
        return "Diese App"
    }
}



// MARK: - Entwickler-Profil (Beispiel)
enum DeveloperProfile {
    static let name          = "Dein Name"
    static let role          = "Solo iOS-Entwickler"
    static let location      = "Berlin, Deutschland"
    static let bio           = "Kurzer Steckbrief/Bio."
    static let photoAsset    = "dev_photo"
    static let photoURL: URL? = nil
    static let email         = "movobp.contact@gmail.com"
    static let website: URL? = nil
    static let github        = URL(string: "https://github.com/dein-account")
    static let twitterX      = URL(string: "https://x.com/dein-account")
    static let instagram     = URL(string: "https://instagram.com/dein-account")
}

// MARK: - Über die App (einzeln)
struct AboutAppView: View {
    @EnvironmentObject var appSettings: AppSettings
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header(title: appSettings.localized("about.title"),
                       subtitle: String(format: appSettings.localized("about.subtitle"),
                                        Bundle.main.appDisplayName))

                LegalCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(appSettings.localized("about.card.benefits"), systemImage: "sparkles")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 10) {
                            benefitRow(icon: "list.bullet.rectangle",
                                       title: appSettings.localized("about.benefit.plan.title"),
                                       text: appSettings.localized("about.benefit.plan.text"))
                            benefitRow(icon: "trophy",
                                       title: appSettings.localized("about.benefit.challenges.title"),
                                       text: appSettings.localized("about.benefit.challenges.text"))
                            benefitRow(icon: "star.circle",
                                       title: appSettings.localized("about.benefit.rewards.title"),
                                       text: appSettings.localized("about.benefit.rewards.text"))
                            benefitRow(icon: "figure.walk",
                                       title: appSettings.localized("about.benefit.steps.title"),
                                       text: appSettings.localized("about.benefit.steps.text"))
                            benefitRow(icon: "checkmark.seal",
                                       title: appSettings.localized("about.benefit.achievements.title"),
                                       text: appSettings.localized("about.benefit.achievements.text"))
                            benefitRow(icon: "doc.badge.plus",
                                       title: appSettings.localized("about.benefit.templates.title"),
                                       text: appSettings.localized("about.benefit.templates.text"))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                LegalCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(appSettings.localized("settings.support.title"), systemImage: "envelope")
                            .font(.headline)
                        Link(appSettings.localized("about.support.email"),
                             destination: URL(string: "mailto:\(DeveloperProfile.email)")!)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)
            }
            .padding(.top, 16)
        }
        .background(bgGradient)
        .navigationTitle(appSettings.localized("about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func benefitRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text)
            }
        }
    }
}

// MARK: - Units.swift (Gewicht)
import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }

    var symbol: String { self == .kg ? "kg" : "lb" }
    var localizedLong: String { self == .kg ? "Kilogramm (kg)" : "Pfund (lb)" }
    var localizedShort: String { symbol.uppercased() }

    func fromKilograms(_ kg: Double) -> Double {
        switch self { case .kg: return kg; case .lb: return kg * 2.20462262185 }
    }
    func toKilograms(_ value: Double) -> Double {
        switch self { case .kg: return value; case .lb: return value / 2.20462262185 }
    }
}

extension WeightUnit {
    func format(kg: Double, decimals: Int = 0) -> String {
        let value = fromKilograms(kg)
        let formatted = value.formatted(.number.precision(.fractionLength(0...decimals)))
        return "\(formatted) \(symbol)"
    }
}

extension Binding where Value == Double {
    func asUnit(_ unit: WeightUnit) -> Binding<Double> {
        Binding<Double>(
            get: { unit.fromKilograms(self.wrappedValue) },
            set: { self.wrappedValue = unit.toKilograms($0) }
        )
    }
}
