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
    private var lastModeRaw: String = "strength"
    private var lastActivityTitle: String = ""
    private var lastDistanceKm: Double = 0
    private var lastPaceOrSpeed: String = ""
    private var lastActivityIcon: String = "figure.strengthtraining.traditional"

    private init() {
        Task { [weak self] in
            await self?.keepOnlyOneActiveActivity()
            if let existing = Activity<WorkoutActivityAttributes>.activities.first {
                self?.currentActivity = existing
            }
        }
    }

    // MARK: - Start

    func startActivity(
        initialUnit: WeightUnit? = nil,
        initialLanguage: String? = nil,
        modeRaw: String = "strength",
        activityTitle: String = "",
        activityIcon: String = "figure.strengthtraining.traditional"
    ) {
        Task {
            await keepOnlyOneActiveActivity()

            if let existing = currentActivity ?? Activity<WorkoutActivityAttributes>.activities.first {
                currentActivity = existing
                updateActivity(
                    elapsedTime: lastElapsed,
                    completedExercises: lastCompleted,
                    totalWeightKg: lastTotalKg,
                    unit: initialUnit,
                    language: initialLanguage,
                    modeRaw: modeRaw,
                    activityTitle: activityTitle.isEmpty ? lastActivityTitle : activityTitle,
                    distanceKm: lastDistanceKm,
                    paceOrSpeed: lastPaceOrSpeed,
                    activityIcon: activityIcon
                )
                return
            }

            let unitRaw = (initialUnit?.rawValue ?? readUnitRaw()).lowercased()
            let langRaw = normalizeLang(initialLanguage ?? readLanguageRaw())

            lastElapsed = 0
            lastCompleted = 0
            lastTotalKg = 0
            lastUnitRaw = unitRaw
            lastLangRaw = langRaw
            lastModeRaw = modeRaw
            lastActivityTitle = activityTitle
            lastDistanceKm = 0
            lastPaceOrSpeed = ""
            lastActivityIcon = activityIcon

            let attributes = WorkoutActivityAttributes(workoutID: UUID(), startedAt: Date())
            let initialState = WorkoutActivityAttributes.ContentState(
                elapsedTime: 0,
                completedExercises: 0,
                totalWeight: 0,         // immer kg
                weightUnitRaw: unitRaw,
                languageRaw: langRaw,
                modeRaw: modeRaw,
                activityTitle: activityTitle,
                distanceKm: 0,
                paceOrSpeed: "",
                activityIcon: activityIcon
            )

            do {
                let activity = try Activity<WorkoutActivityAttributes>.request(
                    attributes: attributes,
                    contentState: initialState,
                    pushType: nil
                )
                currentActivity = activity
                await keepOnlyOneActiveActivity()
            } catch {
                print("LiveActivity start error:", error)
            }
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
        language: String? = nil,
        modeRaw: String? = nil,
        activityTitle: String? = nil,
        distanceKm: Double? = nil,
        paceOrSpeed: String? = nil,
        activityIcon: String? = nil
    ) {
        Task {
            await keepOnlyOneActiveActivity()
            guard let activity = currentActivity ?? Activity<WorkoutActivityAttributes>.activities.first else { return }

            let unitRaw = (unit?.rawValue ?? readUnitRaw()).lowercased()
            let langRaw = normalizeLang(language ?? readLanguageRaw())

            lastElapsed = elapsedTime
            lastCompleted = completedExercises
            lastTotalKg = totalWeightKg
            lastUnitRaw = unitRaw
            lastLangRaw = langRaw
            lastModeRaw = modeRaw ?? lastModeRaw
            lastActivityTitle = activityTitle ?? lastActivityTitle
            lastDistanceKm = distanceKm ?? lastDistanceKm
            lastPaceOrSpeed = paceOrSpeed ?? lastPaceOrSpeed
            lastActivityIcon = activityIcon ?? lastActivityIcon

            let state = WorkoutActivityAttributes.ContentState(
                elapsedTime: elapsedTime,
                completedExercises: completedExercises,
                totalWeight: totalWeightKg,
                weightUnitRaw: unitRaw,
                languageRaw: langRaw,
                modeRaw: lastModeRaw,
                activityTitle: lastActivityTitle,
                distanceKm: lastDistanceKm,
                paceOrSpeed: lastPaceOrSpeed,
                activityIcon: lastActivityIcon
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
            await keepOnlyOneActiveActivity()
            guard let activity = currentActivity ?? Activity<WorkoutActivityAttributes>.activities.first else { return }
            lastUnitRaw = unit.rawValue.lowercased()
            let state = WorkoutActivityAttributes.ContentState(
                elapsedTime: lastElapsed,
                completedExercises: lastCompleted,
                totalWeight: lastTotalKg,
                weightUnitRaw: lastUnitRaw,
                languageRaw: lastLangRaw,
                modeRaw: lastModeRaw,
                activityTitle: lastActivityTitle,
                distanceKm: lastDistanceKm,
                paceOrSpeed: lastPaceOrSpeed,
                activityIcon: lastActivityIcon
            )
            await activity.update(using: state)
            currentActivity = activity
        }
    }

    func refreshLanguage(_ languageCode: String) {
        Task {
            await keepOnlyOneActiveActivity()
            guard let activity = currentActivity ?? Activity<WorkoutActivityAttributes>.activities.first else { return }
            lastLangRaw = normalizeLang(languageCode)
            let state = WorkoutActivityAttributes.ContentState(
                elapsedTime: lastElapsed,
                completedExercises: lastCompleted,
                totalWeight: lastTotalKg,
                weightUnitRaw: lastUnitRaw,
                languageRaw: lastLangRaw,
                modeRaw: lastModeRaw,
                activityTitle: lastActivityTitle,
                distanceKm: lastDistanceKm,
                paceOrSpeed: lastPaceOrSpeed,
                activityIcon: lastActivityIcon
            )
            await activity.update(using: state)
            currentActivity = activity
        }
    }

    // MARK: - End

    func endActivity() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }

    private func keepOnlyOneActiveActivity() async {
        let activities = Activity<WorkoutActivityAttributes>.activities
        guard !activities.isEmpty else {
            currentActivity = nil
            return
        }

        let keeper = currentActivity.flatMap { current in
            activities.first(where: { $0.id == current.id })
        } ?? activities.first

        for activity in activities where activity.id != keeper?.id {
            await activity.end(dismissalPolicy: .immediate)
        }

        currentActivity = keeper
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
