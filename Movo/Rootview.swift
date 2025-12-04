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

            // 3) Onboarding fertig, kein User -> Auswahl Login / Gast
            else {
                AuthChoiceView()
            }
        }
    }
}
import SwiftUI

struct AuthChoiceView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var healthKit: HealthKitManager

    @State private var showLogin = false
    @State private var showOnboarding = false

    // eigener, klarer Key nur für dieses Onboarding-Flag
    @AppStorage("onboarding.v2.completed") private var onboardingCompletedV2 = false

    // einfache Farben, OHNE Color(hex:) – damit keine Abhängigkeit / Fehler
    private var brand: Color { .blue }
    private var bgGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 10/255, green: 14/255, blue: 25/255),
                Color(red: 13/255, green: 18/255, blue: 34/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bgGradient.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Logo
                    Image("fitness_robot_blue")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 110)
                        .padding(.bottom, 4)

                    // Titel + Untertitel
                    VStack(spacing: 8) {
                        Text("Willkommen bei Movo")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)

                        Text("Trainingslog, Schritte & Challenges – ohne Schnickschnack.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer()

                    // Buttons
                    VStack(spacing: 12) {

                        // Mit Konto anmelden
                        Button {
                            showLogin = true
                        } label: {
                            Text("Mit Konto anmelden")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(brand)
                        .cornerRadius(14)

                        // Ohne Anmeldung fortfahren (Gast)
                        Button {
                            authService.signInAnonymouslyIfNeeded()
                        } label: {
                            Text("Ohne Anmeldung fortfahren")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(.white)
                        .cornerRadius(14)

                        // Onboarding ansehen
                        Button {
                            showOnboarding = true
                        } label: {
                            Text("Funktionen zuerst entdecken")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .underline()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    Text("Du kannst später jederzeit ein Konto erstellen oder verknüpfen.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 18)
                        .padding(.horizontal, 32)
                }
            }
        }
        // Login als Sheet
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(authService)
        }
        // Onboarding als Fullscreen
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView {
                onboardingCompletedV2 = true
                showOnboarding = false
            }
            .environmentObject(appSettings)
            .environmentObject(healthKit)
            .preferredColorScheme(.dark)
        }
    }
}
