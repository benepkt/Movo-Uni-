import Foundation
import CoreLocation
import MapKit

// MARK: - ExerciseSet
struct ExerciseSet: Identifiable, Codable, Equatable {
    let id: UUID
    var weight: String
    var reps: String
    var isCompleted: Bool

    init(id: UUID = UUID(), weight: String, reps: String, isCompleted: Bool = false) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }
}

// MARK: - TrainingType
enum TrainingType: String, Codable, CaseIterable, Identifiable {
    case legs, arms, back, chest, fullBody
    var id: String { rawValue }

    var title: String {
        switch self {
        case .legs:     return "Beine"
        case .arms:     return "Arme"
        case .back:     return "Rücken"
        case .chest:    return "Brust"
        case .fullBody: return "Ganzkörper"
        }
    }

    var systemImage: String {
        switch self {
        case .legs:     return "figure.run"
        case .arms:     return "dumbbell"
        case .back:     return UIImage(systemName: "figure.pullup") != nil ? "figure.pullup" : "figure.strengthtraining.traditional"
        case .chest:    return "figure.strengthtraining.traditional"
        case .fullBody: return "staroflife.fill"
        }
    }
}

// MARK: - Exercise
struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sets: [ExerciseSet]
    var imageName: String? = nil

    init(id: UUID = UUID(), name: String, sets: [ExerciseSet] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }

    var totalWeight: Double {
        sets.reduce(0) { acc, set in
            let w = Double(set.weight) ?? 0
            let r = Double(set.reps) ?? 0
            return acc + (w * r)
        }
    }

    var isCompleted: Bool {
        sets.allSatisfy { $0.isCompleted }
    }
}

struct WorkoutActivityBlock: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var kindRaw: String?
    var emoji: String?
    var duration: TimeInterval
    var distanceKm: Double?
    var resistanceLevel: Double?
    var inclinePercent: Double?
    var averageWatts: Double?
    var activeCalories: Double?
    var averageHeartRate: Double?
    var elevationGainM: Double?
    var perceivedEffort: Int?
    var note: String?

    init(
        id: UUID = UUID(),
        title: String,
        kindRaw: String? = nil,
        emoji: String? = nil,
        duration: TimeInterval = 0,
        distanceKm: Double? = nil,
        resistanceLevel: Double? = nil,
        inclinePercent: Double? = nil,
        averageWatts: Double? = nil,
        activeCalories: Double? = nil,
        averageHeartRate: Double? = nil,
        elevationGainM: Double? = nil,
        perceivedEffort: Int? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kindRaw
        self.emoji = emoji
        self.duration = duration
        self.distanceKm = distanceKm
        self.resistanceLevel = resistanceLevel
        self.inclinePercent = inclinePercent
        self.averageWatts = averageWatts
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.elevationGainM = elevationGainM
        self.perceivedEffort = perceivedEffort
        self.note = note
    }
}

struct TrainingEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date

    var title: String
    var exercises: [Exercise]
    var duration: TimeInterval
    var totalWeight: Double
    var emoji: String?
    var updatedAt: Date
    var routePolyline: String?
    var cardioType: String?

    // Manuell erfasste Distanz in Kilometern. Die berechnete `distanceKm`
    // aus Routen bleibt in TrainingEntry+RunningMetrics erhalten.
    var loggedDistanceKm: Double?
    var activeCalories: Double?
    var averageHeartRate: Double?
    var elevationGainM: Double?
    var perceivedEffort: Int?
    var activityNote: String?
    var healthSourceName: String?
    var healthDeviceName: String?
    var healthWorkoutActivityRaw: UInt?
    var isIndoorWorkout: Bool?
    var activities: [WorkoutActivityBlock]

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        exercises: [Exercise] = [],
        duration: TimeInterval = 0,
        totalWeight: Double? = nil,
        emoji: String? = nil,
        updatedAt: Date = Date(),
        routePolyline: String? = nil,
        cardioType: String? = nil,
        distanceKm: Double? = nil,          // 👈 NEU, Default = nil
        activeCalories: Double? = nil,
        averageHeartRate: Double? = nil,
        elevationGainM: Double? = nil,
        perceivedEffort: Int? = nil,
        activityNote: String? = nil,
        healthSourceName: String? = nil,
        healthDeviceName: String? = nil,
        healthWorkoutActivityRaw: UInt? = nil,
        isIndoorWorkout: Bool? = nil,
        activities: [WorkoutActivityBlock] = []
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.exercises = exercises
        self.duration = duration
        self.totalWeight = totalWeight ?? exercises.reduce(0) { $0 + $1.totalWeight }
        self.emoji = emoji
        self.updatedAt = updatedAt
        self.routePolyline = routePolyline
        self.cardioType = cardioType
        self.loggedDistanceKm = distanceKm
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.elevationGainM = elevationGainM
        self.perceivedEffort = perceivedEffort
        self.activityNote = activityNote
        self.healthSourceName = healthSourceName
        self.healthDeviceName = healthDeviceName
        self.healthWorkoutActivityRaw = healthWorkoutActivityRaw
        self.isIndoorWorkout = isIndoorWorkout
        self.activities = activities
    }

    var isCompleted: Bool {
        exercises.allSatisfy { $0.isCompleted }
    }
}


// Für deine Merge-Logik in SyncService:
extension TrainingEntry {
    var updatedAtForSync: Date { updatedAt }
}
