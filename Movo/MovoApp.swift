import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseFirestore
import WidgetKit
import GoogleSignIn

// Gemeinsamer Onboarding-Key für die ganze App
// (Bitte denselben auch in OnboardingFlowView verwenden, dort nicht erneut private definieren)
let kOnboardingKey = "onboarding.v2.completed"

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

// MARK: - MovoApp

@main
struct MovoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // ⚙️ App-weite States
    @StateObject private var appSettings: AppSettings
    @StateObject private var design: DesignSettingsStore
    @StateObject private var challengeStore: ChallengeStore

    @StateObject private var trainingStore: TrainingStore
    @StateObject private var sessionManager: TrainingSessionManager
    @StateObject private var exerciseLibrary: ExerciseLibrary
    @StateObject private var templateStore: TemplateStore
    @StateObject private var authService: AuthService
    @StateObject private var purchaseManager: PurchaseManager
    @StateObject private var healthKit: HealthKitManager
    @StateObject private var gm: GamificationManager
    @StateObject private var languageManager: LanguageManager
    @StateObject private var globalNotesStore: GlobalExerciseNotesStore

    // ☁️ Cloud Sync
    @StateObject private var syncService: SyncService

    // 🔗 DeepLink Manager
    @StateObject private var deepLink: DeepLinkManager

    // Widgets/Health
    @AppStorage("steps.goal") private var stepsGoal: Int = 8000
    @Environment(\.scenePhase) private var scenePhase

    // 🧭 Onboarding-Flag (entscheidet: Onboarding vs. RootView)
    @AppStorage(kOnboardingKey) private var onboardingCompleted: Bool = false

    // DEBUG UI
    #if DEBUG
    @State private var isSmokeBusy = false
    @State private var smokeMessage: String? = nil
    #endif

    // MARK: - Init

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            FirebaseConfiguration.shared.setLoggerLevel(.debug)

            let settings = FirestoreSettings()
            settings.isPersistenceEnabled = true
            Firestore.firestore().settings = settings
        }

        let settings   = AppSettings()
        let design     = DesignSettingsStore()
        let challenge  = ChallengeStore(appSettings: settings)

        let training   = TrainingStore()
        let session    = TrainingSessionManager()
        let library    = ExerciseLibrary()
        let templates  = TemplateStore(training: training) // <- lokal gekoppelt
        let auth       = AuthService()
        let purchase   = PurchaseManager()
        let health     = HealthKitManager()
        let gamify     = GamificationManager()
        let language   = LanguageManager()
        let notes      = GlobalExerciseNotesStore()
        let deeplink   = DeepLinkManager()

        let sync = SyncService(
            auth: auth,
            training: training,
            challenges: challenge,
            notes: notes,
            purchaseManager: purchase
        )

        _appSettings      = StateObject(wrappedValue: settings)
        _design           = StateObject(wrappedValue: design)
        _challengeStore   = StateObject(wrappedValue: challenge)

        _trainingStore    = StateObject(wrappedValue: training)
        _sessionManager   = StateObject(wrappedValue: session)
        _exerciseLibrary  = StateObject(wrappedValue: library)
        _templateStore    = StateObject(wrappedValue: templates)
        _authService      = StateObject(wrappedValue: auth)
        _purchaseManager  = StateObject(wrappedValue: purchase)
        _healthKit        = StateObject(wrappedValue: health)
        _gm               = StateObject(wrappedValue: gamify)
        _languageManager  = StateObject(wrappedValue: language)
        _globalNotesStore = StateObject(wrappedValue: notes)
        _syncService      = StateObject(wrappedValue: sync)

        _deepLink         = StateObject(wrappedValue: deeplink)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            AppThemeHost {
                // 🔑 Zentraler Flow:
                // 1. Wenn Onboarding noch nicht abgeschlossen → OnboardingFlowView
                // 2. Sonst → RootView (die kümmert sich um Auth / Main UI)
                if onboardingCompleted {
                    RootView()
                } else {
                    OnboardingFlowView {
                        onboardingCompleted = true
                    }
                }
            }
            // EnvironmentObjects für beide Fälle
            .environmentObject(appSettings)
            .environmentObject(design)
            .environmentObject(sessionManager)
            .environmentObject(exerciseLibrary)
            .environmentObject(templateStore)
            .environmentObject(authService)
            .environmentObject(trainingStore)
            .environmentObject(purchaseManager)
            .environmentObject(challengeStore)
            .environmentObject(healthKit)
            .environmentObject(gm)
            .environmentObject(languageManager)
            .environmentObject(globalNotesStore)
            .environmentObject(syncService)
            .environmentObject(deepLink)

            // 🔗 Deep Links & Google Sign-In Callback
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) { return }
                deepLink.handle(url)
            }

            // 🔔 Notifications
            .onAppear {
                NotificationManager.shared.bootstrap(appSettings: appSettings)
            }
            .onChange(of: appSettings.notificationsEnabled) { enabled in
                NotificationManager.shared.setEnabled(enabled, appSettings: appSettings)
            }
            .onChange(of: appSettings.language) { _ in
                NotificationManager.shared.rescheduleIfNeeded(appSettings: appSettings)
            }

            // 🚶‍♂️ HealthKit ↔︎ Widget
            .task {
                healthKit.dailyGoal = stepsGoal
                healthKit.refreshToday()
                await healthKit.startBackgroundDelivery()
            }
            .onChange(of: stepsGoal) { newGoal in
                healthKit.dailyGoal = newGoal
                healthKit.refreshToday()
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    healthKit.refreshToday()
            //    case .background:
                  //  syncService.flushInBackgroundSilently()
                default:
                    break
                }
            }

            #if DEBUG
            .overlay(alignment: .bottomTrailing) {
                if let msg = smokeMessage {
                    Text(msg)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                }
            }
            #endif
        }
    }
}

// MARK: - Smoke-Test (nur DEBUG)

#if DEBUG
extension MovoApp {
    @MainActor
    private func smokeTestWrite() async {
        guard let uid = authService.user?.uid else {
            print("[SMOKE] kein uid (nicht eingeloggt?)")
            smokeMessage = "SMOKE: kein uid"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { smokeMessage = nil }
            return
        }

        isSmokeBusy = true
        smokeMessage = "SMOKE läuft…"

        let db = Firestore.firestore()
        do {
            let ref = db.collection("users").document(uid)
                .collection("diagnostics").document("ping")
            try await ref.setData([
                "by": "ios",
                "ts": FieldValue.serverTimestamp()
            ], merge: true)
            print("[SMOKE] diagnostics/ping ✅ write ok (\(ref.path))")
            smokeMessage = "SMOKE ✅"
        } catch {
            print("[SMOKE] diagnostics/ping ❌", error.localizedDescription)
            smokeMessage = "SMOKE ❌"
        }

        isSmokeBusy = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { smokeMessage = nil }
    }
}
#endif
