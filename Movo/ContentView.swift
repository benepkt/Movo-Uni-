import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings   // ✅ wichtig
    @EnvironmentObject var deepLink: DeepLinkManager
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var challengeStore: ChallengeStore

    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var equipmentStore: EquipmentStore

    @StateObject var healthKitManager = HealthKitManager()
    @State private var selection = 0

    var body: some View {
        if authService.user != nil || authService.isGuest {
            TabView(selection: $selection) {

                HomeView(trainingHistory: $trainingStore.history, tabSelection: $selection)
                    .tag(0)
                    .tabItem {
                        Label {
                            Text(appSettings.localized("tab.training"))
                        } icon: {
                            Image(systemName: "figure.strengthtraining.traditional")
                        }
                    }

                ExercisesView()
                    .tag(1)
                    .tabItem {
                        Label {
                            Text(appSettings.localized("tab.exercises"))
                        } icon: {
                            Image(systemName: "dumbbell.fill")
                        }
                    }

                ProgrammeDashboardView()
                    .tag(2)
                    .tabItem {
                        Label {
                            Text(appSettings.localized("tab.feed"))
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                        }
                    }

                StatisticsView()
                    .tag(3)
                    .tabItem {
                        Label {
                            Text(appSettings.localized("tab.stats"))
                        } icon: {
                            Image(systemName: "chart.bar")
                        }
                    }

            }
            .onAppear {
                AnalyticsService.screen(screenName(for: selection))
            }
            .onChange(of: selection) { newSelection in
                AnalyticsService.screen(screenName(for: newSelection))
            }
            .sheet(item: $deepLink.templateToImport) { template in
                TemplateImportView(template: template)
                    .environmentObject(templateStore)

                    .environmentObject(appSettings)
                    .environmentObject(exerciseLibrary)
            }
            .sheet(item: $deepLink.programToImport) { program in
                TrainingProgramImportView(program: program)
                    .environmentObject(challengeStore)
            }
        } else {
            LoginView()
                .environmentObject(authService)
        }
    }

    private func screenName(for selection: Int) -> String {
        switch selection {
        case 0: return "training_home"
        case 1: return "exercise_library"
        case 2: return "training_plan"
        case 3: return "statistics"
        default: return "unknown_tab"
        }
    }
}
