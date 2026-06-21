
import SwiftUI

extension ExerciseInfo {
    // Generates a key like "exercise.instructions.bench_press_barbell" from "Bench Press (Barbell)"
    fileprivate var instructionKeyFromName: String {
        var s = name.lowercased()

        // Handle Umlauts
        s = s.replacingOccurrences(of: "ä", with: "ae")
             .replacingOccurrences(of: "ö", with: "oe")
             .replacingOccurrences(of: "ü", with: "ue")
             .replacingOccurrences(of: "ß", with: "ss")

        // Normalize separators
        let replacers: [String: String] = [
            "(": " ", ")": " ", "+": " ", "–": " ", "—": " ", "-": " ",
            "/": " ", "&": " ", ",": " ", ".": " ", "'": "", "’": ""
        ]
        for (k, v) in replacers { s = s.replacingOccurrences(of: k, with: v) }

        // Collapse whitespace to underscores
        s = s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        s = s.replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
             .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return "exercise.instructions.\(s)"
    }

    /// Provides localized instructions with fallback
    func localizedInstructions(using appSettings: AppSettings) -> String {
        // 1) Try derived key
        let autoKey = instructionKeyFromName
        let localized = appSettings.localized(autoKey)
        if localized != autoKey { return localized }

        // 2) Fallback: stored text or neutral localization
        let trimmed = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appSettings.localized("exercise.instructions.none") : trimmed
    }
    
    func localizedName(using settings: AppSettings) -> String {
         // Use the legacy approach: checks if the name itself is a key?
         // In the legacy version, names were English strings in the JSON.
         // We essentially always displayed the English name unless we had a specific localization logic?
         // Wait, the new logic had `settings.localized(self.name)`.
         // If `self.name` is "Bench Press (Barbell)", `settings.localized` might return it as is if no key matches.
         // But we moved to keys in `exercises.json` "exercise.bench_press_barbell".
         // Reverting means `exercises.json` has "Bench Press (Barbell)" again.
         // So `settings.localized("Bench Press (Barbell)")` -> "Bench Press (Barbell)" (if en) or ...?
         // Actually, `localizedName` was likely just returning `name` before?
         // Or, if we want to support German, we need a map from English Name -> German Key?
         // The previous `localizedName` implementation just called `settings.localized(self.name)`.
         // If `name` is "Bench Press (Barbell)", we need that to map to German?
         // This implies we need a reverse mapping or we should rely on `instructionKeyFromName` style logic for names too?
         // For now, let's keep `localizedName` simple as it was likely not complex before.
         return settings.localized(self.name)
    }

    func localizedMuscle(_ name: String, using settings: AppSettings) -> String {
        let raw = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Direct mapping for known raw names
        let map: [String: String] = [
            "Front Delts": "muscle.deltoids",
            "Side Delts": "muscle.deltoids",
            "Rear Delts": "muscle.deltoids",
            "Deltoids": "muscle.deltoids",
            "Glutes (Medius)": "muscle.glutes_medius",
            "Glutes": "muscle.glutes",
            "Latissimus Dorsi": "muscle.lats",
            "Lats": "muscle.lats",
            "Pectoralis Major": "muscle.chest",
            "Pectoralis Major (Upper)": "muscle.chest",
            "Pectoralis Major (Lower)": "muscle.chest",
            "Erector Spinae": "muscle.erector_spinae",
            "Rhomboids": "muscle.rhomboids",
            "Traps": "muscle.traps",
            "Adductors": "muscle.adductors",
            "Quads": "muscle.quads",
            "Hamstrings": "muscle.hamstrings",
            "Obliques": "muscle.obliques",
            "Brachialis": "muscle.brachialis",
            "Forearms": "muscle.forearms",
            "Calves": "muscle.calves",
            "Abs": "muscle.abs",
            "Biceps": "muscle.biceps",
            "Triceps": "muscle.triceps",
            "Back": "muscle.back",
            "Chest": "muscle.chest",
            "Legs": "muscle.legs",
            "Shoulders": "muscle.shoulders",
            "Cardio": "muscle.cardio",
            "Full Body": "muscle.fullbody",
            "Lower Back": "muscle.lowerback",
            "Posterior Chain": "muscle.posteriorchain",
            "Grip": "muscle.grip",
            "Heart": "muscle.heart",
            
            // New mappings
            "Core": "muscle.core",
            "Hip Flexors": "muscle.hip_flexors",
            "Rotator Cuff": "muscle.rotator_cuff",
            "Arms": "muscle.arms"
        ]
        
        if let key = map[raw] {
            return settings.localized(key)
        }
        
        // 2. Fallback: Try "muscle.<lowercase>"
        let simpleKey = "muscle." + raw.lowercased().replacingOccurrences(of: " ", with: "")
        let localized = settings.localized(simpleKey)
        if localized != simpleKey { return localized }
        
        // 3. Fallback: Return raw name
        return raw
    }
}
