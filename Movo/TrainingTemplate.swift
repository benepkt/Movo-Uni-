import Foundation

struct TrainingTemplate: Identifiable, Codable, Equatable {
    var id: String            // Firestore-Dokument-ID (String)
    var name: String
    var exercises: [String]

    // Sync-Metadaten
    var ownerId: String       // UID des Users oder "guest:<device>"
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         exercises: [String],
         ownerId: String,
         updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.ownerId = ownerId
        self.updatedAt = updatedAt
    }

    static func == (lhs: TrainingTemplate, rhs: TrainingTemplate) -> Bool {
        lhs.id == rhs.id
    }
}
