// Enhanced Interactive Onboarding Flow - Complete Redesign
// 16 Screens with personalization, feature showcases, and hard paywall

import SwiftUI
import UserNotifications
import HealthKit
import StoreKit

// MARK: - Brand Colors

private let brand      = Color(hex: 0x4C5BFF)
private let bgDeepA    = Color(hex: 0x050505) // Matches LoginView
private let bgDeepB    = Color(hex: 0x050505) // Matches LoginView
private let brandTintA = Color(hex: 0x3846E8)

// MARK: - Main Onboarding View

struct OnboardingFlowView: View {
    
    var onFinished: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var healthKit: HealthKitManager

    
    // User Defaults (keep existing for compatibility)
    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg
    @AppStorage("profile.weightKg") private var weightKg: Double = 70
    @AppStorage("profile.heightCm") private var heightCm: Double = 175
    @AppStorage("steps.goal") private var stepsGoal: Int = 10_000
    @AppStorage(kOnboardingKey) private var completed: Bool = false
    @AppStorage("profile.hasGoalWeight") private var hasGoalWeight: Bool = false
    @AppStorage("profile.goalWeightKg")  private var storedGoalWeightKg: Double = 75
    
    // Detect system language only on first launch
    @AppStorage("onboarding.language") private var onboardingLanguage: String = {
        // Check if language was already set before
        if let existingLanguage = UserDefaults.standard.string(forKey: "onboarding.language") {
            return existingLanguage
        }
        // First launch: detect system language
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        return systemLanguage.lowercased().hasPrefix("de") ? "de" : "en"
    }()
    
    // Onboarding Data
    @State private var onboardingData = OnboardingData.load()
    
    // UI State
    @State private var currentStep: Int = 0
    @State private var backgroundOffset: CGFloat = 0
    @State private var showContent: Bool = false
    
    private let totalSteps = 20
    
    var body: some View {
        ZStack {
            // Animated background
            AnimatedBackground(offset: backgroundOffset)
            
            // Content
            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
                Spacer()
                
                currentStepView
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                    .animation(.easeInOut(duration: 0.35), value: currentStep)
                
                Spacer()
                
                // Bottom bar
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold && currentStep > 0 {
                        // Swipe right - go back
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentStep -= 1
                        }
                    } else if value.translation.width < -threshold && currentStep < totalSteps - 1 {
                        // Swipe left - go forward
                        if canContinue {
                            handleContinue()
                        }
                    }
                }
        )
        .colorScheme(.dark)
        .preferredColorScheme(.dark)
        .onAppear {
            // Sync app language with onboarding language on first load
            if appSettings.language != onboardingLanguage {
                appSettings.language = onboardingLanguage
            }
            
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                backgroundOffset = 360
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showContent = true
            }
        }
        .onChange(of: stepsGoal) { new in
            healthKit.dailyGoal = new
            healthKit.refreshToday()
        }
    }
    
    // MARK: - Current Step View
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        // Phase 1: Personalization (Grouped)
        case 0: WelcomeAnimationScreen()                                // 0. Welcome Animation
            // Case 1 (Username) removed
        case 1: FitnessGoalsScreen(data: $onboardingData)               // 1. Goals
        case 2: ExperienceLevelScreen(data: $onboardingData)            // 2. Level
        case 3: TrainingFrequencyScreen(data: $onboardingData)          // 3. Frequency
        case 4: BirthdayScreen(data: $onboardingData)                   // 4. Birthday
        case 5: GenderScreen(data: $onboardingData)                     // 5. Gender
        
        // Interstitial
        case 6: PersonalQuestionsIntroScreen()                          // 6. Intro (New)
            
        case 7: WeightSetupScreen(weightUnit: $weightUnit, weightKg: $weightKg) // 7. Weight
        case 8: HeightSetupScreen(heightCm: $heightCm)                 // 8. Height
        case 9: GoalWeightScreen(                                     // 9. Goal Weight
            weightUnit: $weightUnit,
            currentWeightKg: $weightKg,
            hasGoalWeight: $hasGoalWeight,
            goalWeightKg: $storedGoalWeightKg,
            fitnessGoals: onboardingData.fitnessGoals
        )
        case 10: StepsGoalScreen(stepsGoal: $stepsGoal, experienceLevel: onboardingData.experienceLevel) // 10. Steps (Redesigned)
        
        case 11: EquipmentScreen(data: $onboardingData)                  // 11. Equipment
        case 12: LocationScreen(data: $onboardingData)                   // 12. Location
        case 13: MuscleFocusScreen(data: $onboardingData)                // 13. Focus
        
        // Phase 2: App Preview / Showcases
        case 14: EasyLoggingScreen(onNext: {
            handleContinue()
        })                                     // 14. Easy Logging
        case 15: TrackProgressScreen()                                   // 15. Track Progress (Score)
        case 16: TrackStatisticsScreen()                                 // 16. Statistics (Heatmap - New)
            
        case 17: ReviewsScreen()                                         // 17. Reviews
        
        // Phase 3: Permissions
        case 18: HealthPermissionScreen(onRequest: requestHealthPermissions) // 18. Health Permission
        case 19: NotificationPermissionScreen(onRequest: requestNotificationPermissions) // 19. Notification Permission
        
        default: FitnessGoalsScreen(data: $onboardingData)
        }
    }
    
    // MARK: - Top/Bottom Bars
    
    private var topBar: some View {
        VStack(spacing: 0) {
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(Color.white) // Forge White
                        .frame(width: (CGFloat(currentStep + 1) / CGFloat(totalSteps)) * geo.size.width, height: 4)
                        .animation(.smooth, value: currentStep)
                }
            }
            .frame(height: 4)
            .padding(.bottom, 16)
            
            HStack {
                if currentStep > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentStep = max(0, currentStep - 1)
                        }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
                Spacer()
                
                // Language Switcher (only on welcome screen)
                if currentStep == 0 {
                    Button {
                        withAnimation(.spring()) {
                            let newLang = appSettings.language == "de" ? "en" : "de"
                            appSettings.language = newLang
                            onboardingLanguage = newLang
                        }
                    } label: {
                        Text(appSettings.language == "de" ? "DE" : "EN")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
        }
    }
    
    private var bottomBar: some View {
            // Continue button
            Button {
                handleContinue()
            } label: {
                Text(continueButtonText)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(
                Capsule()
                    .fill(Color.white) // High contrast white button for Forge
            )
            .disabled(!canContinue)
            .opacity(canContinue ? 1.0 : 0.5)
            // Hide bottom bar for EasyLoggingScreen (Step 14) as it has its own "Speichern" button
            // .opacity(currentStep == 14 ? 0 : 1) // Keep visible 
        }
    
    
    // MARK: - Button Text & Validation
    
    private var continueButtonText: String {
        let isGerman = appSettings.language == "de"
        
        // Permissions or Reviews
        if currentStep == 18 { // Reviews check
            return isGerman ? "Weiter" : "Continue"
        }
        if currentStep == totalSteps - 1 {
            return isGerman ? "Los geht's!" : "Let's go!"
        }
        return isGerman ? "Weiter" : "Continue"
    }
    
    private var canContinue: Bool {
        switch currentStep {
        case 0: return true // Welcome Animation
        case 1: return !onboardingData.fitnessGoals.isEmpty
        case 2: return true // Level
        case 3: return true // Frequency
        case 4: return onboardingData.age != nil // Birthday
        case 5: return onboardingData.gender != nil // Gender
        case 6: return true // Intro
        case 7: return true // Weight
        case 8: return true // Height
        case 9: return true // Goal Weight
        case 10: return true // Steps
        case 11: return !onboardingData.equipment.isEmpty
        case 12: return true // Location
        case 13: return true // Focus
        
        // Showcases
        case 14: return true // Easy Logging
        case 15: return true // Progress
        case 16: return true // Statistics
        case 17: return true // Reviews
        
        // Permissions
        case 18: return true // Health
        case 19: return true // Notifications
        default: return true
        }
    }
    
    // MARK: - Actions
    
    private func handleContinue() {
        // Save data after each step
        onboardingData.save()
        
        // Special handling for Reviews (Step 19) is done inside the view itself (ReviewsScreen).
        // We do typically NOT request it here again to avoid double prompts.
        
        if currentStep < totalSteps - 1 {
            withAnimation(.spring()) {
                currentStep += 1
            }
        } else {
            finish()
        }
    }
    
    private func finish() {
        completed = true
        healthKit.dailyGoal = stepsGoal
        healthKit.refreshToday()
        onboardingData.save()
        
        // Save userName to UserDefaults for profile
        if !onboardingData.userName.isEmpty {
            UserDefaults.standard.set(onboardingData.userName, forKey: "profile.userName")
        }
        
        onFinished?()
        dismiss()
    }
    
    private func requestHealthPermissions() {
        // Deleagte to HealthKitManager which handles Read vs Share types safely
        Task {
            await healthKit.requestPermissions()
        }
    }
    
    private func requestNotificationPermissions() {
        // Notifications
        NotificationManager.shared.requestAuthorizationIfNeeded(
            forcePrompt: true,
            appSettings: appSettings
        )
    }
}

// MARK: - Animated Background (Keep existing)

private struct AnimatedBackground: View {
    let offset: CGFloat
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [bgDeepA, bgDeepB],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Blue tint removed for pure black "Forge" look
            // LinearGradient(
            //     colors: [brandTintA.opacity(0.2), .clear],
            //     startPoint: .topLeading,
            //     endPoint: .bottomTrailing
            // )
            
            // FloatingParticles(offset: offset)
        }
        .ignoresSafeArea()
    }
}

private struct FloatingParticles: View {
    let offset: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(brand.opacity(0.1))
                    .frame(width: CGFloat.random(in: 4...12))
                    .offset(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: (CGFloat(index) * 80 + offset).truncatingRemainder(dividingBy: geo.size.height + 100) - 50
                    )
                    .blur(radius: 2)
            }
        }
    }
}

// MARK: - Helper Components

private struct FeatureBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(brand)
                .frame(width: 28)
            
            Text(text)
                .font(.body)
        }
    }
}
