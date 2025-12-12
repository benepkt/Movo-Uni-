// Interactive Onboarding Flow - Redesigned with animations and new features
// Features: Goal weight tracking, premium showcase, XRP system, activity window

import SwiftUI
import UserNotifications
import HealthKit




// Brand colors
private let brand      = Color(hex: 0x4C5BFF)
private let bgDeepA    = Color(hex: 0x0A0E19)
private let bgDeepB    = Color(hex: 0x0D1222)
private let brandTintA = Color(hex: 0x3846E8)

// MARK: - Main Onboarding View

struct OnboardingFlowView: View {
    
    
    var onFinished: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var healthKit: HealthKitManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    // User Defaults
    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg
    @AppStorage("profile.weightKg") private var weightKg: Double = 70
    @AppStorage("profile.heightCm") private var heightCm: Double = 175
    @AppStorage("steps.goal") private var stepsGoal: Int = 10_000
    @AppStorage(kOnboardingKey) private var completed: Bool = false
    @AppStorage("profile.hasGoalWeight") private var hasGoalWeight: Bool = false
    @AppStorage("profile.goalWeightKg")  private var storedGoalWeightKg: Double = 75
    
    // UI State
    @State private var currentStep: Int = 0
    @State private var backgroundOffset: CGFloat = 0
    @State private var showContent: Bool = false
    
    private let totalSteps = 10
    
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
                    .id(currentStep) // wichtig für saubere Transitions
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)

                
                Spacer()
                
                // Bottom bar
                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .colorScheme(.dark)
        .preferredColorScheme(.dark)
        .onAppear {
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
    
    // MARK: - Top/Bottom Bars
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0: WelcomeScreen()
        case 1: QuickLoggingScreen()
        case 2: ChallengesScreen()
        case 3:
            GoalWeightScreen(
                weightKg: $weightKg,
                goalWeightKg: Binding<Double?>(
                    get: { hasGoalWeight ? storedGoalWeightKg : nil },
                    set: { newValue in
                        if let v = newValue {
                            hasGoalWeight = true
                            storedGoalWeightKg = v
                        } else {
                            hasGoalWeight = false
                        }
                    }
                ),
                weightUnit: weightUnit
            )
        case 4: StatisticsScreen()
        case 5: PremiumShowcaseScreen(onContinueFree: { withAnimation(.spring()) { currentStep += 1 } })
        case 6: XRPSystemScreen()
        case 7: PersonalSetupScreen(weightUnit: $weightUnit, heightCm: $heightCm, stepsGoal: $stepsGoal)
        case 8: PermissionsScreen()
        case 9: FinalScreen()
        default: WelcomeScreen()
        }
    }


    private var topBar: some View {
        HStack {
            if currentStep > 0 {
                Button { withAnimation(.spring()) { currentStep = max(0, currentStep - 1) } }
                label: { Image(systemName: "chevron.left").font(.headline) }
            } else {
                Color.clear.frame(width: 24, height: 24)
            }
            Spacer()
        }
        .tint(brand)
    }
    
    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? brand : Color.white.opacity(0.3))
                        .frame(width: index == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(), value: currentStep)
                }
            }
            
            // Continue button
            Button {
                handleContinue()
            } label: {
                Text(currentStep == totalSteps - 1 ? "Let's Go!" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(brand)
        }
    }
    
    // MARK: - Actions
    
    private func handleContinue() {
        // Special handling for permissions screen
        if currentStep == 8 {
            requestPermissions()
        }
        
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
        onFinished?()
        dismiss()
    }
    
    private func requestPermissions() {
        // Notifications
        NotificationManager.shared.requestAuthorizationIfNeeded(
            forcePrompt: true,
            appSettings: appSettings
        )
        
        // HealthKit
        Task {
            await healthKit.requestReadAuthorizationIfNeeded(
                readTypes: [
                    HKObjectType.quantityType(forIdentifier: .stepCount)!,
                    HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                    HKObjectType.quantityType(forIdentifier: .bodyMass)!,
                    HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                    HKObjectType.quantityType(forIdentifier: .height)!,
                    HKObjectType.quantityType(forIdentifier: .heartRate)!,
                    HKObjectType.workoutType()
                ],
                forcePrompt: true
            )
        }
    }
}

// MARK: - Animated Background

private struct AnimatedBackground: View {
    let offset: CGFloat
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [bgDeepA, bgDeepB],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            LinearGradient(
                colors: [brandTintA.opacity(0.2), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Floating particles
            FloatingParticles(offset: offset)
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

// MARK: - Screen 1: Welcome

private struct WelcomeScreen: View {
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Welcome to")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("Movo")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [brand, brandTintA],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Focus on what matters.\nTrack workouts, build streaks, see progress.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(brand.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animate ? 1.2 : 1.0)
                    .opacity(animate ? 0 : 1)
                
                Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundStyle(brand)
                .rotationEffect(.degrees(animate ? 720 : 0))
            }
            .frame(height: 140)
            .onAppear {
                withAnimation(.easeInOut(duration: 4)) {
                    animate = true
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureBullet(icon: "bolt.fill", text: "Lightning-fast logging")
                FeatureBullet(icon: "flame.fill", text: "Streaks & rewards")
                FeatureBullet(icon: "chart.bar.fill", text: "Detailed insights")
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen 2: Quick Logging

private struct QuickLoggingScreen: View {
    @State private var checkStates = [false, false, false]
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Log Workouts")
                    .font(.largeTitle.bold())
                
                Text("Tap sets to check them off.\nThat's it. Really.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            // Interactive demo card
            VStack(alignment: .leading, spacing: 16) {
                Label("Bench Press", systemImage: "dumbbell.fill")
                    .font(.headline)
                
                ForEach(0..<3, id: \.self) { index in
                    Button {
                        withAnimation(.spring()) {
                            checkStates[index].toggle()
                        }
                    } label: {
                        HStack {
                            Text("80 kg × 10 reps")
                                .foregroundStyle(checkStates[index] ? .secondary : .primary)
                                .strikethrough(checkStates[index])
                            
                            Spacer()
                            
                            Image(systemName: checkStates[index] ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(checkStates[index] ? brand : .secondary)
                                .font(.title2)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(checkStates[index] ? 0.03 : 0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(. horizontal, 24)
            
            Text("Tap above to try it! ☝️")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Screen 3: Challenges & Gamification

private struct ChallengesScreen: View {
    @State private var progress: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Stay Motivated")
                    .font(.largeTitle.bold())
                
                Text("Set challenges, earn XRP coins,\nunlock badges & levels.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            // Animated progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [brand, brandTintA], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("3/5")
                        .font(.system(size: 32, weight: .bold))
                    Text("Workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 1.5).delay(0.3)) {
                    progress = 0.6
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureBullet(icon: "target", text: "Custom weekly goals")
                FeatureBullet(icon: "star.fill", text: "Unlock achievements")
                FeatureBullet(icon: "gift.fill", text: "Earn XRP rewards")
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 4: Goal Weight (NEW!)

private struct GoalWeightScreen: View {
    @Binding var weightKg: Double
    @Binding var goalWeightKg: Double?
    let weightUnit: WeightUnit
    
    @State private var hasGoal = false
    @State private var tempGoal: Double = 70
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Set Your Goal")
                    .font(.largeTitle.bold())
                
                Text("Track your progress towards\nyour ideal weight.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 24) {
                // Current weight
                VStack(spacing: 8) {
                    Text("Current Weight")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(formatWeight(weightDisplay) + " " + (weightUnit == .kg ? "kg" : "lb"))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    
                    Slider(
                        value: Binding(
                            get: { weightDisplay },
                            set: { v in
                                weightKg = weightUnit == .kg ? v : WeightUnit.lb.toKilograms(v)
                            }
                        ),
                        in: weightUnit == .kg ? 40...180 : 90...400,
                        step: 0.5
                    )
                    .tint(brand)
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
                
                // Goal weight
                Toggle("Set a goal weight", isOn: $hasGoal.animation(.spring()))
                    .tint(brand)
                
                if hasGoal {
                    VStack(spacing: 8) {
                        Text("Goal Weight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(formatWeight(goalDisplay) + " " + (weightUnit == .kg ? "kg" : "lb"))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(brand)
                        
                        Slider(
                            value: $tempGoal,
                            in: weightUnit == .kg ? 40...180 : 90...400,
                            step: 0.5
                        )
                        .tint(brand)
                        
                        // Progress visualization
                        if abs(weightDisplay - goalDisplay) > 1 {
                            let diff = weightDisplay - goalDisplay
                            if diff > 0 {
                                Text("\(formatWeight(abs(diff))) \(weightUnit == .kg ? "kg" : "lb") to lose 💪")
                                    .font(.subheadline)
                                    .foregroundStyle(brand)
                            } else if diff < 0 {
                                Text("\(formatWeight(abs(diff))) \(weightUnit == .kg ? "kg" : "lb") to gain 💪")
                                    .font(.subheadline)
                                    .foregroundStyle(brand)
                            } else {
                                Text("Goal reached! 🎉")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 20).fill(brand.opacity(0.1)))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            if let goal = goalWeightKg {
                tempGoal = weightUnit == .kg ? goal : WeightUnit.lb.fromKilograms(goal)
                hasGoal = true
            } else {
                tempGoal = weightDisplay
            }
        }
        .onChange(of: hasGoal) { newValue in
            goalWeightKg = newValue ? (weightUnit == .kg ? tempGoal : WeightUnit.lb.toKilograms(tempGoal)) : nil
        }
        .onChange(of: tempGoal) { newValue in
            if hasGoal {
                goalWeightKg = weightUnit == .kg ? newValue : WeightUnit.lb.toKilograms(newValue)
            }
        }
    }
    
    private var weightDisplay: Double {
        weightUnit == .kg ? weightKg : WeightUnit.lb.fromKilograms(weightKg)
    }
    
    private var goalDisplay: Double {
        weightUnit == .kg ? tempGoal : WeightUnit.lb.fromKilograms(WeightUnit.lb.toKilograms(tempGoal))
    }
    
    private func formatWeight(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Screen 5: Statistics & Activity Window (NEW!)

private struct StatisticsScreen: View {
    @State private var barHeights: [CGFloat] = Array(repeating: 0, count: 7)
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Smart Statistics")
                    .font(.largeTitle.bold())
                
                Text("See trends, PRs, and discover\nwhen you train best.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            // Animated bar chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Volume")
                    .font(.headline)
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(brand.opacity(barHeights[index] > 0.7 ? 1.0 : 0.6))
                                .frame(width: 32, height: barHeights[index] * 100)
                            
                            Text(["M", "T", "W", "T", "F", "S", "S"][index])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 120)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
            .padding(.horizontal, 24)
            .onAppear {
                let heights: [CGFloat] = [0.6, 0.4, 0.8, 0.5, 0.9, 0.3, 0.4]
                heights.enumerated().forEach { index, height in
                    withAnimation(.spring(duration: 0.6).delay(Double(index) * 0.1)) {
                        barHeights[index] = height
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureBullet(icon: "clock.fill", text: "Activity window: best training times")
                FeatureBullet(icon: "chart.line.uptrend.xyaxis", text: "Personal records tracking")
                FeatureBullet(icon: "calendar", text: "Long-term progress trends")
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 6: Premium Showcase

private struct PremiumShowcaseScreen: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @State private var showCards = [false, false, false, false, false]
    
    let onContinueFree: () -> Void   // ✅ NEU

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("🌟 Movo Pro")
                        .font(.largeTitle.bold())
                    
                    Text("Unlock powerful features\nfor serious athletes.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                VStack(spacing: 12) {
                    PremiumFeatureCard(
                        icon: "chart.xyaxis.line",
                        title: "Advanced Statistics",
                        description: "Custom date ranges, exercise PRs, body composition",
                        color: .blue,
                        show: showCards[0]
                    )
                    
                    PremiumFeatureCard(
                        icon: "square.grid.2x2.fill",
                        title: "Home & Lock Screen Widgets",
                        description: "Quick glance at your stats from anywhere",
                        color: .purple,
                        show: showCards[1]
                    )
                    
                    PremiumFeatureCard(
                        icon: "clock.badge.fill",
                        title: "Live Activities",
                        description: "Real-time workout tracking on Dynamic Island",
                        color: .indigo,
                        show: showCards[2]
                    )
                    
                    PremiumFeatureCard(
                        icon: "heart.fill",
                        title: "Heart Rate Training",
                        description: "Zone tracking, recovery insights, real-time monitoring",
                        color: .red,
                        show: showCards[3]
                    )
                    
                    PremiumFeatureCard(
                        icon: "sparkles",
                        title: "Premium Features",
                        description: "Unlock all pro features and future updates",
                        color: .orange,
                        show: showCards[4]
                    )
                }
                .padding(.horizontal, 24)
                
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await purchaseManager.purchase(plan: .monthly)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.body)
                            Text("Unlock Movo Premium Features")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [brand, brandTintA],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Text("3.49€/month • Cancel anytime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        
                        // Just continue
                        onContinueFree()     // ✅ statt currentStep += 1
                    } label: {
                        Text("Continue with free version")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showCards.enumerated().forEach { index, _ in
                withAnimation(.spring(duration: 0.5).delay(Double(index) * 0.1)) {
                    showCards[index] = true
                }
            }
        }
    }
}

private struct PremiumFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let show: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(show ? 1 : 0.8)
        .opacity(show ? 1 : 0)
    }
}

// MARK: - Screen 7: XRP System

private struct XRPSystemScreen: View {
    @State private var coins: [CGPoint] = []
    @State private var level: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("🪙 XRP Rewards")
                    .font(.largeTitle.bold())
                
                Text("Your fitness journey, rewarded.\nEarn coins, level up, unlock perks.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: level)
                        .stroke(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 4) {
                        Text("Level")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("12")
                            .font(.system(size: 32, weight: .bold))
                    }
                }
                
                // Better coin drop animation
                GeometryReader { geo in
                    ForEach(0..<coins.count, id: \.self) { index in
                        if index < coins.count {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.title)
                                .foregroundStyle(.yellow)
                                .position(x: coins[index].x, y: coins[index].y)
                                .opacity(coins[index].y > 20 && coins[index].y < 80 ? 1 : 0)
                        }
                    }
                }
                .frame(height: 100)
            }
            .onAppear {
                withAnimation(.spring(duration: 1.5).delay(0.3)) {
                    level = 0.35
                }
                
                // Drop coins with better spacing
                for i in 0..<5 {
                    let delay = Double(i) * 0.25
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        let startX = CGFloat(80 + i * 45)
                        let startY: CGFloat = 10
                        let endY: CGFloat = 50
                        
                        coins.append(CGPoint(x: startX, y: startY))
                        
                        withAnimation(.easeOut(duration: 0.6)) {
                            if i < coins.count {
                                coins[i] = CGPoint(x: startX, y: endY)
                            }
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureBullet(icon: "checkmark.circle.fill", text: "Earn XRP for completing workouts")
                FeatureBullet(icon: "flame.fill", text: "Streak bonuses and daily multipliers")
                FeatureBullet(icon: "trophy.fill", text: "Level up to unlock profile badges")
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Screen 8: Personal Setup

private struct PersonalSetupScreen: View {
    @Binding var weightUnit: WeightUnit
    @Binding var heightCm: Double
    @Binding var stepsGoal: Int
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("Personalize")
                        .font(.largeTitle.bold())
                    
                    Text("Quick setup for better recommendations.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    Text("Weight Unit")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {
                        UnitButton(title: "Kilograms", isSelected: weightUnit == .kg) {
                            weightUnit = .kg
                        }
                        UnitButton(title: "Pounds", isSelected: weightUnit == .lb) {
                            weightUnit = .lb
                        }
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
                
                VStack(spacing: 16) {
                    Text("Height")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(Int(heightCm)) cm")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    
                    Slider(value: $heightCm, in: 140...220, step: 1)
                        .tint(brand)
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
                
                VStack(spacing: 16) {
                    Text("Daily Steps Goal")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(stepsGoal.formatted(.number.grouping(.automatic)))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    
                    Slider(
                        value: Binding(get: { Double(stepsGoal) }, set: { stepsGoal = Int($0) }),
                        in: 3000...20000,
                        step: 500
                    )
                    .tint(brand)
                    
                    HStack(spacing: 8) {
                        ForEach([8000, 10000, 15000], id: \.self) { preset in
                            Button(String(preset)) {
                                withAnimation(.spring()) { stepsGoal = preset }
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(stepsGoal == preset ? brand : Color.white.opacity(0.1)))
                            .foregroundColor(stepsGoal == preset ? .white : .secondary)
                        }
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

private struct UnitButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? brand : Color.white.opacity(0.1)))
                .foregroundColor(isSelected ? .white : .secondary)
        }
    }
}

// MARK: - Screen 9: Permissions

private struct PermissionsScreen: View {
    @State private var pulseHealth = false
    @State private var pulseBell = false
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Enable Features")
                    .font(.largeTitle.bold())
                
                Text("Grant permissions to unlock\nthe full Movo experience.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "heart.fill",
                    title: "Apple Health",
                    description: "Sync steps, calories, workouts, and more.",
                    iconColor: .red,
                    pulse: pulseHealth
                )
                
                PermissionCard(
                    icon: "bell.badge.fill",
                    title: "Notifications",
                    description: "Get reminders for rest timers and streaks.",
                    iconColor: .blue,
                    pulse: pulseBell
                )
            }
            .padding(.horizontal, 24)
            
            Text("Tap Continue to grant permissions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulseHealth = true
                pulseBell = true
            }
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    let pulse: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Screen 10: Final

private struct FinalScreen: View {
    @State private var scale: CGFloat = 0.5
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.largeTitle.bold())
                
                Text("Welcome to Movo.\nLet's build something amazing.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            ZStack {
                Circle()
                    .fill(brand.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(scale)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [brand, brandTintA], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .scaleEffect(scale)
                
                if showConfetti {
                    ForEach(0..<20, id: \.self) { index in
                        Circle()
                            .fill([Color.yellow, Color.orange, brand, Color.purple, Color.pink].randomElement() ?? brand)
                            .frame(width: CGFloat.random(in: 4...8))
                            .offset(
                                x: cos(Double(index) * .pi / 10) * 100,
                                y: sin(Double(index) * .pi / 10) * 100
                            )
                            .opacity(0)
                    }
                }
            }
            .frame(height: 180)
            .onAppear {
                withAnimation(.spring(duration: 0.8)) {
                    scale = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showConfetti = true
                    }
                }
            }
            
            Text("Tap 'Let's Go!' to start your fitness journey")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
}


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

// Helper extension for Color from hex
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
