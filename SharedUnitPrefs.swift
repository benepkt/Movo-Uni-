import Foundation

// MARK: - App Group für gemeinsame Defaults (optional)
let APP_GROUP_ID = "group.DEINE-APP-GROUP-ID-HIER"

// MARK: - Units (Gewicht) – unverändert
enum UnitPrefs {
    enum Weight: String { case kg, lb }

    private static var store: UserDefaults {
        UserDefaults(suiteName: APP_GROUP_ID) ?? .standard
    }

    static func currentWeightUnit() -> Weight {
        let raw = store.string(forKey: "units.weight")?.lowercased() ?? "kg"
        return Weight(rawValue: raw) ?? .kg
    }

    static func setWeightUnit(_ unit: Weight) {
        store.set(unit.rawValue, forKey: "units.weight")
    }

    static func formatWeightLong(kg value: Double) -> String {
        let (val, sym) = convert(kg: value)
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        let s = nf.string(from: NSNumber(value: val)) ?? "0"
        return "\(s) \(sym)"   // mit Leerzeichen
    }

    static func formatWeightShort(kg value: Double) -> String {
        let (val, sym) = convert(kg: value)
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 1
        let s = nf.string(from: NSNumber(value: val)) ?? "0"
        return "\(s)\(sym)"     // kompakt ohne Leerzeichen
    }

    private static func convert(kg: Double) -> (Double, String) {
        switch currentWeightUnit() {
        case .kg: return (kg, "kg")
        case .lb: return (kg * 2.2046226218, "lb")
        }
    }
}

// MARK: - Minimale Live-Activity-Lokalisierungen
/// Eigene, kleine Tabelle NUR für Widget/Live-Activity,
/// damit es keine Abhängigkeit zur großen App-Tabelle gibt.
enum LocalizedStrings_LA {
    static let de: [String: String] = [
        "live.sets": "Sätze",
        "live.duration": "Dauer",
        "live.weight": "Gewicht",
        "live.training.running": "🏋️ Training läuft",
        "live.min.suffix": "m"
    ]

    static let en: [String: String] = [
        "live.sets": "Sets",
        "live.duration": "Duration",
        "live.weight": "Weight",
        "live.training.running": "🏋️ Workout running",
        "live.min.suffix": "m"
    ]
}

// MARK: - Zugriff-Helper
enum LAStrings {
    /// Übersetzung ohne Platzhalter
    static func t(_ key: String, lang raw: String?) -> String {
        let lang = (raw ?? Locale.current.languageCode ?? "en").lowercased()
        let table = lang.hasPrefix("de") ? LocalizedStrings_LA.de : LocalizedStrings_LA.en
        return table[key] ?? LocalizedStrings_LA.en[key] ?? key
    }

    /// Übersetzung mit Format-Argumenten (z. B. %d, %@)
    static func f(_ key: String, lang raw: String?, _ args: CVarArg...) -> String {
        String(format: t(key, lang: raw), arguments: args)
    }
}
