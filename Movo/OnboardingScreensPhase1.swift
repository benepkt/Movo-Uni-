// Onboarding Screens - Phase 1: Personalization
// Screens 1-6: Welcome, Goals, Level, Frequency, Questions, Muscle Focus

import SwiftUI

// MARK: - Screen 1: Welcome Screen

// MARK: - Screen 0: Welcome Animation
struct WelcomeAnimationScreen: View {
    @State private var animate = false
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private var isGerman: Bool {
        onboardingLanguage == "de"
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text(isGerman ? "Willkommen bei" : "Welcome to")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 20)
                
                Text("Movo")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(.white)
                    .scaleEffect(animate ? 1.0 : 0.8)
                    .opacity(animate ? 1 : 0)
                
                Text(isGerman ? "Dein persönlicher Gym Tracker." : "Your personal gym tracker.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 20)
            }
            .onAppear {
                withAnimation(.spring(duration: 0.8).delay(0.2)) {
                    animate = true
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Screen 1: Username
struct WelcomeNameScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @FocusState private var isFocused: Bool
    
    // Mock availability
    var isAvailable: Bool {
        return !data.userName.isEmpty && data.userName.count > 2
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Text("Choose a username")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                TextField(appSettings.localized("onboarding.name.placeholder") != "onboarding.name.placeholder" ? appSettings.localized("onboarding.name.placeholder") : "Username", text: $data.userName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal, 40)
                    .foregroundStyle(.white)
                    .tint(Color(hex: 0x4C5BFF))
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    if !data.userName.isEmpty {
                        // Cursor simulation or just blinking tint handled by TextField
                    }
                }
                
                if isAvailable {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                        Text("Available")
                            .foregroundStyle(Color.green)
                            .font(.subheadline.weight(.medium))
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Screen 2: Fitness Goals

struct FitnessGoalsScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @State private var showCards = false
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    // Helper function to get localized string based on onboarding language
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text(localizedOnboarding("onboarding.goals.title"))
                        .font(.largeTitle.bold())
                    
                    Text(localizedOnboarding("onboarding.goals.subtitle"))
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    ForEach(FitnessGoal.allCases) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: data.fitnessGoals.contains(goal),
                            show: showCards
                        ) {
                            withAnimation(.spring()) {
                                if data.fitnessGoals.contains(goal) {
                                    data.fitnessGoals.remove(goal)
                                } else {
                                    data.fitnessGoals.insert(goal)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6).delay(0.2)) {
                showCards = true
            }
        }
    }
}

private struct GoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let show: Bool
    let action: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) { // 1. Reduced spacing
                ZStack {
                    Circle()
                        .fill(goal.color.opacity(0.2))
                        .frame(width: 50, height: 50) // 2. Reduced size
                    
                    Image(systemName: goal.icon)
                        .font(.title3) // 3. Reduced font
                        .foregroundStyle(goal.color)
                }
                
                VStack(alignment: .leading, spacing: 2) { // 4. Reduced spacing
                    Text(localizedOnboarding(goal.titleKey))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(localizedOnboarding(goal.descriptionKey))
                        .font(.footnote) // 5. Smaller font
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color(hex: 0x4C5BFF) : .secondary)
            }
            .padding(12) // 6. Reduced padding
            .background(
                RoundedRectangle(cornerRadius: 16) // 7. Smaller radius
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color(hex: 0x4C5BFF).opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(show ? 1 : 0.8)
        .opacity(show ? 1 : 0)
    }
}

// MARK: - Screen 3: Experience Level

struct ExperienceLevelScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @State private var showCards = false
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text(localizedOnboarding("onboarding.level.title"))
                        .font(.title.bold())
                        .minimumScaleFactor(0.8)
                    
                    Text(localizedOnboarding("onboarding.level.subtitle"))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    ForEach(ExperienceLevel.allCases) { level in
                        LevelCard(
                            level: level,
                            isSelected: data.experienceLevel == level,
                            show: showCards
                        ) {
                            withAnimation(.spring()) {
                                data.experienceLevel = level
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6).delay(0.2)) {
                showCards = true
            }
        }
    }
}

private struct LevelCard: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let show: Bool
    let action: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) { // Reduced spacing
                ZStack {
                    Circle()
                        .fill(level.color.opacity(0.2))
                        .frame(width: 60, height: 60) // Reduced size
                    
                    Image(systemName: level.icon)
                        .font(.system(size: 28)) // Reduced font
                        .foregroundStyle(level.color)
                }
                
                VStack(spacing: 4) { // Reduced spacing
                    Text(localizedOnboarding(level.titleKey))
                        .font(.title3.bold()) // Smaller font
                        .foregroundStyle(.primary)
                    
                    Text(localizedOnboarding(level.descriptionKey))
                        .font(.footnote) // Smaller font
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16) // Reduced padding
            .background(
                RoundedRectangle(cornerRadius: 20) // Smaller radius
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(isSelected ? Color(hex: 0x4C5BFF).opacity(0.8) : Color.clear, lineWidth: 3)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(show ? 1 : 0.8)
        .opacity(show ? 1 : 0)
    }
}

// MARK: - Screen 4: Training Frequency

struct TrainingFrequencyScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @State private var progress: CGFloat = 0
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private let frequencies = [2, 3, 4, 5]
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(localizedOnboarding("onboarding.frequency.title"))
                    .font(.largeTitle.bold())
                
                Text(localizedOnboarding("onboarding.frequency.subtitle"))
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            // Progress ring showing commitment
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: 0x4C5BFF), Color(hex: 0x3846E8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(data.trainingFrequency)")
                        .font(.system(size: 48, weight: .bold))
                    Text(localizedOnboarding("onboarding.frequency.perweek"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 1.5).delay(0.3)) {
                    progress = CGFloat(data.trainingFrequency) / 7.0
                }
            }
            .onChange(of: data.trainingFrequency) { newValue in
                withAnimation(.spring()) {
                    progress = CGFloat(newValue) / 7.0
                }
            }
            
            VStack(spacing: 12) {
                ForEach(frequencies, id: \.self) { freq in
                    Button {
                        withAnimation(.spring()) {
                            data.trainingFrequency = freq
                        }
                    } label: {
                        HStack {
                            Text(String(format: localizedOnboarding("onboarding.frequency.times"), freq))
                                .font(.headline)
                            
                            Spacer()
                            
                            if freq == 4 {
                                Text("⭐")
                                    .font(.title3)
                            }
                        }
                        .foregroundStyle(data.trainingFrequency == freq ? .white : .secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(data.trainingFrequency == freq ? Color(hex: 0x4C5BFF) : Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 5: Personal Questions

// MARK: - Screen 5: Birthday
struct BirthdayScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    @State private var day: String = ""
    @State private var month: String = ""
    @State private var year: String = ""
    
    @FocusState private var focusedField: DateField?
    
    enum DateField {
        case day, month, year
    }
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var age: Int? {
        guard let d = Int(day), let m = Int(month), let y = Int(year) else { return nil }
        let components = DateComponents(year: y, month: m, day: d)
        guard let date = Calendar.current.date(from: components) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year
    }
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(onboardingLanguage == "de" ? "Wann hast du Geburtstag?" : "When's your birthday?")
                    .font(.largeTitle.bold())
                
                // Visual Date Display
                HStack(spacing: 0) {
                    DateInputView(placeholder: onboardingLanguage == "de" ? "TT" : "DD", text: $day, focus: $focusedField, field: .day, next: .month)
                        .frame(width: 60)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 40)
                    
                    DateInputView(placeholder: onboardingLanguage == "de" ? "MM" : "MM", text: $month, focus: $focusedField, field: .month, next: .year)
                        .frame(width: 60)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 40)
                    
                    DateInputView(placeholder: onboardingLanguage == "de" ? "JJJJ" : "YYYY", text: $year, focus: $focusedField, field: .year, next: nil)
                        .frame(width: 100)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.top, 24)
                
                // Subtitle removed as per user request
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Redundant button removed as per user request
            // Main "Continue" button handles progression
        }
        .padding(.horizontal, 24)
        .onAppear {
            focusedField = .day
            // Load existing data if available
            if let existingAge = data.age {
                // If we only have age, we can't reconstruct birthday. 
                // We'll leave it empty or default to standard.
                // For this redesign, we assume fresh start or just calculate age from input.
            }
        }
        .onChange(of: age) { newAge in
            if let a = newAge {
                data.age = a
            }
        }
    }
}

private struct DateInputView: View {
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<BirthdayScreen.DateField?>.Binding
    let field: BirthdayScreen.DateField
    let next: BirthdayScreen.DateField?
    
    var maxChars: Int { field == .year ? 4 : 2 }
    
    var body: some View {
        ZStack {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3)) // Visible placeholder
                    .allowsHitTesting(false)
            }
            
            TextField("", text: $text)
                .focused(focus, equals: field)
                .keyboardType(.numberPad)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: field == .year ? 100 : 60)
                .foregroundStyle(.white)
                .tint(Color(hex: 0x4C5BFF))
                .onChange(of: text) { newValue in
                    if newValue.count > maxChars {
                        text = String(newValue.prefix(maxChars))
                    }
                    if text.count == maxChars {
                        if let n = next {
                            focus.wrappedValue = n
                        } else {
                            focus.wrappedValue = nil
                        }
                    }
                }
        }
        .padding(.vertical, 8)
        // Background removed here as it's now handled by the parent container
        // .background(
        //     RoundedRectangle(cornerRadius: 12)
        //         .fill(Color.white.opacity(0.05))
        // )
    }
}

// MARK: - Screen 6: Gender
struct GenderScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(localizedOnboarding("onboarding.personal.gender"))
                    .font(.largeTitle.bold())
                
                Text(onboardingLanguage == "de" ? "Hilft uns, deinen Trainingsplan anzupassen." : "Helps us tailor your workout plan.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                ForEach([Gender.male, Gender.female, Gender.other]) { gender in
                    Button {
                        withAnimation(.spring()) {
                            data.gender = gender
                        }
                    } label: {
                        HStack {
                            Text(localizedOnboarding(gender.titleKey))
                                .font(.headline)
                            
                            Spacer()
                            
                            if data.gender == gender {
                                Image(systemName: "checkmark")
                                    .font(.headline)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(data.gender == gender ? Color(hex: 0x4C5BFF) : Color.white.opacity(0.05))
                        )
                        .foregroundStyle(data.gender == gender ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 6: Equipment
struct EquipmentScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text(localizedOnboarding("onboarding.personal.equipment"))
                        .font(.largeTitle.bold())
                    
                    Text(onboardingLanguage == "de" ? "Wähle alles aus, was dir zur Verfügung steht." : "Select everything you have access to.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(Equipment.allCases) { equipment in
                        EquipmentChip(
                            equipment: equipment,
                            isSelected: data.equipment.contains(equipment)
                        ) {
                            withAnimation(.spring()) {
                                if data.equipment.contains(equipment) {
                                    data.equipment.remove(equipment)
                                } else {
                                    data.equipment.insert(equipment)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Screen 7: Location
struct LocationScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(localizedOnboarding("onboarding.personal.location"))
                    .font(.largeTitle.bold())
                
                Text(onboardingLanguage == "de" ? "Wir nutzen dies, um dir Fitnessstudios in deiner Nähe zu empfehlen." : "We use this to recommend gyms near you.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                ForEach(TrainingLocation.allCases) { location in
                    Button {
                        withAnimation(.spring()) {
                            data.trainingLocation = location
                        }
                    } label: {
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(data.trainingLocation == location ? Color(hex: 0x4C5BFF) : Color.white.opacity(0.1))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: location.icon)
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                            
                            Text(localizedOnboarding(location.titleKey))
                                .font(.title3.bold())
                                .foregroundStyle(data.trainingLocation == location ? .white : .secondary)
                            
                            Spacer()
                            
                            if data.trainingLocation == location {
                                Image(systemName: "checkmark")
                                    .font(.headline)
                                    .foregroundStyle(Color(hex: 0x4C5BFF))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(data.trainingLocation == location ? 0.08 : 0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .strokeBorder(data.trainingLocation == location ? Color(hex: 0x4C5BFF).opacity(0.5) : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct EquipmentChip: View {
    let equipment: Equipment
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: equipment.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color(hex: 0x4C5BFF) : .white)
                
                Text(localizedOnboarding(equipment.titleKey))
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: 0x4C5BFF).opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color(hex: 0x4C5BFF) : Color.clear, lineWidth: 1.5)
                    )
            )
            .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 6: Muscle Focus

struct MuscleFocusScreen: View {
    @Binding var data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedGroups: Set<String> = []
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var muscleGroups: [(String, String, String)] {
        let isGerman = onboardingLanguage == "de"
        return [
            ("fullbody", isGerman ? "Ganzkörper" : "Full Body", "figure.stand"),
            ("chest", isGerman ? "Brust" : "Chest", "figure.arms.open"),
            ("back", isGerman ? "Rücken" : "Back", "figure.walk"),
            ("shoulders", isGerman ? "Schultern" : "Shoulders", "figure.strengthtraining.traditional"),
            ("arms", isGerman ? "Arme" : "Arms", "figure.arms.open"),
            ("legs", isGerman ? "Beine" : "Legs", "figure.walk"),
            ("core", isGerman ? "Core" : "Core", "figure.core.training")
        ]
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(localizedOnboarding("onboarding.focus.title"))
                        .font(.title.bold())
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                    
                    Text(localizedOnboarding("onboarding.focus.subtitle"))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                .frame(maxWidth: .infinity)
                
                // Body figures with highlighted regions - SMALLER SIZE
                HStack(spacing: 20) {
                    MuscleFigure(
                        side: .front,
                        regionColors: selectedRegionColors
                    )
                    .frame(height: 200) // Reduced from default
                    
                    MuscleFigure(
                        side: .back,
                        regionColors: selectedRegionColors
                    )
                    .frame(height: 200) // Reduced from default
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                
                if !selectedGroups.isEmpty {
                    let count = selectedGroups.count
                    let text = onboardingLanguage == "de" 
                        ? (count == 1 ? "1 Muskelgruppe ausgewählt" : "\(count) Muskelgruppen ausgewählt")
                        : (count == 1 ? "1 muscle group selected" : "\(count) muscle groups selected")
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Muscle group selection grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(muscleGroups, id: \.0) { group in
                        MuscleGroupButton(
                            id: group.0,
                            title: group.1,
                            icon: group.2,
                            isSelected: selectedGroups.contains(group.0)
                        ) {
                            toggleMuscleGroup(group.0)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
        }
    }
    
    private var selectedRegions: [MuscleRegion] {
        var regions: [MuscleRegion] = []
        for group in selectedGroups {
            regions.append(contentsOf: muscleRegionsFor(group))
        }
        return regions
    }
    
    private func toggleMuscleGroup(_ group: String) {
        withAnimation(.spring()) {
            if group == "fullbody" {
                if selectedGroups.contains("fullbody") {
                    selectedGroups.removeAll()
                } else {
                    selectedGroups = ["fullbody"]
                }
            } else {
                selectedGroups.remove("fullbody")
                if selectedGroups.contains(group) {
                    selectedGroups.remove(group)
                } else {
                    selectedGroups.insert(group)
                }
            }
            
            // Update data
            data.muscleFocusRegions = Array(selectedGroups)
        }
    }
    
    private var selectedRegionColors: [MuscleRegion: Color] {
        var colors: [MuscleRegion: Color] = [:]
        for region in selectedRegions {
            colors[region] = Color(hex: 0x4C5BFF)
        }
        return colors
    }
    
    
    private func muscleRegionsFor(_ group: String) -> [MuscleRegion] {
        switch group {
        case "fullbody": return Array(MuscleRegion.allCases)
        case "chest": return [.chest]
        case "back": return [.traps, .lats, .lowerBack]
        case "shoulders": return [.shoulders]
        case "arms": return [.biceps, .triceps, .forearms]
        case "legs": return [.quads, .hamstrings, .calves, .glutes]
        case "core": return [.abs]
        default: return []
        }
    }
}

private struct MuscleGroupButton: View {
    let id: String
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color(hex: 0x4C5BFF) : .secondary)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color(hex: 0x4C5BFF) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 7: Personal Questions Intro (Interstitial)
struct PersonalQuestionsIntroScreen: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var animate = false
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: 0x4C5BFF).opacity(0.1))
                    .frame(width: 120, height: 120) // Large pulsing circle
                    .scaleEffect(animate ? 1.1 : 0.9)
                
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: 0x4C5BFF))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
            
            Text(onboardingLanguage == "de" ? "Lass uns Movo personalisieren." : "Let's personalize Movo.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            
            Text(onboardingLanguage == "de" ? "Wir brauchen ein paar Details, um dein Trainingserlebnis anzupassen." : "We need a few details to tailor your workout experience.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}
