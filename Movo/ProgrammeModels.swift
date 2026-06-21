import Foundation

// MARK: - Program Definition (Blueprint)
struct TrainingProgram: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let difficulty: ProgramDifficulty
    let durationWeeks: Int
    let isUnlimited: Bool
    let smartOrderingEnabled: Bool
    
    // The "Routines" available in this program
    // We store full templates here for simplicity in this pilot
    let routines: [TrainingTemplate]
    
    // Schedule: Which routine on which day?
    // Key: Weekday (1=Sunday, 2=Monday, ... 7=Saturday)
    // Value: Template ID
    let schedule: [Int: String]
    
    enum ProgramDifficulty: String, Codable {
        case beginner = "Anfänger"
        case intermediate = "Fortgeschritten"
        case advanced = "Profi"
    }

    init(
        id: String,
        title: String,
        description: String,
        difficulty: ProgramDifficulty,
        durationWeeks: Int,
        isUnlimited: Bool = false,
        smartOrderingEnabled: Bool = true,
        routines: [TrainingTemplate],
        schedule: [Int: String]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.difficulty = difficulty
        self.durationWeeks = durationWeeks
        self.isUnlimited = isUnlimited
        self.smartOrderingEnabled = smartOrderingEnabled
        self.routines = routines
        self.schedule = schedule
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, difficulty, durationWeeks, isUnlimited, smartOrderingEnabled, routines, schedule
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Trainingsplan"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        difficulty = try container.decodeIfPresent(ProgramDifficulty.self, forKey: .difficulty) ?? .intermediate
        durationWeeks = try container.decodeIfPresent(Int.self, forKey: .durationWeeks) ?? 8
        isUnlimited = try container.decodeIfPresent(Bool.self, forKey: .isUnlimited) ?? false
        smartOrderingEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartOrderingEnabled) ?? true
        routines = try container.decodeIfPresent([TrainingTemplate].self, forKey: .routines) ?? []
        schedule = try container.decodeIfPresent([Int: String].self, forKey: .schedule) ?? [:]
    }
}

// MARK: - Plan Generator Models
enum PlanGoal: String, CaseIterable, Hashable, Codable {
    case hypertrophy = "Muskelaufbau"
    case strength = "Kraft"
    case endurance = "Ausdauer"
    case weightLoss = "Abnehmen"
}



// MARK: - Active Program (User Progress)
struct ActiveProgram: Codable {
    let programId: String
    let startDate: Date
    
    // Compute current week based on start date
    var currentWeek: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: startDate, to: Date())
        return (components.weekOfYear ?? 0) + 1
    }
    
    // Compute exact day of program (1...duration*7)
    var currentDayOfProgram: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return (components.day ?? 0) + 1
    }
}
