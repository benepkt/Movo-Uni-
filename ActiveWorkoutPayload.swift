import Foundation

public struct ActiveWorkoutPayload: Codable, Equatable {
    public var isActive: Bool
    public var workoutId: String?
    public var workoutName: String?
    public var exercises: [ExerciseItem]
    public var selectedExerciseId: String?
    public var restTimer: RestTimerState?

    public init(isActive: Bool,
                workoutId: String? = nil,
                workoutName: String? = nil,
                exercises: [ExerciseItem] = [],
                selectedExerciseId: String? = nil,
                restTimer: RestTimerState? = nil) {
        self.isActive = isActive
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.exercises = exercises
        self.selectedExerciseId = selectedExerciseId
        self.restTimer = restTimer
    }

    public struct RestTimerState: Codable, Equatable {
        public var isActive: Bool
        public var remaining: TimeInterval
        public var total: TimeInterval

        public init(isActive: Bool, remaining: TimeInterval, total: TimeInterval) {
            self.isActive = isActive
            self.remaining = remaining
            self.total = total
        }
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

public struct WatchStartOptionsPayload: Codable, Equatable {
    public var templates: [WatchStartItem]
    public var planItems: [WatchStartItem]
    public var activePlanTitle: String?
    public var todaysPlanItemId: String?

    public init(templates: [WatchStartItem] = [],
                planItems: [WatchStartItem] = [],
                activePlanTitle: String? = nil,
                todaysPlanItemId: String? = nil) {
        self.templates = templates
        self.planItems = planItems
        self.activePlanTitle = activePlanTitle
        self.todaysPlanItemId = todaysPlanItemId
    }
}

public struct WatchStartItem: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var exerciseCount: Int
    public var source: Source

    public enum Source: String, Codable, Equatable {
        case template
        case plan
    }

    public init(id: String, title: String, subtitle: String, exerciseCount: Int, source: Source) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.exerciseCount = exerciseCount
        self.source = source
    }
}
