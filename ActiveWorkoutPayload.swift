import Foundation

public struct ActiveWorkoutPayload: Codable, Equatable {
    public var isActive: Bool
    public var workoutId: String?
    public var workoutName: String?
    public var exercises: [ExerciseItem]
    public var selectedExerciseId: String?

    public init(isActive: Bool,
                workoutId: String? = nil,
                workoutName: String? = nil,
                exercises: [ExerciseItem] = [],
                selectedExerciseId: String? = nil) {
        self.isActive = isActive
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.exercises = exercises
        self.selectedExerciseId = selectedExerciseId
    }
    
    public struct LoggedSetItem: Codable, Equatable, Identifiable {
        public var id: String
        public var reps: Int
        public var weight: Double
        public var completed: Bool           // ✅ NEU
    }

    public struct ExerciseItem: Codable, Equatable, Identifiable {
        public var id: String
        public var name: String
        public var order: Int
        public var setCount: Int
        public var sets: [LoggedSetItem]        // ✅ neu
    }

    }
