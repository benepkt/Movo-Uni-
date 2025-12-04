import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var trainingStore: TrainingStore
    @StateObject var healthKitManager = HealthKitManager()



    var body: some View {
        if authService.user != nil || authService.isGuest {
            // Benutzer ist eingeloggt oder als Gast unterwegs – Hauptinhalt anzeigen
            TabView {
                HomeView(trainingHistory: $trainingStore.history)
                    .tabItem {
                        Label("Training", systemImage: "figure.strengthtraining.traditional")
                    }

                ExercisesView()
                    .tabItem {
                        Label("Übungen", systemImage: "book")
                    }

                ChallengesDashboardView()
                    .tabItem {
                        Label("Challenges", systemImage: "star.fill")
                    }

                TrainingHistoryView()
                    .tabItem {
                        Label("Verlauf", systemImage: "clock.arrow.circlepath")
                    }

                StatisticsView()
                    .tabItem {
                        Label("Statistik", systemImage: "chart.bar")
                    }
            }
        } else {
            // Nicht eingeloggt – LoginView anzeigen
            LoginView()
                .environmentObject(authService)  // Wichtig für LoginView
        }
    }
}
