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

// MARK: - TrainingEntry (⚠️ jetzt mit updatedAt)
struct TrainingEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date

    var title: String
    var exercises: [Exercise]
    var duration: TimeInterval
    var totalWeight: Double
    var emoji: String?
    var updatedAt: Date   // ⬅️ wird für Sync/Conflict-Resolution genutzt
    
    var routePolyline: String?    // optional für alte Einträge
    
    var cardioType: String?      // z.B. "Outdoor Walk", "Outdoor Run"



    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        exercises: [Exercise] = [],
        duration: TimeInterval = 0,
        totalWeight: Double? = nil,
        emoji: String? = nil,
        updatedAt: Date = Date(),  // ⬅️ Standard: jetzt
        routePolyline: String? = nil,  // 👈 default, damit alte Call-Sites kompilieren
        cardioType: String? = nil

        

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


    }

    var isCompleted: Bool {
        exercises.allSatisfy { $0.isCompleted }
    }
}

// Für deine Merge-Logik in SyncService:
extension TrainingEntry {
    var updatedAtForSync: Date { updatedAt }
}
