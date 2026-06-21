// Onboarding Screens - Phase 3: Final
// Screen 16: Final Screen (Paywall removed)

import SwiftUI

// MARK: - Screen 16: Final Screen

struct FinalScreen: View {
    let data: OnboardingData
    @EnvironmentObject var appSettings: AppSettings

    @State private var scale: CGFloat = 0.5
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text(String(format: appSettings.localized("onboarding.final.title"), data.userName))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("Welcome to Movo.\nLet's build something amazing together.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            ZStack {
                Circle()
                    .fill(Color(hex: 0x4C5BFF).opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(scale)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x4C5BFF), Color(hex: 0x3846E8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(scale)
                
                if showConfetti {
                    ForEach(0..<20, id: \.self) { index in
                        Circle()
                            .fill([Color.yellow, Color.orange, Color(hex: 0x4C5BFF), Color.purple, Color.pink].randomElement() ?? Color(hex: 0x4C5BFF))
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
            
            // Personalized summary
            VStack(alignment: .leading, spacing: 12) {
                if !data.fitnessGoals.isEmpty {
                    SummaryRow(
                        icon: "target",
                        text: String(format: appSettings.localized("onboarding.final.goals"), data.fitnessGoals.count)
                    )
                }
                
                SummaryRow(
                    icon: "calendar",
                    text: String(format: appSettings.localized("onboarding.final.frequency"), data.trainingFrequency)
                )
                

            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, 24)
            
            Text(appSettings.localized("onboarding.final.motivation"))
                .font(.headline)
                .foregroundStyle(Color(hex: 0x4C5BFF))
            
            Spacer()
        }
    }
    

}

private struct SummaryRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color(hex: 0x4C5BFF))
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
// MARK: - Screen 17: Notification Permission
struct NotificationPermissionScreen: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var animate = false
    var onRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: 0x4C5BFF).opacity(0.1))
                    .frame(width: 180, height: 180)
                    .scaleEffect(animate ? 1.1 : 0.9)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(animate ? 15 : -15))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animate = true
                }
                // Trigger permission request automatically
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onRequest()
                }
            }
            
            VStack(spacing: 16) {
                Text(appSettings.localized("onboarding.notifications.title") != "onboarding.notifications.title" ? appSettings.localized("onboarding.notifications.title") : "Stay Consistent")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text(appSettings.localized("onboarding.notifications.subtitle") != "onboarding.notifications.subtitle" ? appSettings.localized("onboarding.notifications.subtitle") : "Get reminders to workout and track your progress.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

// MARK: - Screen 18: Health Permission
struct HealthPermissionScreen: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var pulse = false
    var onRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulse ? 1.2 : 0.8)
                    .opacity(pulse ? 0 : 0.5)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.red)
                    .scaleEffect(pulse ? 1.1 : 0.9)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
                // Trigger permission request automatically
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onRequest()
                }
            }
            
            VStack(spacing: 16) {
                Text(appSettings.localized("onboarding.health.title") != "onboarding.health.title" ? appSettings.localized("onboarding.health.title") : "Sync with Health")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text(appSettings.localized("onboarding.health.subtitle") != "onboarding.health.subtitle" ? appSettings.localized("onboarding.health.subtitle") : "Import your workouts and biometrics automatically.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}
