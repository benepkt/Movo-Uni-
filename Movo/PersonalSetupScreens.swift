// Separate Personal Setup Screens - Split into 4 individual screens
// Weight, Height, Steps Goal, Goal Weight

import SwiftUI

// MARK: - Screen 1: Weight Setup

struct WeightSetupScreen: View {
    @Binding var weightUnit: WeightUnit
    @Binding var weightKg: Double
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(onboardingLanguage == "de" ? "Wie viel wiegst du?" : "What's your weight?")
                    .font(.largeTitle.bold())
                
                Text(onboardingLanguage == "de" ? "Wir nutzen dies, um dein Erlebnis zu personalisieren" : "We'll use this to personalize your experience")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Weight display
            VStack(spacing: 16) {
                Text(formatWeight(weightDisplay) + " " + (weightUnit == .kg ? "kg" : "lb"))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: 0x4C5BFF))
                
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
                .tint(Color(hex: 0x4C5BFF))
                .padding(.horizontal, 24)
            }
            
            // Unit toggle
            HStack(spacing: 12) {
                UnitButton(title: "kg", isSelected: weightUnit == .kg) {
                    weightUnit = .kg
                }
                UnitButton(title: "lb", isSelected: weightUnit == .lb) {
                    weightUnit = .lb
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var weightDisplay: Double {
        weightUnit == .kg ? weightKg : WeightUnit.lb.fromKilograms(weightKg)
    }
    
    private func formatWeight(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Screen 2: Height Setup

struct HeightSetupScreen: View {
    @Binding var heightCm: Double
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(onboardingLanguage == "de" ? "Wie groß bist du?" : "How tall are you?")
                    .font(.largeTitle.bold())
                
                Text(onboardingLanguage == "de" ? "Dies hilft uns, deine Metriken zu berechnen" : "This helps us calculate your metrics")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Height display
            VStack(spacing: 16) {
                Text("\(Int(heightCm)) cm")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: 0x4C5BFF))
                
                Slider(value: $heightCm, in: 140...220, step: 1)
                    .tint(Color(hex: 0x4C5BFF))
                    .padding(.horizontal, 24)
            }
            
            Spacer()
        }
    }
}

// MARK: - Screen 3: Steps Goal

struct StepsGoalScreen: View {
    @Binding var stepsGoal: Int
    let experienceLevel: ExperienceLevel?
    @EnvironmentObject var appSettings: AppSettings
    @State private var stepsDouble: Double = 10000
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(onboardingLanguage == "de" ? "Tägliches Schrittziel?" : "Daily steps goal?")
                    .font(.largeTitle.bold())
                
                Text(onboardingLanguage == "de" ? "Setze ein realistisches Ziel für deine Aktivität" : "Set a realistic target for your activity")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            // Widget Visualization
            VStack(alignment: .leading, spacing: 16) {
                Text("\(stepsGoal.formatted(.number.grouping(.automatic)))")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(onboardingLanguage == "de" ? "Schritte pro Tag" : "steps per day")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                // Mock Graph
                GeometryReader { geo in
                    Path { path in
                        let width = geo.size.width
                        let height = geo.size.height
                        
                        path.move(to: CGPoint(x: 0, y: height - 10))
                        
                        // Bezier curve points tailored to look like the screenshot (Peak in 1st third)
                        path.addCurve(
                            to: CGPoint(x: width * 0.35, y: 10), // Peak
                            control1: CGPoint(x: width * 0.1, y: height - 10),
                            control2: CGPoint(x: width * 0.25, y: 10)
                        )
                        
                        path.addCurve(
                            to: CGPoint(x: width * 0.55, y: height - 30), // Valley
                            control1: CGPoint(x: width * 0.45, y: 10),
                            control2: CGPoint(x: width * 0.5, y: height - 30)
                        )
                        
                        path.addCurve(
                            to: CGPoint(x: width * 0.65, y: height - 50), // Small Peak
                            control1: CGPoint(x: width * 0.6, y: height - 30),
                            control2: CGPoint(x: width * 0.62, y: height - 50)
                        )
                        
                        path.addCurve(
                            to: CGPoint(x: width, y: height - 10), // End
                            control1: CGPoint(x: width * 0.7, y: height - 20),
                            control2: CGPoint(x: width * 0.9, y: height - 10)
                        )
                    }
                    .stroke(
                        Color(hex: 0x3ac9ff), // Bright Cyan/Blue from screenshot
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    
                    // Gradient fill below
                    Path { path in
                        let width = geo.size.width
                        let height = geo.size.height
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height - 10))
                        
                        path.addCurve(
                             to: CGPoint(x: width * 0.35, y: 10),
                             control1: CGPoint(x: width * 0.1, y: height - 10),
                             control2: CGPoint(x: width * 0.25, y: 10)
                        )
                         path.addCurve(
                             to: CGPoint(x: width * 0.55, y: height - 30),
                             control1: CGPoint(x: width * 0.45, y: 10),
                             control2: CGPoint(x: width * 0.5, y: height - 30)
                         )
                         path.addCurve(
                             to: CGPoint(x: width * 0.65, y: height - 50),
                             control1: CGPoint(x: width * 0.6, y: height - 30),
                             control2: CGPoint(x: width * 0.62, y: height - 50)
                         )
                        path.addCurve(
                            to: CGPoint(x: width, y: height - 10),
                            control1: CGPoint(x: width * 0.7, y: height - 20),
                            control2: CGPoint(x: width * 0.9, y: height - 10)
                        )
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x3ac9ff).opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 100)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: 0x1C1C1E))
            )
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Slider
            VStack(spacing: 8) {
                Slider(value: $stepsDouble, in: 2000...20000, step: 500)
                    .tint(Color(hex: 0x3ac9ff))
                
                HStack {
                    Text("2.000")
                    Spacer()
                    Text("20.000")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .onAppear {
            if stepsGoal == 0 {
                if experienceLevel == .beginner { stepsDouble = 8000 }
                else if experienceLevel == .intermediate { stepsDouble = 10000 }
                else { stepsDouble = 12000 }
            } else {
                stepsDouble = Double(stepsGoal)
            }
        }
        .onChange(of: stepsDouble) { newValue in
            stepsGoal = Int(newValue)
        }
    }
}

// MARK: - Screen 4: Goal Weight - NO TOGGLE, ALWAYS SHOWN

struct GoalWeightScreen: View {
    @Binding var weightUnit: WeightUnit
    @Binding var currentWeightKg: Double
    @Binding var hasGoalWeight: Bool
    @Binding var goalWeightKg: Double
    let fitnessGoals: Set<FitnessGoal>
    @EnvironmentObject var appSettings: AppSettings
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(onboardingLanguage == "de" ? "Zielgewicht?" : "Goal weight?")
                    .font(.largeTitle.bold())
                
                Text(onboardingLanguage == "de" ? "Setze dein Zielgewicht" : "Set your target weight")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Goal weight display - ALWAYS SHOWN, NO TOGGLE
            VStack(spacing: 16) {
                Text(formatWeight(goalWeightDisplay) + " " + (weightUnit == .kg ? "kg" : "lb"))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: 0x4C5BFF))
                
                Slider(
                    value: Binding(
                        get: { goalWeightDisplay },
                        set: { v in
                            goalWeightKg = weightUnit == .kg ? v : WeightUnit.lb.toKilograms(v)
                        }
                    ),
                    in: weightUnit == .kg ? 40...180 : 90...400,
                    step: 0.5
                )
                .tint(Color(hex: 0x4C5BFF))
                .padding(.horizontal, 24)
                
                // Show difference
                let diff = currentWeightKg - goalWeightKg
                if abs(diff) > 0.1 {
                    let loseText = onboardingLanguage == "de" ? "↓ \(formatWeight(abs(weightUnit.fromKilograms(diff)))) \(weightUnit.symbol) abnehmen" : "↓ \(formatWeight(abs(weightUnit.fromKilograms(diff)))) \(weightUnit.symbol) to lose"
                    let gainText = onboardingLanguage == "de" ? "↑ \(formatWeight(abs(weightUnit.fromKilograms(diff)))) \(weightUnit.symbol) zunehmen" : "↑ \(formatWeight(abs(weightUnit.fromKilograms(diff)))) \(weightUnit.symbol) to gain"
                    Text(diff > 0 ? loseText : gainText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .onAppear {
            // Pre-fill goal weight if not set
            if goalWeightKg == 0 {
                goalWeightKg = currentWeightKg - 5 // Suggest 5kg less
            }
            hasGoalWeight = true // Always enabled
        }
    }
    
    private var goalWeightDisplay: Double {
        weightUnit == .kg ? goalWeightKg : WeightUnit.lb.fromKilograms(goalWeightKg)
    }
    
    private func formatWeight(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Helper Components

private struct UnitButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(isSelected ? Color(hex: 0x4C5BFF) : Color.white.opacity(0.1)))
                .foregroundColor(isSelected ? .white : .secondary)
        }
    }
}
