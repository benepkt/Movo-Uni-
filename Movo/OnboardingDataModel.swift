import Foundation
import SwiftUI

// MARK: - Onboarding Data Model

struct OnboardingData {
    var userName: String = ""
    var fitnessGoals: Set<FitnessGoal> = []
    var experienceLevel: ExperienceLevel = .beginner
    var trainingFrequency: Int = 3
    var age: Int?
    var gender: Gender?
    var equipment: Set<Equipment> = []
    var trainingLocation: TrainingLocation = .gym
    var muscleFocusRegions: [String] = [] // Store as String array instead of Set<MuscleRegion>
    var selectedPackageIdentifier: String?
    var hasCompletedTemplateCreation: Bool = false
    
    // Helper to check if onboarding is complete
    var isComplete: Bool {
        !fitnessGoals.isEmpty && selectedPackageIdentifier != nil
    }
}

// MARK: - Codable Implementation

extension OnboardingData: Codable {
    enum CodingKeys: String, CodingKey {
        case userName
        case fitnessGoals
        case experienceLevel
        case trainingFrequency
        case age
        case gender
        case equipment
        case trainingLocation
        case muscleFocusRegions
        case selectedPackageIdentifier
        case hasCompletedTemplateCreation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        
        // Decode arrays and convert to sets
        let goalsArray = try container.decodeIfPresent([FitnessGoal].self, forKey: .fitnessGoals) ?? []
        fitnessGoals = Set(goalsArray)
        
        experienceLevel = try container.decodeIfPresent(ExperienceLevel.self, forKey: .experienceLevel) ?? .beginner
        trainingFrequency = try container.decodeIfPresent(Int.self, forKey: .trainingFrequency) ?? 3
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
        
        let equipmentArray = try container.decodeIfPresent([Equipment].self, forKey: .equipment) ?? []
        equipment = Set(equipmentArray)
        
        trainingLocation = try container.decodeIfPresent(TrainingLocation.self, forKey: .trainingLocation) ?? .gym
        muscleFocusRegions = try container.decodeIfPresent([String].self, forKey: .muscleFocusRegions) ?? []
        selectedPackageIdentifier = try container.decodeIfPresent(String.self, forKey: .selectedPackageIdentifier)
        hasCompletedTemplateCreation = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedTemplateCreation) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userName, forKey: .userName)
        
        // Convert sets to arrays for encoding
        try container.encode(Array(fitnessGoals), forKey: .fitnessGoals)
        try container.encode(experienceLevel, forKey: .experienceLevel)
        try container.encode(trainingFrequency, forKey: .trainingFrequency)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encode(Array(equipment), forKey: .equipment)
        try container.encode(trainingLocation, forKey: .trainingLocation)
        try container.encode(muscleFocusRegions, forKey: .muscleFocusRegions)
        try container.encodeIfPresent(selectedPackageIdentifier, forKey: .selectedPackageIdentifier)
        try container.encode(hasCompletedTemplateCreation, forKey: .hasCompletedTemplateCreation)
    }
}

// MARK: - Fitness Goals

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case loseWeight
    case buildMuscle
    case stayFit
    case gainStrength
    case improveEndurance
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .loseWeight: return "flame.fill"
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .stayFit: return "bolt.fill"
        case .gainStrength: return "dumbbell.fill"
        case .improveEndurance: return "figure.run"
        }
    }
    
    var color: Color {
        switch self {
        case .loseWeight: return .orange
        case .buildMuscle: return .blue
        case .stayFit: return .green
        case .gainStrength: return .purple
        case .improveEndurance: return .red
        }
    }
    
    var titleKey: String {
        "onboarding.goal.\(rawValue)"
    }
    
    var descriptionKey: String {
        "onboarding.goal.\(rawValue).desc"
    }
    
    func localizedTitle(_ appSettings: AppSettings) -> String {
        let key = "onboarding.goal.\(rawValue)"
        return appSettings.localized(key)
    }
    
    func localizedDescription(_ appSettings: AppSettings) -> String {
        let key = "onboarding.goal.\(rawValue).desc"
        return appSettings.localized(key)
    }
}

// MARK: - Experience Level

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .beginner: return "star.fill"
        case .intermediate: return "star.leadinghalf.filled"
        case .advanced: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
    
    var titleKey: String {
        "onboarding.level.\(rawValue)"
    }
    
    var descriptionKey: String {
        "onboarding.level.\(rawValue).desc"
    }
    
    func localizedTitle(_ appSettings: AppSettings) -> String {
        let key = "onboarding.level.\(rawValue)"
        return appSettings.localized(key)
    }
    
    func localizedDescription(_ appSettings: AppSettings) -> String {
        let key = "onboarding.level.\(rawValue).desc"
        return appSettings.localized(key)
    }
}

// MARK: - Equipment

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case fullGym
    case dumbbells
    case barbell
    case kettlebell
    case resistanceBands
    case bodyweight
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .fullGym: return "building.2.fill"
        case .dumbbells: return "dumbbell.fill"
        case .barbell: return "figure.strengthtraining.traditional"
        case .kettlebell: return "figure.core.training"
        case .resistanceBands: return "bandage.fill"
        case .bodyweight: return "figure.arms.open"
        }
    }
    
    var titleKey: String {
        "onboarding.equipment.\(rawValue)"
    }
    
    func localizedTitle(_ appSettings: AppSettings) -> String {
        let key = "onboarding.equipment.\(rawValue)"
        return appSettings.localized(key)
    }
}

// MARK: - Training Location

enum TrainingLocation: String, Codable, CaseIterable, Identifiable {
    case gym
    case home
    case outdoor
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .gym: return "building.2.fill"
        case .home: return "house.fill"
        case .outdoor: return "leaf.fill"
        }
    }
    
    var titleKey: String {
        "onboarding.location.\(rawValue)"
    }
    
    func localizedTitle(_ appSettings: AppSettings) -> String {
        let key = "onboarding.location.\(rawValue)"
        return appSettings.localized(key)
    }
}

// MARK: - Gender

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case other
    case preferNotToSay
    
    var id: String { rawValue }
    
    var titleKey: String {
        "onboarding.gender.\(rawValue)"
    }
    
    func localizedTitle(_ appSettings: AppSettings) -> String {
        let key = "onboarding.gender.\(rawValue)"
        return appSettings.localized(key)
    }
}

// MARK: - AppStorage Extensions

extension OnboardingData {
    private static let userNameKey = "onboarding.userName"
    private static let dataKey = "onboarding.data"
    
    static func load() -> OnboardingData {
        guard let data = UserDefaults.standard.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode(OnboardingData.self, from: data) else {
            return OnboardingData()
        }
        return decoded
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.dataKey)
        }
        // Also save userName separately for easy access
        UserDefaults.standard.set(userName, forKey: Self.userNameKey)
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: dataKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
    }
}
