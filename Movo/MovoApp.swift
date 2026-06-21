import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import GoogleSignIn
import PostHog


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

// MARK: - Analytics Bootstrap

enum PostHogBootstrap {
    static func configure() {
        guard let projectToken = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_PROJECT_TOKEN") as? String,
              !projectToken.isEmpty,
              !projectToken.hasPrefix("$(") else {
            print("[PostHogBootstrap] Analytics disabled: missing POSTHOG_PROJECT_TOKEN")
            return
        }

        let host = (Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String)
            ?? "https://eu.i.posthog.com"

        let config = PostHogConfig(projectToken: projectToken, host: host)

        config.optOut = !AnalyticsService.isEnabled
        config.captureApplicationLifecycleEvents = false
        config.sessionReplay = false

        PostHogSDK.shared.setup(config)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // Configure Firebase as early as possible (safe to call multiple times because of guard)
        FirebaseBootstrap.configureIfNeeded()
        PostHogBootstrap.configure()

        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.endActivity()
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle tap on notification here if needed
        completionHandler()
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

    @StateObject private var healthKit: HealthKitManager
    @StateObject private var gm: GamificationManager
    @StateObject private var languageManager: LanguageManager
    @StateObject private var globalNotesStore: GlobalExerciseNotesStore
    @StateObject private var equipmentStore: EquipmentStore // NEW

    // ☁️ Cloud Sync
    @StateObject private var syncService: SyncService

    // 🔗 DeepLink Manager
    @StateObject private var deepLink: DeepLinkManager
    
    // Widgets/Health
    @AppStorage("steps.goal") private var stepsGoal: Int = 8000
    @Environment(\.scenePhase) private var scenePhase

    // 🧭 Onboarding
    @AppStorage(kOnboardingKey) private var onboardingCompleted: Bool = false
    @State private var showAnalyticsConsentPrompt = false

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

        let health     = HealthKitManager()
        let gamify     = GamificationManager()
        let language   = LanguageManager()
        language.currentLanguage = settings.language
        let notes      = GlobalExerciseNotesStore()
        let deeplink   = DeepLinkManager()
        let equipment  = EquipmentStore() // Fix: Init locally

        let sync = SyncService(
            auth: auth,
            training: training,
            challenges: challenge,
            notes: notes
        )

        _appSettings      = StateObject(wrappedValue: settings)
        _design           = StateObject(wrappedValue: design)
        _challengeStore   = StateObject(wrappedValue: challenge)

        _trainingStore    = StateObject(wrappedValue: training)
        _sessionManager   = StateObject(wrappedValue: session)
        _exerciseLibrary  = StateObject(wrappedValue: library)
        _templateStore    = StateObject(wrappedValue: templates)
        _authService      = StateObject(wrappedValue: auth)

        _healthKit        = StateObject(wrappedValue: health)
        _gm               = StateObject(wrappedValue: gamify)
        _languageManager  = StateObject(wrappedValue: language)
        _globalNotesStore = StateObject(wrappedValue: notes)
        _syncService      = StateObject(wrappedValue: sync)
        _equipmentStore   = StateObject(wrappedValue: equipment) // NEW

        _deepLink         = StateObject(wrappedValue: deeplink)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            AppThemeHost {
                RootView()
            }
            .environmentObject(appSettings)
            .environmentObject(design)
            .environmentObject(sessionManager)
            .environmentObject(exerciseLibrary)
            .environmentObject(templateStore)
            .environmentObject(authService)
            .environmentObject(trainingStore)
            .environmentObject(challengeStore)
            .environmentObject(healthKit)
            .environmentObject(gm)
            .environmentObject(languageManager)
            .environmentObject(globalNotesStore)
            .environmentObject(equipmentStore) // NEW
            .environmentObject(syncService)
            .environmentObject(deepLink)
            .alert(analyticsConsentTitle, isPresented: $showAnalyticsConsentPrompt) {
                Button(analyticsConsentDeclineTitle, role: .cancel) {
                    updateAnalyticsConsent(enabled: false)
                }
                Button(analyticsConsentAllowTitle) {
                    updateAnalyticsConsent(enabled: true)
                }
            } message: {
                Text(analyticsConsentMessage)
            }
            .onOpenURL { url in
                // Handle Google Sign-In
                if GIDSignIn.sharedInstance.handle(url) { return }
                
                // Handle deep links (including QR code scans)
                AnalyticsService.track("deep_link_opened", properties: [
                    "scheme": url.scheme ?? "unknown",
                    "host": url.host ?? "unknown"
                ])
                deepLink.handle(url)
            }
            .onAppear {
                AnalyticsService.screen("app_root")
                scheduleAnalyticsConsentPromptIfNeeded()
                NotificationManager.shared.bootstrap(appSettings: appSettings)
                if #available(iOS 16.1, *), !sessionManager.isTrainingActive {
                    LiveActivityManager.shared.endActivity()
                }
                PhoneConnectivity.shared.activate()
                if !sessionManager.isTrainingActive {
                    PhoneConnectivity.shared.pushActiveWorkoutState(.init(isActive: false))
                }
                syncWatchStartOptions()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    refreshWatchStartStateIfIdle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    refreshWatchStartStateIfIdle()
                }

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
                PhoneConnectivity.shared.onStartTemplateRequested = { templateId in
                    startTemplateFromWatch(templateId: templateId, source: .template)
                }
                PhoneConnectivity.shared.onStartPlanTemplateRequested = { templateId in
                    startTemplateFromWatch(templateId: templateId, source: .plan)
                }
            }
            .onChange(of: templateStore.userTemplates) { _ in
                refreshWatchStartStateIfIdle()
            }
            .onReceive(challengeStore.$activeProgram) { _ in
                refreshWatchStartStateIfIdle()
            }
            .onReceive(challengeStore.$availablePrograms) { _ in
                refreshWatchStartStateIfIdle()
            }
            .onChange(of: appSettings.notificationsEnabled) { enabled in
                NotificationManager.shared.setEnabled(enabled, appSettings: appSettings)
            }
            .onChange(of: appSettings.analyticsEnabled) { enabled in
                AnalyticsService.applyAnalyticsPreference(enabled)
            }
            .onChange(of: onboardingCompleted) { completed in
                if completed {
                    scheduleAnalyticsConsentPromptIfNeeded()
                }
            }
            .onChange(of: appSettings.language) { newLang in
                NotificationManager.shared.rescheduleIfNeeded(appSettings: appSettings)
                // 🔄 Sync LanguageManager with AppSettings
                languageManager.currentLanguage = newLang
            }
            .task {
                // Keep goal and refresh, but DO NOT trigger HealthKit permission automatically.
                healthKit.dailyGoal = stepsGoal
                healthKit.refreshToday()
                
                // If you want background observers, start them only after the user has granted permission,
                // e.g. from within a Health-related screen after successful authorization.
                // await healthKit.startBackgroundDelivery() // ⛔️ moved behind an explicit user action
                // await healthKit.startWorkoutObserver()    // ⛔️ moved behind an explicit user action
                // await healthKit.startWeightObserver()     // ⛔️ moved behind an explicit user action
                // print("[App] ✅ HealthKit background observers started")
            }
            .onChange(of: stepsGoal) { newGoal in
                healthKit.dailyGoal = newGoal
                healthKit.refreshToday()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    AnalyticsService.track("app_opened", properties: ["entry_point": "scene_active"])
                    healthKit.refreshToday()
                    if #available(iOS 16.1, *), !sessionManager.isTrainingActive {
                        LiveActivityManager.shared.endActivity()
                    }
                    refreshWatchStartStateIfIdle()
                } else if phase == .background, !sessionManager.isTrainingActive {
                    AnalyticsService.track("app_backgrounded")
                    if #available(iOS 16.1, *) {
                        LiveActivityManager.shared.endActivity()
                    }
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
                            if trimmed.contains("."), !trimmed.contains(","),
                               let d = Double(trimmed) { return d }
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

    private enum WatchStartSource {
        case template
        case plan
    }

    @MainActor
    private func syncWatchStartOptions() {
        let activeProgram = challengeStore.activeTrainingProgram()
        let todaysTemplate = challengeStore.recommendedTemplate(from: trainingStore.history)

        let templateItems = templateStore.allTemplates.prefix(8).map { template in
            WatchStartItem(
                id: template.id,
                title: template.name,
                subtitle: "\(template.exercises.count) Übungen",
                exerciseCount: template.exercises.count,
                source: .template
            )
        }

        let planRoutines = activeProgram?.routines ?? []
        let orderedPlanRoutines: [TrainingTemplate] = {
            guard let todaysTemplate,
                  let index = planRoutines.firstIndex(where: { $0.id == todaysTemplate.id }) else {
                return planRoutines
            }
            var copy = planRoutines
            let today = copy.remove(at: index)
            return [today] + copy
        }()

        let planItems = orderedPlanRoutines.map { template in
            WatchStartItem(
                id: template.id,
                title: template.name,
                subtitle: template.id == todaysTemplate?.id ? "Heute empfohlen" : "Aus deinem Plan",
                exerciseCount: template.exercises.count,
                source: .plan
            )
        }

        PhoneConnectivity.shared.pushWatchStartOptions(
            WatchStartOptionsPayload(
                templates: Array(templateItems),
                planItems: Array(planItems.prefix(6)),
                activePlanTitle: activeProgram?.title,
                todaysPlanItemId: todaysTemplate?.id
            )
        )
    }

    @MainActor
    private func refreshWatchStartStateIfIdle() {
        guard !sessionManager.isTrainingActive else { return }
        PhoneConnectivity.shared.pushActiveWorkoutState(.init(isActive: false))
        syncWatchStartOptions()
    }

    @MainActor
    private func startTemplateFromWatch(templateId: String, source: WatchStartSource) {
        guard !sessionManager.isTrainingActive else { return }
        let planTemplates = (challengeStore.activeProgram.flatMap { active in
            challengeStore.availablePrograms.first(where: { $0.id == active.programId })
        }?.routines ?? [])
        let template: TrainingTemplate?
        switch source {
        case .template:
            template = templateStore.allTemplates.first(where: { $0.id == templateId })
        case .plan:
            template = planTemplates.first(where: { $0.id == templateId })
        }
        guard let template else { return }

        let analyticsSource = source == .plan ? "watch_plan" : "watch_template"
        sessionManager.startTraining(
            title: template.name,
            source: analyticsSource,
            templateId: template.id,
            hasActivePlan: source == .plan
        )
        for name in template.exercises {
            sessionManager.addExercise(name)
        }
        sessionManager.activities = template.activities
        sessionManager.persistSnapshotIfNeeded()
        AnalyticsService.trackWorkoutStarted(
            source: analyticsSource,
            template: template,
            hasActivePlan: source == .plan
        )
        PhoneConnectivity.shared.pushActiveWorkoutState(buildActiveWorkoutPayload(from: sessionManager))
        Task {
            await healthKit.startWorkoutSession()
        }
    }

}

private extension MovoApp {
    var isGerman: Bool {
        appSettings.language.lowercased().hasPrefix("de")
    }

    var analyticsConsentTitle: String {
        isGerman ? "Produktanalyse erlauben?" : "Allow product analytics?"
    }

    var analyticsConsentMessage: String {
        isGerman
            ? "Movo kann anonyme Nutzungsdaten senden, damit wir sehen, welche Funktionen helfen und wo die App verbessert werden sollte. Keine Bildschirmaufnahmen, keine Passwörter."
            : "Movo can send anonymous usage data so we can understand which features help and where the app should improve. No screen recordings, no passwords."
    }

    var analyticsConsentAllowTitle: String {
        isGerman ? "Erlauben" : "Allow"
    }

    var analyticsConsentDeclineTitle: String {
        isGerman ? "Nicht erlauben" : "Don't allow"
    }

    func scheduleAnalyticsConsentPromptIfNeeded() {
        guard onboardingCompleted else { return }
        guard !appSettings.analyticsConsentPromptSeen else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard onboardingCompleted, !appSettings.analyticsConsentPromptSeen else { return }
            showAnalyticsConsentPrompt = true
        }
    }

    func updateAnalyticsConsent(enabled: Bool) {
        appSettings.analyticsEnabled = enabled
        appSettings.analyticsConsentPromptSeen = true
        AnalyticsService.applyAnalyticsPreference(enabled)
        if enabled {
            AnalyticsService.track("analytics_consent_granted", properties: ["source": "first_launch_prompt"])
        }
    }
}
