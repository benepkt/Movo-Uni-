import SwiftUI
import UIKit   // ⬅️ nötig, weil wir UIColor encodieren/decodieren

struct ThemeHost<Content: View>: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.colorScheme) private var systemScheme
    @ViewBuilder var content: () -> Content

    private var effectiveScheme: ColorScheme {
        switch appSettings.themeMode {
        case .system: return systemScheme
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var body: some View {
        content()
            .environment(\.colorScheme, effectiveScheme)
            .tint(appSettings.accentColor)
            .animation(.easeInOut(duration: 0.22), value: appSettings.themeMode)
            .animation(.easeInOut(duration: 0.22), value: appSettings.accentColor)
    }
}

// MARK: - Theme Mode
enum AppThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Hell"
        case .dark:   return "Dunkel"
        }
    }

    /// Mapping für preferredColorScheme (nil = System)
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - App Settings
enum MovoLanguage: String, CaseIterable, Identifiable {
    case de
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .de: return "de_DE"
        case .en: return "en_US"
        }
    }

    static func normalized(_ value: String) -> MovoLanguage {
        value.lowercased().hasPrefix("de") ? .de : .en
    }
}

final class AppSettings: ObservableObject {
    // Darstellung (Hell/Dunkel/System)
    @Published var themeMode: AppThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode") }
    }

    // Akzentfarbe (globales .tint)
    @Published var accentColor: Color {
        didSet {
            let uiColor = UIColor(accentColor)
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiColor,
                                                            requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: "accentColor")
            }
        }
    }

    // Push/Local Notifications (nur Einstellung)
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    // Product analytics via PostHog. Defaults to disabled until the user chooses.
    @Published var analyticsEnabled: Bool {
        didSet { UserDefaults.standard.set(analyticsEnabled, forKey: "analyticsEnabled") }
    }

    @Published var analyticsConsentPromptSeen: Bool {
        didSet { UserDefaults.standard.set(analyticsConsentPromptSeen, forKey: "analyticsConsentPromptSeen") }
    }

    // Sprache (de/en)
    @Published var language: String {
        didSet {
            let normalized = MovoLanguage.normalized(language).rawValue
            if language != normalized {
                language = normalized
                return
            }
            UserDefaults.standard.set(normalized, forKey: "language")
            UserDefaults.standard.set(normalized, forKey: "app.language")
            UserDefaults(suiteName: APP_GROUP_ID)?.set(normalized, forKey: "app.language")
        }
    }

    // User name for personalization (optional)
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }

    // Goal weight in kg for motivation (optional)
    @Published var goalWeightKg: Double? {
        didSet {
            if let goal = goalWeightKg {
                UserDefaults.standard.set(goal, forKey: "goalWeightKg")
            } else {
                UserDefaults.standard.removeObject(forKey: "goalWeightKg")
            }
        }
    }

    init() {
        // Theme laden
        if let raw = UserDefaults.standard.string(forKey: "themeMode"),
           let mode = AppThemeMode(rawValue: raw) {
            self.themeMode = mode
        } else {
            self.themeMode = .system
        }

        // Akzentfarbe laden
        if let data = UserDefaults.standard.data(forKey: "accentColor"),
           let uiColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor {
            self.accentColor = Color(uiColor)
        } else {
            self.accentColor = .blue
        }

        // Notifications laden
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")

        let analyticsState = AppSettings.loadAnalyticsConsentState()
        self.analyticsEnabled = analyticsState.enabled
        self.analyticsConsentPromptSeen = analyticsState.promptSeen

        // Sprache laden oder erstmals anhand System-Sprache initialisieren
        if let saved = UserDefaults.standard.string(forKey: "language") {
            self.language = saved
        } else {
            let initial = AppSettings.detectInitialLanguage()
            self.language = initial
            UserDefaults.standard.set(initial, forKey: "language")
        }

        // User name laden
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        
        // Goal weight laden
        if UserDefaults.standard.object(forKey: "goalWeightKg") != nil {
            self.goalWeightKg = UserDefaults.standard.double(forKey: "goalWeightKg")
        } else {
            self.goalWeightKg = nil
        }
    }

    /// Wählt "de" wenn eine bevorzugte Sprache mit "de" beginnt, sonst "en".
    private static func detectInitialLanguage() -> String {
        // 1) bevorzugte Sprachenliste (z. B. ["de-DE", "en-DE", ...])
        if let first = Locale.preferredLanguages.first?.lowercased(),
           first.hasPrefix("de") {
            return "de"
        }
        // 2) Fallback: Locale.current (iOS 16+ hat language.languageCode)
        if #available(iOS 16.0, *) {
            if let code = Locale.current.language.languageCode?.identifier.lowercased(),
               code.hasPrefix("de") {
                return "de"
            }
        } else {
            let id = Locale.current.identifier.lowercased()
            if id.hasPrefix("de") { return "de" }
        }
        // 3) Default: Fallback zu Deutsch für diesen User, da er es wünscht
        // Original war "en", aber User sagt es ist immer englisch am Start.
        // Wir erzwingen hier "de" als Default fallback oder prüfen präziser.
        return "de"
    }

    private static func loadAnalyticsConsentState() -> (enabled: Bool, promptSeen: Bool) {
        let defaults = UserDefaults.standard
        let migrationKey = "analyticsConsentMigration.v1"
        let enabledKey = "analyticsEnabled"
        let promptKey = "analyticsConsentPromptSeen"

        if defaults.object(forKey: migrationKey) == nil {
            let hasExplicitChoice = defaults.object(forKey: promptKey) != nil
            let looksLikeExistingInstall = defaults.object(forKey: kOnboardingKey) != nil
                || defaults.object(forKey: "profile.weightKg") != nil
                || defaults.object(forKey: "userName") != nil
                || defaults.object(forKey: "language") != nil

            if looksLikeExistingInstall, !hasExplicitChoice {
                defaults.set(false, forKey: enabledKey)
                defaults.set(true, forKey: promptKey)
            } else if defaults.object(forKey: enabledKey) == nil {
                defaults.set(false, forKey: enabledKey)
                defaults.set(false, forKey: promptKey)
            }

            defaults.set(true, forKey: migrationKey)
        }

        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(false, forKey: enabledKey)
        }
        if defaults.object(forKey: promptKey) == nil {
            defaults.set(false, forKey: promptKey)
        }

        return (
            enabled: defaults.bool(forKey: enabledKey),
            promptSeen: defaults.bool(forKey: promptKey)
        )
    }
}

// MARK: - Simple Localizer über AppSettings.language
extension AppSettings {
    var movoLanguage: MovoLanguage { MovoLanguage.normalized(language) }
    var isGerman: Bool { movoLanguage == .de }
    var locale: Locale { Locale(identifier: movoLanguage.localeIdentifier) }

    func localized(_ key: String) -> String {
        switch movoLanguage {
        case .en:
            return LocalizedStrings.en[key] ?? LocalizedStrings.de[key] ?? key
        case .de:
            return LocalizedStrings.de[key] ?? LocalizedStrings.en[key] ?? key
        }
    }

    func localized(_ key: String, fallback: String) -> String {
        let value = localized(key)
        return value == key ? fallback : value
    }

    func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        String(format: localized(key), locale: locale, arguments: args)
    }
}

extension View {
    /// Zentriert den Content auf iPad und begrenzt die Breite (wie ein "Card"-Layout).
    @ViewBuilder
    func iPadConstrained(maxWidth: CGFloat = 520) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            self
        }
    }
}
