import Foundation
import FirebaseFirestore

/// Schlankes, feed-taugliches Training (aus der Cloud)
public struct SocialTraining: Identifiable, Codable, Hashable {
    @DocumentID public var id: String?
    public var userId: String
    public var userDisplayName: String
    public var type: String            // z.B. "Push", "Pull", "Legs", "Run"
    public var startedAt: Date
    public var createdAt: Date         // Zeit des Schreibens (Index/Sortierung)
    public var durationMin: Int
    public var kcal: Int?
    public var notes: String?

    public init(id: String? = nil,
                userId: String,
                userDisplayName: String,
                type: String,
                startedAt: Date,
                createdAt: Date = Date(),
                durationMin: Int,
                kcal: Int? = nil,
                notes: String? = nil) {
        self.id = id
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.type = type
        self.startedAt = startedAt
        self.createdAt = createdAt
        self.durationMin = durationMin
        self.kcal = kcal
        self.notes = notes
    }
}
