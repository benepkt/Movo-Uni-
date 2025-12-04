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
    var muscleGroup: String
    var instructions: String
    var imageName: String

    // NEU: mehrere Notizen
    var notes: [Note] = []

    // weitere Felder von dir (optional)
    var previousMax: Double? = nil
    var videoURL: URL? = nil
    var techniqueImageName: String? = nil

    var muscleGroups: [String] {
        muscleGroup
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: String = "Unbekannt",
        instructions: String = "Keine Anleitung verfügbar",
        imageName: String = "default_muscle",
        notes: [Note] = []
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.instructions = instructions
        self.imageName = imageName
        self.notes = notes
    }
}
