import Foundation

struct TrainingTemplate: Identifiable, Codable, Equatable {
    var id: String            // Firestore-Dokument-ID (String)
    var name: String
    var exercises: [String]
    var activities: [WorkoutActivityBlock]

    // Sync-Metadaten
    var ownerId: String       // UID des Users oder "guest:<device>"
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         exercises: [String],
         activities: [WorkoutActivityBlock] = [],
         ownerId: String,
         updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.activities = activities
        self.ownerId = ownerId
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, exercises, activities, ownerId, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        exercises = try container.decodeIfPresent([String].self, forKey: .exercises) ?? []
        activities = try container.decodeIfPresent([WorkoutActivityBlock].self, forKey: .activities) ?? []
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "local"
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    static func == (lhs: TrainingTemplate, rhs: TrainingTemplate) -> Bool {
        lhs.id == rhs.id
    }
}
