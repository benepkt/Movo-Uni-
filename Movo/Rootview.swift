// RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage(kOnboardingKey) private var onboardingCompleted: Bool = false

    var body: some View {
        Group {
            // 1) Onboarding noch nicht gemacht -> OnboardingFlowView
            if !onboardingCompleted {
                OnboardingFlowView {
                    onboardingCompleted = true
                    // danach rendert der Body neu und springt automatisch weiter
                }
            }

            // 2) Onboarding fertig & User vorhanden (egal ob normal oder anonym) -> Haupt-App
            else if authService.user != nil {
                ContentView()  // deine bisherige Start-View der App
            }

            // 3. Onboarding fertig, kein User -> Login (Landing Page)
            else {
                LoginView()
            }
        }
    }
}
