import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

let kOnboardingKey = "onboarding.v2.completed"

// MARK: - Firebase Bootstrap (shared)

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }

        #if DEBUG
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        #endif

        FirebaseApp.configure()

        // Optional: Firestore persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings

        print("[FirebaseBootstrap] ✅ Firebase configured")
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // Configure Firebase as early as possible (safe to call multiple times because of guard)
        FirebaseBootstrap.configureIfNeeded()

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

    // 🧭 Onboarding
    @AppStorage(kOnboardingKey) private var onboardingCompleted: Bool = false

    #if DEBUG
    @State private var smokeMessage: String? = nil
    #endif

    // MARK: - Init

    init() {
        // ✅ Wichtig: Firebase VOR allen Services konfigurieren,
        // die evtl. Auth/Firestore benutzen (z.B. AuthService()).
        FirebaseBootstrap.configureIfNeeded()

        let settings   = AppSettings()
        let design     = DesignSettingsStore()
        let challenge  = ChallengeStore(appSettings: settings)

        let training   = TrainingStore()
        let session    = TrainingSessionManager()
        let library    = ExerciseLibrary()
        let templates  = TemplateStore(training: training)

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
                if onboardingCompleted {
                    RootView()
                } else {
                    OnboardingFlowView {
                        onboardingCompleted = true
                    }
                }
            }
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
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) { return }
                deepLink.handle(url)
            }
            .onAppear {
                NotificationManager.shared.bootstrap(appSettings: appSettings)
                PhoneConnectivity.shared.activate()

                // Watch callbacks
                PhoneConnectivity.shared.onSetLogged = { _, workoutExerciseId, reps, weight in
                    guard sessionManager.isTrainingActive else { return }
                    sessionManager.addSetFromWatch(
                        workoutExerciseId: workoutExerciseId,
                        reps: reps,
                        weightKg: weight,
                        markCompleted: true
                    )
                    // ⌚️ Sofort aktualisierten Payload pushen (inkl. Propagation)
                    let payload = buildActiveWorkoutPayload(from: sessionManager)
                    PhoneConnectivity.shared.pushActiveWorkoutState(payload)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }

                PhoneConnectivity.shared.onSetUpdated = { _, workoutExerciseId, setId, reps, weight in
                    guard sessionManager.isTrainingActive else { return }
                    sessionManager.updateSetFromWatch(
                        workoutExerciseId: workoutExerciseId,
                        setId: setId,
                        reps: reps,
                        weightKg: weight
                    )
                    // ⌚️ Sofort aktualisierten Payload pushen (inkl. Propagation)
                    let payload = buildActiveWorkoutPayload(from: sessionManager)
                    PhoneConnectivity.shared.pushActiveWorkoutState(payload)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }

                PhoneConnectivity.shared.onSetRemoved = { workoutExerciseId, setId in
                    guard sessionManager.isTrainingActive else { return }
                    sessionManager.removeSetFromWatch(
                        workoutExerciseId: workoutExerciseId,
                        setId: setId
                    )
                    // ⌚️ Sofort aktualisierten Payload pushen
                    let payload = buildActiveWorkoutPayload(from: sessionManager)
                    PhoneConnectivity.shared.pushActiveWorkoutState(payload)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }

                PhoneConnectivity.shared.onExerciseChanged = { _, workoutExerciseId in
                    print("⌚️ exercise_changed:", workoutExerciseId)
                }
            }
            .onChange(of: appSettings.notificationsEnabled) { enabled in
                NotificationManager.shared.setEnabled(enabled, appSettings: appSettings)
            }
            .onChange(of: appSettings.language) { _ in
                NotificationManager.shared.rescheduleIfNeeded(appSettings: appSettings)
            }
            .task {
                healthKit.dailyGoal = stepsGoal
                healthKit.refreshToday()

                await healthKit.startBackgroundDelivery()
                await healthKit.startWorkoutObserver()
                await healthKit.startWeightObserver()

                print("[App] ✅ All HealthKit background observers started")
            }
            .onChange(of: stepsGoal) { newGoal in
                healthKit.dailyGoal = newGoal
                healthKit.refreshToday()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    healthKit.refreshToday()
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

    // MARK: - Helper: Payload Builder (global nutzbar)
    private func buildActiveWorkoutPayload(from manager: TrainingSessionManager) -> ActiveWorkoutPayload {
        // Workout-ID: versuche eine stabile ID aus dem Snapshot; ansonsten generisch
        let wid: String = {
            if let started = manager.loadResumeSnapshot()?.startedAt {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f.string(from: started)
            } else {
                return UUID().uuidString
            }
        }()

        let exercises: [ActiveWorkoutPayload.ExerciseItem] =
            manager.exercises.enumerated().map { idx, ex in
                // Exercise-ID
                let exId = Mirror(reflecting: ex).children.first { $0.label == "id" }?.value as? UUID ?? UUID()
                let exName = Mirror(reflecting: ex).children.first { $0.label == "name" }?.value as? String ?? "Exercise \(idx + 1)"
                // Sets
                let anySets = Mirror(reflecting: ex).children.first { $0.label == "sets" }?.value
                let arr = anySets as? [Any] ?? []
                let sets: [ActiveWorkoutPayload.LoggedSetItem] = arr.map { s in
                    let sid = Mirror(reflecting: s).children.first { $0.label == "id" }?.value as? UUID ?? UUID()
                    let repsAny = Mirror(reflecting: s).children.first { $0.label == "reps" }?.value
                    let weightAny = Mirror(reflecting: s).children.first { $0.label == "weight" }?.value
                    let completedAny = Mirror(reflecting: s).children.first { $0.label == "isCompleted" }?.value

                    let repsVal: Int = {
                        if let i = repsAny as? Int { return i }
                        if let str = repsAny as? String { return Int(str.filter("0123456789".contains)) ?? 0 }
                        return 0
                    }()
                    let weightVal: Double = {
                        if let d = weightAny as? Double { return d }
                        if let str = weightAny as? String {
                            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                            let nf = NumberFormatter(); nf.locale = .current; nf.numberStyle = .decimal
                            if let n = nf.number(from: trimmed) { return n.doubleValue }
                            if let d = Double(trimmed.replacingOccurrences(of: ",", with: ".")) { return d }
                            if let n = nf.number(from: trimmed.replacingOccurrences(of: ".", with: ",")) { return n.doubleValue }
                        }
                        return 0
                    }()
                    let completedVal: Bool = (completedAny as? Bool) ?? false

                    return ActiveWorkoutPayload.LoggedSetItem(
                        id: sid.uuidString,
                        reps: repsVal,
                        weight: weightVal,
                        completed: completedVal
                    )
                }
                return ActiveWorkoutPayload.ExerciseItem(
                    id: exId.uuidString,
                    name: exName,
                    order: idx,
                    setCount: sets.count,
                    sets: sets
                )
            }

        return ActiveWorkoutPayload(
            isActive: true,
            workoutId: wid,
            workoutName: manager.trainingTitle.isEmpty ? "Training" : manager.trainingTitle,
            exercises: exercises,
            selectedExerciseId: exercises.first?.id
        )
    }
}
