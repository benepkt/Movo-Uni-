import Foundation

/// Zentraler Parser/Formatter für Gewichts- & Satzangaben.
enum SetFormatter {

    // MARK: - Public

    /// Kurztext für die UI – Zeit dominiert, sonst „kg × Wdh“, sonst Rohtext.
    static func display(weight: String, reps: String) -> String {
        let kg  = numericKg(weight)
        let eff = effortType(reps)

        switch eff {
        case .time(let t):
            // Zeitbasierte Sets: nur Zeit anzeigen (z.B. "30s", "45s pro Seite", "1:00 min")
            return t
        case .reps(let r):
            if let w = kg { return "\(trim(w)) kg × \(r) Wdh" }
            return "\(r) Wdh"
        case .other(let raw):
            if let w = kg { return "\(trim(w)) kg × \(raw)" }
            return raw
        }
    }

    /// true, wenn ein numerisches Gewicht erkennbar ist.
    static func hasNumericWeight(_ weight: String) -> Bool {
        numericKg(weight) != nil
    }

    /// Extrahiert eine Gewichts-Zahl in kg (z. B. "50", "50kg", "50 kg", "50,5 kg").
    /// Gibt `nil` zurück bei Bodyweight/Band/Kettlebell/„+…“ usw.
    static func numericKg(_ weight: String) -> Double? {
        // Offensichtliche Nicht-Gewichte ignorieren
        let lower = weight.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("bodyweight") || lower.contains("band") || lower.contains("kettlebell") || lower.contains("+") {
            return nil
        }

        // Komma zu Punkt, Whitespace trimmen
        let s = weight
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Erste Double-Zahl lesen (z. B. "50kg", " 50 kg", "50.5")
        let scanner = Scanner(string: s)
        scanner.charactersToBeSkipped = .whitespaces
        var value: Double = .nan
        if scanner.scanDouble(&value), value.isFinite { return value }

        return nil
    }

    // MARK: - Internal

    private enum Effort { case time(String), reps(Int), other(String) }

    /// Heuristik: erkennt Zeit (min/s/„:“), sonst Reps als Zahl, sonst Rohtext.
    private static func effortType(_ reps: String) -> Effort {
        let lower = reps.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // einfache Zeit-Erkennung
        if lower.contains("min") || lower.contains("s") || lower.contains(":") {
            return .time(reps)
        }

        // Reps als Zahl extrahieren
        let digits = lower.filter("0123456789".contains)
        if let r = Int(digits), !digits.isEmpty {
            return .reps(r)
        }

        return .other(reps)
    }

    private static func trim(_ v: Double) -> String {
        abs(v - round(v)) < 0.001 ? String(Int(round(v))) : String(format: "%.1f", v)
    }
}
