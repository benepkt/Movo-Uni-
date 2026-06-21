import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct WorkoutActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var elapsedTime: TimeInterval
        public var completedExercises: Int
        /// Gesamtgewicht in **kg** (intern immer kg!)
        public var totalWeight: Double
        /// "kg" oder "lb" – Anzeige-Einheit
        public var weightUnitRaw: String
        /// "de" oder "en" – Sprache für die Live Activity
        public var languageRaw: String
        /// "strength" oder "activity"
        public var modeRaw: String
        public var activityTitle: String
        public var distanceKm: Double
        public var paceOrSpeed: String
        public var activityIcon: String

        public init(
            elapsedTime: TimeInterval = 0,
            completedExercises: Int = 0,
            totalWeight: Double = 0,
            weightUnitRaw: String = "kg",
            languageRaw: String = "de",
            modeRaw: String = "strength",
            activityTitle: String = "",
            distanceKm: Double = 0,
            paceOrSpeed: String = "",
            activityIcon: String = "figure.strengthtraining.traditional"
        ) {
            self.elapsedTime = elapsedTime
            self.completedExercises = completedExercises
            self.totalWeight = totalWeight
            self.weightUnitRaw = weightUnitRaw
            self.languageRaw = languageRaw
            self.modeRaw = modeRaw
            self.activityTitle = activityTitle
            self.distanceKm = distanceKm
            self.paceOrSpeed = paceOrSpeed
            self.activityIcon = activityIcon
        }

        public static let preview: Self = .init(
            elapsedTime: 8*60+30,
            completedExercises: 5,
            totalWeight: 72.5,
            weightUnitRaw: "kg",
            languageRaw: "de",
            modeRaw: "strength",
            activityTitle: "Krafttraining",
            distanceKm: 0,
            paceOrSpeed: "",
            activityIcon: "figure.strengthtraining.traditional"
        )
    }

    public var workoutID: UUID
    public var startedAt: Date

    public init(workoutID: UUID = .init(), startedAt: Date = .init()) {
        self.workoutID = workoutID
        self.startedAt = startedAt
    }

    public static let preview: Self = .init()
}
