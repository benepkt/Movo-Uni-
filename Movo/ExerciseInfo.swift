import SwiftUI
import Foundation

struct Note: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var text: String
    var date: Date

    init(id: UUID = UUID(), text: String = "", date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }
}

struct ExerciseInfo: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var muscleGroup: String // Legacy support, primarily used for display if primaryMuscle is missing
    var instructions: String
    var imageName: String

    // Enhanced Metadata
    var primaryMuscle: String?
    var secondaryMuscles: [String]?
    var equipment: String?     // e.g., "Dumbbell", "Machine", "Bodyweight"
    var classification: String? // e.g., "Compound", "Isolation"
    var category: String       // "Strength", "Cardio", "Activity"

    // NEU: mehrere Notizen
    var notes: [Note] = []

    // weitere Felder von dir (optional)
    var previousMax: Double? = nil
    var videoURL: URL? = nil
    var techniqueImageName: String? = nil

    var muscleGroups: [String] {
        if let primary = primaryMuscle {
            var groups = [primary]
            if let secondary = secondaryMuscles {
                groups.append(contentsOf: secondary)
            }
            return groups
        } else {
            return muscleGroup
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: String = "Unbekannt",
        instructions: String = "Keine Anleitung verfügbar",
        imageName: String = "default_muscle",
        notes: [Note] = [],
        primaryMuscle: String? = nil,
        secondaryMuscles: [String]? = nil,
        equipment: String? = nil,
        classification: String? = nil,
        category: String = "Strength"
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.instructions = instructions
        self.imageName = imageName
        self.notes = notes
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.classification = classification
        self.category = category
    }

    // MARK: - Codable Migration Logic
    enum CodingKeys: String, CodingKey {
        case id, name, muscleGroup, instructions, imageName, notes, previousMax, videoURL, techniqueImageName
        case primaryMuscle, secondaryMuscles, equipment, classification, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        muscleGroup = try container.decodeIfPresent(String.self, forKey: .muscleGroup) ?? "Unbekannt"
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions) ?? "Keine Anleitung verfügbar"
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName) ?? "default_muscle"
        notes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
        
        previousMax = try container.decodeIfPresent(Double.self, forKey: .previousMax)
        videoURL = try container.decodeIfPresent(URL.self, forKey: .videoURL)
        techniqueImageName = try container.decodeIfPresent(String.self, forKey: .techniqueImageName)
        
        // Enhanced Metadata Defaults
        primaryMuscle = try container.decodeIfPresent(String.self, forKey: .primaryMuscle)
        secondaryMuscles = try container.decodeIfPresent([String].self, forKey: .secondaryMuscles)
        equipment = try container.decodeIfPresent(String.self, forKey: .equipment)
        classification = try container.decodeIfPresent(String.self, forKey: .classification)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Strength"
    }
}
