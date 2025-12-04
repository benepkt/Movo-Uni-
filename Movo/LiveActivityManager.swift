import Foundation
import ActivityKit

@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>?

    // 👇 Neu: einfache Abfrage, ob (irgend)eine Activity läuft
    var hasActiveActivity: Bool {
        currentActivity != nil || !Activity<WorkoutActivityAttributes>.activities.isEmpty
    }

    // Letzte Werte – damit wir Sprache/Einheit „live“ updaten können, ohne neue Messwerte zu schicken
    private var lastElapsed: TimeInterval = 0
    private var lastCompleted: Int = 0
    private var lastTotalKg: Double = 0
    private var lastUnitRaw: String = "kg"
    private var lastLangRaw: String = "de"

    private init() {
        Task { [weak self] in
            if let existing = Activity<WorkoutActivityAttributes>.activities.first {
                self?.currentActivity = existing
            }
        }
    }

    // MARK: - Start

    func startActivity(initialUnit: WeightUnit? = nil, initialLanguage: String? = nil) {
        guard currentActivity == nil else { return }

        let unitRaw = (initialUnit?.rawValue ?? readUnitRaw()).lowercased()
        let langRaw = normalizeLang(initialLanguage ?? readLanguageRaw())

        lastElapsed = 0
        lastCompleted = 0
        lastTotalKg = 0
        lastUnitRaw = unitRaw
        lastLangRaw = langRaw

        let attributes = WorkoutActivityAttributes(workoutID: UUID(), startedAt: Date())
        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedTime: 0,
            completedExercises: 0,
            totalWeight: 0,         // immer kg
            weightUnitRaw: unitRaw,
            languageRaw: langRaw
        )

        do {
            let activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("LiveActivity start error:", error)
        }
    }

    // Backwards-compat convenience
    func startActivity() { startActivity(initialUnit: nil, initialLanguage: nil) }

    // MARK: - Update

    func updateActivity(
        elapsedTime: TimeInterval,
        completedExercises: Int,
        totalWeightKg: Double,
        unit: WeightUnit? = nil,
        language: String? = nil
    ) {
        Task {
            guard let activity = currentActivity ?? Activity<WorkoutActivityAttributes>.activities.first else { return }

            let unitRaw = (unit?.rawValue ?? readUnitRaw()).lowercased()
            let langRaw = normalizeLang(language ?? readLanguageRaw())

            lastElapsed = elapsedTime
            lastCompleted = completedExercises
            lastTotalKg = totalWeightKg
            lastUnitRaw = unitRaw
            lastLangRaw = langRaw

            let state = WorkoutActivityAttributes.ContentState(
                elapsedTime: elapsedTime,
                completedExercises: completedExercises,
                totalWeight: totalWeightKg,
                weightUnitRaw: unitRaw,
                languageRaw: langRaw
            )
            await activity.update(using: state)
            currentActivity = activity
        }
    }

    // Backwards-compat convenience
    func updateActivity(elapsedTime: TimeInterval, completedExercises: Int, totalWeight: Double) {
        updateActivity(elapsedTime: elapsedTime,
                       completedExercises: completedExercises,
                       totalWeightKg: totalWeight,
                       unit: nil,
                       language: nil)
    }

    // MARK: - Live Refresh für Einheit/Sprache

    func refreshUnit(_ unit: WeightUnit) {
        Task {
            guard let activity = currentActivity ?? Activity<WorkoutActivityAttributes>.activities.first else { return }
            lastUnitRaw = unit.rawValue.lowercased()
            let state = WorkoutActivityAttributes.ContentState(
                elapsedTime: lastElapsed,
                completedExercises: lastCompleted,
                totalWeight: lastTotalKg,
                weightUnitRaw: lastUnitRaw,
                languageRaw: lastLangRaw
            )
            await activity.update(using: state)
            currentActivity = activity
        }
    }

    func refreshLanguage(_ languageCode: String) {
        Task {
            guard let activity = currentActivity ?? Activity<WorkoutActivityAttributes>.activities.first else { return }
            lastLangRaw = normalizeLang(languageCode)
            let state = WorkoutActivityAttributes.ContentState(
                elapsedTime: lastElapsed,
                completedExercises: lastCompleted,
                totalWeight: lastTotalKg,
                weightUnitRaw: lastUnitRaw,
                languageRaw: lastLangRaw
            )
            await activity.update(using: state)
            currentActivity = activity
        }
    }

    // MARK: - End

    func endActivity() {
        Task {
            guard let activity = currentActivity ?? Activity<WorkoutActivityAttributes>.activities.first else { return }
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }

    // MARK: - Defaults (App + App-Group)

    private func readUnitRaw() -> String {
        UserDefaults(suiteName: APP_GROUP_ID)?.string(forKey: "units.weight")
        ?? UserDefaults.standard.string(forKey: "units.weight")
        ?? "kg"
    }

    private func readLanguageRaw() -> String {
        UserDefaults(suiteName: APP_GROUP_ID)?.string(forKey: "app.language")
        ?? UserDefaults.standard.string(forKey: "app.language")
        ?? (Locale.current.languageCode ?? "en")
    }
}

private func normalizeLang(_ s: String) -> String {
    s.lowercased().hasPrefix("de") ? "de" : "en"
}
