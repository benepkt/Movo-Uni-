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

    // Sprache (de/en)
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
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

        // Sprache laden
        self.language = UserDefaults.standard.string(forKey: "language") ?? "de"
    }
}

// MARK: - Simple Localizer über AppSettings.language
extension AppSettings {
    func localized(_ key: String) -> String {
        switch language {
        case "en": LocalizedStrings.en[key] ?? key
        default:   LocalizedStrings.de[key] ?? key
        }
    }
}
