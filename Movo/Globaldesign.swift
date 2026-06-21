import SwiftUI

// MARK: - Theme Host (System/Light/Dark + Tint aus Preset)
struct AppThemeHost<Content: View>: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var design: DesignSettingsStore
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
            .environment(\.designTokens, design.tokens)
            .environment(\.colorScheme, effectiveScheme)
            .environment(\.locale, appSettings.locale)
            .tint(design.tokens.palette.primary)
            .animation(.easeInOut(duration: 0.22), value: design.tokens.colors)
            .animation(nil, value: appSettings.themeMode)
            .id("\(appSettings.themeMode.rawValue)-\(appSettings.language)")
    }
}

// MARK: - Presets
struct DSColorPalette: Equatable {
    let name: String
    let primary: Color
    let secondary: Color
    let surfaceA: Color
    let surfaceB: Color
    let positive: Color
    let warning: Color
    let outline: Color
    let onSurface: Color
}

enum DSColorPreset: String, CaseIterable, Identifiable, Codable {
    case movo, berry, mint, mango, graphite, neon
    var id: String { rawValue }
    var title: String {
        switch self {
        case .movo: "Movo"; case .berry: "Berry"; case .mint: "Mint"
        case .mango: "Mango"; case .graphite: "Graphit"; case .neon: "Neon"
        }
    }

    var palette: DSColorPalette {
        switch self {
        case .movo:
            .init(name: "Movo",
                  primary: Color(red: 0.29, green: 0.36, blue: 0.98),
                  secondary: Color(red: 0.93, green: 0.57, blue: 0.99),
                  surfaceA: Color(red: 0.90, green: 0.94, blue: 1.00),
                  surfaceB: Color(red: 0.96, green: 0.92, blue: 1.00),
                  positive: Color(red: 0.17, green: 0.74, blue: 0.36),
                  warning:  Color(red: 1.00, green: 0.64, blue: 0.20),
                  outline: .black.opacity(0.10),
                  onSurface: .black.opacity(0.9))
        case .berry:
            .init(name: "Berry",
                  primary: Color(red: 0.84, green: 0.19, blue: 0.56),
                  secondary: Color(red: 0.55, green: 0.33, blue: 0.97),
                  surfaceA: Color(red: 0.98, green: 0.92, blue: 1.00),
                  surfaceB: Color(red: 0.95, green: 0.96, blue: 1.00),
                  positive: Color(red: 0.20, green: 0.70, blue: 0.40),
                  warning:  Color(red: 1.00, green: 0.41, blue: 0.39),
                  outline: .black.opacity(0.10),
                  onSurface: .black.opacity(0.9))
        case .mint:
            .init(name: "Mint",
                  primary: Color(red: 0.05, green: 0.73, blue: 0.63),
                  secondary: Color(red: 0.22, green: 0.85, blue: 0.56),
                  surfaceA: Color(red: 0.90, green: 1.00, blue: 0.96),
                  surfaceB: Color(red: 0.92, green: 1.00, blue: 0.98),
                  positive: Color(red: 0.08, green: 0.67, blue: 0.32),
                  warning:  Color(red: 1.00, green: 0.66, blue: 0.20),
                  outline: .black.opacity(0.10),
                  onSurface: .black.opacity(0.9))
        case .mango:
            .init(name: "Mango",
                  primary: Color(red: 1.00, green: 0.58, blue: 0.12),
                  secondary: Color(red: 1.00, green: 0.76, blue: 0.27),
                  surfaceA: Color(red: 1.00, green: 0.95, blue: 0.90),
                  surfaceB: Color(red: 1.00, green: 0.97, blue: 0.92),
                  positive: Color(red: 0.20, green: 0.70, blue: 0.40),
                  warning:  Color(red: 0.90, green: 0.24, blue: 0.19),
                  outline: .black.opacity(0.10),
                  onSurface: .black.opacity(0.9))
        case .graphite:
            .init(name: "Graphit",
                  primary: Color(white: 0.18),
                  secondary: Color(white: 0.35),
                  surfaceA: Color(white: 0.10),
                  surfaceB: Color(white: 0.18),
                  positive: Color(red: 0.25, green: 0.78, blue: 0.34),
                  warning:  Color(red: 1.00, green: 0.71, blue: 0.00),
                  outline: .white.opacity(0.14),
                  onSurface: .white)
        case .neon:
            .init(name: "Neon",
                  primary: Color(red: 0.00, green: 0.90, blue: 0.38),
                  secondary: Color(red: 0.23, green: 0.97, blue: 0.86),
                  surfaceA: Color(red: 0.04, green: 0.05, blue: 0.06),
                  surfaceB: Color(red: 0.09, green: 0.10, blue: 0.12),
                  positive: Color(red: 0.00, green: 0.90, blue: 0.38),
                  warning:  Color(red: 1.00, green: 0.31, blue: 0.31),
                  outline: .white.opacity(0.16),
                  onSurface: .white)
        }
    }
}

// MARK: - Environment + Persistenz
struct DesignTokens: Equatable {
    var colors: DSColorPreset = .movo
    var palette: DSColorPalette { colors.palette }
}

private struct DesignTokensKey: EnvironmentKey { static let defaultValue = DesignTokens() }
extension EnvironmentValues {
    var designTokens: DesignTokens {
        get { self[DesignTokensKey.self] }
        set { self[DesignTokensKey.self] = newValue }
    }
}

final class DesignSettingsStore: ObservableObject {
    @Published var tokens: DesignTokens { didSet { persist() } }
    init() {
        if let data = UserDefaults.standard.data(forKey: "designColors"),
           let raw = String(data: data, encoding: .utf8),
           let preset = DSColorPreset(rawValue: raw) {
            tokens = .init(colors: preset)
        } else {
            tokens = .init()
        }
    }
    private func persist() {
        UserDefaults.standard.set(tokens.colors.rawValue.data(using: .utf8), forKey: "designColors")
    }
}

// MARK: - Brand Styles (Hero etc.)

struct AppHeroCardModifier: ViewModifier {
    @Environment(\.designTokens) private var t
    @Environment(\.colorScheme)  private var scheme

    func body(content: Content) -> some View {
        let isDark = (scheme == .dark)
        let g1 = t.palette.primary.opacity(isDark ? 0.55 : 0.35)
        let g2 = t.palette.secondary.opacity(isDark ? 0.45 : 0.30)
        let outline = isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
        let shadow  = isDark ? Color.black.opacity(0.45) : Color.black.opacity(0.18)

        return content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [g1, g2],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(outline, lineWidth: 1))
            .shadow(color: shadow, radius: 18, x: 0, y: 10)
    }
}

// MARK: - Global Neutral/Brand/Search Styles

struct AppNeutralCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let baseTop    = scheme == .dark ? Color.white.opacity(0.10) : Color(UIColor.secondarySystemBackground)
        let baseBottom = scheme == .dark ? Color.white.opacity(0.06) : Color(UIColor.systemBackground)
        let outline    = scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
        let shadow     = scheme == .dark ? Color.black.opacity(0.40)  : Color.black.opacity(0.08)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return content
            .padding(16)
            .background(shape.fill(LinearGradient(colors: [baseTop, baseBottom],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(shape.stroke(outline, lineWidth: 1))
            .shadow(color: shadow, radius: 10, x: 0, y: 5)
    }
}

struct AppBrandCard: ViewModifier {
    @Environment(\.designTokens) private var t
    @Environment(\.colorScheme)  private var scheme
    func body(content: Content) -> some View {
        let isDark = (scheme == .dark)
        let baseTop    = isDark ? Color.white.opacity(0.10) : Color(UIColor.secondarySystemBackground)
        let baseBottom = isDark ? Color.white.opacity(0.06) : Color(UIColor.systemBackground)
        let tintTop    = t.palette.primary.opacity(isDark ? 0.06 : 0.03)
        let tintBottom = t.palette.secondary.opacity(isDark ? 0.04 : 0.02)
        let outline    = isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
        let shadow     = isDark ? Color.black.opacity(0.40)  : Color.black.opacity(0.10)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return content
            .padding(16)
            .background(shape.fill(LinearGradient(colors: [baseTop, baseBottom],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(
                shape.fill(LinearGradient(colors: [tintTop, tintBottom],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blendMode(.overlay)
            )
            .overlay(shape.stroke(outline, lineWidth: 1))
            .shadow(color: shadow, radius: 12, x: 0, y: 6)
    }
}

struct AppSearchFieldStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let bg = scheme == .dark ? Color.white.opacity(0.08) : Color(UIColor.secondarySystemFill)
        let outline = scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)

        return content
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(outline, lineWidth: 1))
            .shadow(color: scheme == .dark ? .black.opacity(0.20) : .black.opacity(0.06),
                    radius: 8, x: 0, y: 4)
    }
}

private struct DarkPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
    }
}

// MARK: - View helpers
extension View {
    // Bestand: lässt Hero wie gehabt aussehen
    func appHeroCard() -> some View { modifier(AppHeroCardModifier()) }

    // Neu: neutrale, systemkonforme Karte
    func appNeutralCard() -> some View { modifier(AppNeutralCard()) }

    // Neu: neutrale Karte mit zarter Brand-Tönung
    func appBrandCard() -> some View { modifier(AppBrandCard()) }

    // Neu: Suchfeld-Styling
    func appSearchField() -> some View { modifier(AppSearchFieldStyle()) }

    // Kompatibilität: bisherige Elevated-Card zeigt jetzt die neutrale Karte
    func appElevatedCard() -> some View { modifier(AppNeutralCard()) }

    func darkPill() -> some View { modifier(DarkPillModifier()) }
}
