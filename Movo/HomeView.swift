import SwiftUI
import HealthKit
import UIKit
import Charts
import WidgetKit
import FirebaseFirestore
import StoreKit

// MARK: - Design Tokens (Minimalist System)

extension View {
    /// Minimal shadow for elevation (lighter than default)
    func minimalShadow() -> some View {
        self.shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    /// Minimal card style with subtle border and light background
    func minimalCard() -> some View {
        self
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
    }

    /// Section header text style
    func sectionHeader() -> some View {
        self
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
    }

    /// Safe numeric text transition on iOS 17+, no-op on iOS 16
    @ViewBuilder
    func numericTextTransition() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }
}

// Spacing constants
private enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}

private enum HomeFocusMetric: String, CaseIterable, Identifiable {
    case training
    case plan
    case steps
    case weight

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .training: return "dumbbell.fill"
        case .plan: return "calendar.badge.clock"
        case .steps: return "figure.walk"
        case .weight: return "scalemass.fill"
        }
    }

    func title(using settings: AppSettings) -> String {
        let isGerman = settings.language.lowercased().hasPrefix("de")
        switch self {
        case .training: return isGerman ? "Training" : "Training"
        case .plan: return isGerman ? "Plan" : "Plan"
        case .steps: return settings.localized("steps.unit")
        case .weight: return settings.localized("common.weight")
        }
    }
}

private struct HomeWeekDay: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
    let isToday: Bool
}

// MARK: - Kleine Helfer

func localizedWeekTitle(_ raw: String, weekWord: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = t.lowercased()
    if lower.hasPrefix("week ") {
        let parts = t.split(separator: " ")
        if parts.count >= 2, let n = Int(parts[1]) { return "\(weekWord) \(n)" }
    }
    return t
}

// MARK: - Step Counter (Toolbar-Chip)

struct StepCounterView: View {
    @ObservedObject var healthManager: HealthKitManager
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.walk")
                .font(.caption)
                .foregroundStyle(t.palette.primary)
            Text("\(healthManager.todaySteps)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .numericTextTransition()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(t.palette.primary.opacity(0.14)))
        .overlay(Capsule().stroke(t.palette.outline, lineWidth: 0.8))
        .accessibilityLabel(appSettings.localized("steps.today"))
    }
}

// MARK: - Progress Ring

private struct HomeProgressRing: View {
    @Environment(\.designTokens) private var t
    var progress: Double
    var color: Color? = nil
    var lineWidth: CGFloat = 8

    var body: some View {
        let c = color ?? t.palette.primary
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(c, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
        }
    }
}

private struct WeightUpdateBanner: Equatable {
    let kg: Double

    var formattedKg: String {
        String(format: "%.1f", kg)
    }
}

// MARK: - HomeView
struct HomeView: View {

    @Binding var trainingHistory: [TrainingEntry]
    @Binding var tabSelection: Int // Added to allow navigation to Statistics
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var challengeStore: ChallengeStore

    @EnvironmentObject var syncService: SyncService
    @Environment(\.designTokens) private var t
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme    // ⬅️ NEU

    // Animation state
    @State private var watchWorkoutId: String = ""
    @State private var selectedFocusMetric: HomeFocusMetric = .training
    @State private var latestHomeWeight: Double?
    @State private var previousHomeWeight: Double?
    @State private var weightUpdateBanner: WeightUpdateBanner?


    // Hintergrundfarbe ähnlich wie im zweiten Screenshot
    private var homeBackground: Color {
        if colorScheme == .dark {
            // wie vorher: systemBackground für Dark Mode
            return Color(.systemBackground)
        } else {
            // neuer Pastell-Hintergrund nur im Light Mode
            return Color(red: 244/255, green: 243/255, blue: 250/255)
        }
    }

    // Avatar Cache
    @AppStorage("profile.imageData") private var profileImageData: Data?
    @AppStorage("profile.hasGoalWeight") private var hasGoalWeight: Bool = false
    @AppStorage("profile.goalWeightKg")  private var goalWeightKg: Double = 75

    var effectiveGoalWeightKg: Double? { hasGoalWeight ? goalWeightKg : nil }

    @StateObject private var healthManager = HealthKitManager()

    @State private var showNewTraining = false
    @State private var showTemplates = false
    @State private var showManualEntry = false
    @State private var showStartMenu = false

    // Rating – only native App Store popup
    @AppStorage("goals.workoutsPerWeek") private var weeklyGoal: Int = 3
    @AppStorage("steps.goal") private var stepsGoal: Int = 8000
    @AppStorage("profile.weightKg") private var weightKg: Double = 0

    @AppStorage("ratingPrompt.seen") private var ratingPromptSeen = false

    // Beta-Promo
    @AppStorage("betaPromo.seen.v2") private var betaPromoSeen = false
    @State private var showBetaPromo = false

    // Resume-Popup
    @State private var showResumeCard = false
    @State private var pendingResume: TrainingSessionManager.ResumeSnapshot? = nil

    // Zentraler Sheet-Status
    @State private var activeSheet: ActiveSheet? = nil
    @State private var previewTemplate: TrainingTemplate? // New: For preview sheet

    enum ActiveSheet: Identifiable {
        case steps, profile, weight, calories, water, sleep, lastTraining, streak
        var id: String {
            switch self {
            case .steps: return "steps"
            case .profile: return "profile"
            case .weight: return "weight"
            case .calories: return "calories"
            case .water: return "water"
            case .sleep: return "sleep"
            case .lastTraining: return "lastTraining"
            case .streak: return "streak"
            }
        }
    }


    // NUR eigene Templates (ohne Default-Templates)
    private var templates: [TrainingTemplate] { templateStore.userTemplates }
    private var homeTemplates: [TrainingTemplate] {
        let pinned = templateStore.allTemplates.filter { templateStore.isPinned($0) }
        if !pinned.isEmpty { return pinned }
        return Array(templateStore.defaultTemplates.prefix(4))
    }

    // Timer für Widget-Sync (alle 2 Sekunden)
    private let widgetUpdateTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [
                        t.palette.primary.opacity(0.42),
                        Color.blue.opacity(0.16),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 430
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [
                        t.palette.secondary.opacity(0.28),
                        Color.cyan.opacity(0.10),
                        Color.clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 40,
                    endRadius: 420
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        greetingSection()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.spring(response: 0.45, dampingFraction: 0.9), value: authService.user?.uid)
                        weightUpdateNotice()
                        focusMetricTabs()
                        weeklyTrainingCard()
                        activeTrainingSection()
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        quickStartSection()
                        templatesSection()
                            .transition(.opacity)

                        // feedSection() // Removed as per user request
                        //     .transition(.opacity)

                        Spacer(minLength: 32)
                    }
                    .padding(.bottom, 28)
                }
                .coordinateSpace(name: "templatesScroll") // für Parallax in TemplateCards
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .sheet(item: $activeSheet) { item in
                switch item {
                case .steps:
                    StepsPanelView(healthManager: healthManager)
                        .environmentObject(appSettings)
                        .tint(t.palette.primary)
                case .profile:
                    ProfileView(customProfileImageData: $profileImageData)
                        .environmentObject(appSettings)
                        .environmentObject(authService)
                        .environmentObject(trainingStore)
                        .environmentObject(gm)
                case .weight:
                    WeightDetailView(healthManager: healthManager)
                        .environmentObject(appSettings)
                case .calories:
                    CaloriesDetailView(healthManager: healthManager)
                        .environmentObject(appSettings)
                case .water:
                    WaterDetailView()
                        .environmentObject(appSettings)
                case .sleep:
                    SleepDetailView(healthManager: healthManager)
                        .environmentObject(appSettings)
                case .lastTraining:
                    LastTrainingDetailView(
                        trainingHistory: trainingHistory,
                        lastTrainingDate: trainingHistory.sorted { $0.date > $1.date }.first?.date
                    )
                    .environmentObject(trainingStore)
                    .environmentObject(appSettings)
                    .environmentObject(syncService)
                    .environmentObject(templateStore)
                    .environmentObject(sessionManager)

                    .environmentObject(exerciseLibrary)
                    .environmentObject(gm)
                    .environmentObject(authService)
                case .streak:
                    StreakDetailView()
                        .environmentObject(trainingStore)
                        .environmentObject(appSettings)

                }
            }
            // Preview Sheet for Home Templates
            .sheet(item: $previewTemplate) { template in
                TemplateDetailView(
                    template: template,
                    onStart: {
                        sessionManager.startTraining(title: template.name, source: "from_template", templateId: template.id)
                        for name in template.exercises { sessionManager.addExercise(name) }
                        sessionManager.activities = template.activities
                        sessionManager.persistSnapshotIfNeeded()
                        AnalyticsService.trackWorkoutStarted(source: "from_template", template: template)
                        showNewTraining = true
                        previewTemplate = nil
                    },
                    onPin: {
                        templateStore.togglePin(for: template)
                    },
                    isPinned: templateStore.isPinned(template)
                )
            }

            .sheet(isPresented: $showStartMenu) {
                TrainingStartMenu { type in
                    switch type {
                    case .strength:
                        showNewTraining = true
                    case .manual:
                        showManualEntry = true
                    }
                }
                .environmentObject(appSettings)
                .presentationDetents([.fraction(0.38)])
                .presentationDragIndicator(.hidden)
            }

            // WICHTIG: NewTrainingView als Fullscreen-Cover (stabiler als NavigationLink)
            .fullScreenCover(isPresented: $showNewTraining) {
                NewTrainingView()
                    .environmentObject(sessionManager)
                    .environmentObject(appSettings)
                    .environmentObject(exerciseLibrary)
                    .environmentObject(trainingStore)
                    .environmentObject(gm)
                    .environmentObject(authService)
                    .environmentObject(syncService)

                    .environmentObject(healthManager)
            }

            .onAppear {
                // 1) Rating nur über nativen SKStoreReview-Dialog
                if !ratingPromptSeen && workoutsThisWeek() >= 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        requestAppReview()
                        ratingPromptSeen = true
                    }
                }

                Task {
                    await prefetchAvatarIntoAppStorage()
                    healthManager.refreshAll()
                    healthManager.detectLatestWeightChangeForHome()
                    loadHomeWeightTrend()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        loadPendingWeightUpdateNotice()
                    }
                    updateWidgetData()
                }

                // Resume prüfen bei Kaltstart
                if !sessionManager.isTrainingActive,
                   let snap = sessionManager.loadResumeSnapshot() {
                    pendingResume = snap
                    withAnimation(.spring()) { showResumeCard = true }
                }

                // Beta-Promo
                if false && !betaPromoSeen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                            showBetaPromo = true
                        }
                    }
                }
            }
            .onChange(of: authService.user?.uid) { _ in
                Task { await prefetchAvatarIntoAppStorage() }
            }
            .onChange(of: authService.isGuest) { _ in
                Task { await prefetchAvatarIntoAppStorage() }
            }

            .onChange(of: sessionManager.isTrainingActive) { isActive in
                if isActive {
                    if watchWorkoutId.isEmpty { watchWorkoutId = UUID().uuidString }

                    let payload = buildActiveWorkoutPayload()
                    PhoneConnectivity.shared.pushActiveWorkoutState(payload)
                    print("📤 WATCH push (start):", payload.workoutName ?? "nil", payload.exercises.count)
                } else {
                    PhoneConnectivity.shared.pushActiveWorkoutState(.init(isActive: false))
                    watchWorkoutId = ""
                    print("📤 WATCH push (stop)")
                }
            }
            .onChange(of: sessionManager.exercises.count) { _ in
                // Wenn Übungen geladen/angepasst werden, Watch aktualisieren
                guard sessionManager.isTrainingActive else { return }
                let payload = buildActiveWorkoutPayload()
                PhoneConnectivity.shared.pushActiveWorkoutState(payload)
                print("📤 WATCH push (exercises changed):", payload.exercises.count)
            }

            .onChange(of: totalSetCount) { _ in
                guard sessionManager.isTrainingActive else { return }
                let payload = buildActiveWorkoutPayload()
                PhoneConnectivity.shared.pushActiveWorkoutState(payload)
                print("📤 WATCH push (sets changed): totalSets:", totalSetCount)
            }

            // Szene-Änderungen
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .inactive, .background:
                    sessionManager.persistSnapshotIfNeeded()
                    if !sessionManager.isTrainingActive, #available(iOS 16.1, *) {
                        LiveActivityManager.shared.endActivity()
                    }
                case .active:
                    healthManager.detectLatestWeightChangeForHome()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        loadPendingWeightUpdateNotice()
                    }
                    if !sessionManager.isTrainingActive, #available(iOS 16.1, *) {
                        LiveActivityManager.shared.endActivity()
                    }
                    if !sessionManager.isTrainingActive,
                       let snap = sessionManager.loadResumeSnapshot() {
                        pendingResume = snap
                        withAnimation(.spring()) { showResumeCard = true }
                    }
                default:
                    break
                }
            }
            // 2) Auto-Widget-Sync alle 2 Sekunden
            .onReceive(widgetUpdateTimer) { _ in
                guard scenePhase == .active else { return }
                healthManager.refreshToday()
                updateWidgetData()
            }
            // ⬇️ NEU: Heatmap-Snapshot immer aktualisieren, wenn sich die History ändert
            .onReceive(trainingStore.$history) { hist in
                HeatmapShared.saveSnapshot(from: hist) { $0.date }
                WidgetCenter.shared.reloadTimelines(ofKind: "TrainingHeatmapWidget")
            }

            // Versteckte NavigationLinks für die anderen Ziele
            .overlay(alignment: .center) {
                navigationLinks()
                    .frame(width: 0, height: 0)
            }
        }
        // === Overlay: Resume-Glass-Card =====================================
        .overlay(alignment: .bottom) {
            if showResumeCard, let snap = pendingResume {
                ResumeTrainingGlassCard(
                    title: snap.title.isEmpty ? appSettings.localized("home.defaultTrainingTitle") : snap.title,
                    elapsed: snap.elapsed,
                    onDismiss: {
                        withAnimation(.spring()) { showResumeCard = false }
                        pendingResume = nil
                        sessionManager.clearResumeSnapshot()
                    },
                    onContinue: {
                        _ = sessionManager.resume(from: snap)
                        sessionManager.clearResumeSnapshot()
                        withAnimation(.spring()) { showResumeCard = false }
                        pendingResume = nil
                        showNewTraining = true
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1000)
            }
        }
    }

    // MARK: - App-Review anfordern

    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        SKStoreReviewController.requestReview(in: scene)
    }

    // MARK: - Avatar aus Firestore in @AppStorage cachen

    private func prefetchAvatarIntoAppStorage() async {
        guard let uid = authService.user?.uid, !authService.isGuest else { return }
        let db = Firestore.firestore()
        do {
            async let userDoc  = db.collection("users").document(uid).getDocument()
            async let stateDoc = db.collection("users").document(uid)
                .collection("state").document("profile").getDocument()
            let (userSnap, stateSnap) = try await (userDoc, stateDoc)
            let userData  = userSnap.data() ?? [:]
            let stateData = stateSnap.data() ?? [:]
            let b64 = (stateData["imageB64"] as? String) ?? (userData["photoInline"] as? String)
            if let b64, let bytes = Data(base64Encoded: b64) {
                self.profileImageData = bytes
            }
        } catch {
            print("[HOME] Avatar preload error:", error.localizedDescription)
        }
    }

    // MARK: - Sections (UI)
    private var todayHeaderString: String {
        let formatter = DateFormatter()
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        formatter.locale = Locale(identifier: code)
        formatter.dateFormat = "EEE, d. MMM"
        return formatter.string(from: Date())
    }

    @ViewBuilder
    private func greetingSection() -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button { activeSheet = .profile } label: {
                ProfileAvatarButton(
                    customProfileImageData: profileImageData,
                    initials: initialsFromUser(),
                    size: 52
                )
            }
            .accessibilityLabel(appSettings.localized("profile.title"))
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(homeCopy(de: "Hi, \(userName)", en: "Hi, \(userName)"))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(homeCopy(de: "Bereit fürs nächste Training?", en: "Ready for your next workout?"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Text(todayHeaderString)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white.opacity(0.09)))
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    @ViewBuilder
    private func focusMetricTabs() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HomeFocusMetric.allCases) { metric in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedFocusMetric = metric
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 14, weight: .bold))
                            Text(metric.title(using: appSettings))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(selectedFocusMetric == metric ? .black : .white.opacity(0.58))
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(
                            Capsule()
                                .fill(selectedFocusMetric == metric ? t.palette.primary : .white.opacity(0.09))
                        )
                        .overlay(Capsule().stroke(.white.opacity(selectedFocusMetric == metric ? 0 : 0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func weeklyTrainingCard() -> some View {
        switch selectedFocusMetric {
        case .training:
            trainingOverviewCard()
        case .plan:
            planOverviewCard()
        case .steps:
            stepsOverviewCard()
        case .weight:
            weightOverviewCard()
        }
    }

    @ViewBuilder
    private func planOverviewCard() -> some View {
        let program = challengeStore.activeTrainingProgram()
        let nextTemplate = challengeStore.recommendedTemplate(from: trainingStore.history)
        let active = challengeStore.activeProgram
        let progress = planProgress(program: program, active: active)

        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(t.palette.primary)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.10))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(program?.title ?? homeCopy(de: "Dein Trainingsplan", en: "Your training plan"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Text(planSubtitle(program: program, active: active))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(nextTemplate == nil
                         ? homeCopy(de: "Erstelle einen Plan aus deinen Zielen, Tagen und Equipment.", en: "Create a plan from your goals, days and equipment.")
                         : homeCopy(de: "Empfohlen: \(nextTemplate?.name ?? "")", en: "Recommended: \(nextTemplate?.name ?? "")"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer(minLength: 8)

                CircularMetricBadge(
                    progress: progress,
                    icon: nextTemplate == nil ? "sparkles" : "checklist",
                    tint: t.palette.primary
                )
                .frame(width: 54, height: 54)
            }

            Divider()
                .overlay(.white.opacity(0.14))

            VStack(alignment: .leading, spacing: 12) {
                Text(nextTemplate?.name ?? homeCopy(de: "Noch kein Plan aktiv", en: "No active plan yet"))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let nextTemplate {
                    HStack(spacing: 10) {
                        planChip(icon: "list.bullet", text: "\(nextTemplate.exercises.count) \(homeCopy(de: "Übungen", en: "exercises"))")
                        planChip(icon: "clock", text: "~\(estimatedMinutes(for: nextTemplate)) min")
                        if let program {
                            planChip(
                                icon: "repeat",
                                text: program.isUnlimited
                                    ? homeCopy(de: "∞ Plan", en: "∞ Plan")
                                    : "\(program.durationWeeks) \(homeCopy(de: "Wo.", en: "wk"))"
                            )
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    if let nextTemplate {
                        startTemplateFromPlan(nextTemplate)
                    } else {
                        tabSelection = 2
                    }
                } label: {
                    Label(nextTemplate == nil ? homeCopy(de: "Plan erstellen", en: "Create plan") : homeCopy(de: "Heute starten", en: "Start today"),
                          systemImage: nextTemplate == nil ? "wand.and.stars" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(.black)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(t.palette.primary))
                }
                .buttonStyle(.plain)

                Button { tabSelection = 2 } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 18)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func trainingOverviewCard() -> some View {
        let completed = workoutsThisWeek()
        let goal = max(1, weeklyGoal)
        let progress = min(Double(completed) / Double(goal), 1)
        let week = currentWeekTrainingDays()

        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: selectedFocusMetric.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(t.palette.primary)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.10))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(primaryGoalTitle())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(homeCopy(de: "Letzte 7 Tage", en: "Last 7 days"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                    Text(
                        homeCopy(
                            de: "Wochenfortschritt: \(completed) von \(goal) Einheiten",
                            en: "Weekly progress: \(completed) of \(goal) sessions"
                        )
                    )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
                }

                Spacer(minLength: 8)

                CircularMetricBadge(
                    progress: progress,
                    icon: selectedFocusMetric == .steps ? "figure.walk" : "flame.fill",
                    tint: t.palette.primary
                )
                .frame(width: 54, height: 54)
            }

            Divider()
                .overlay(.white.opacity(0.14))

            HStack(spacing: 0) {
                ForEach(week) { day in
                    VStack(spacing: 9) {
                        Text(shortWeekday(day.date))
                            .font(.system(size: 14, weight: day.isToday ? .bold : .semibold))
                            .foregroundStyle(day.isToday ? .white : .white.opacity(0.58))

                        ZStack {
                            Circle()
                                .fill(day.isToday ? .white.opacity(0.16) : .white.opacity(0.09))
                                .frame(width: 42, height: 42)
                            Circle()
                                .trim(from: 0, to: day.value > 0 ? 1 : 0)
                                .stroke(
                                    day.isToday ? t.palette.primary : .orange.opacity(0.82),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 42, height: 42)
                            Image(systemName: day.value > 0 ? "flame.fill" : "minus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(day.value > 0 ? .orange : .white.opacity(0.34))
                        }

                        Text("\(day.value)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(day.value > 0 ? .white : .white.opacity(0.36))
                            .numericTextTransition()
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 0) {
                SummaryMetric(
                    value: "\(completed)",
                    label: homeCopy(de: "Diese Woche", en: "This week")
                )

                Spacer(minLength: 10)

                Button { showNewTraining = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.black)
                        .frame(width: 46, height: 46)
                        .background(t.palette.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 18)
        .padding(.horizontal, 20)
    }

    private func planSubtitle(program: TrainingProgram?, active: ActiveProgram?) -> String {
        guard let program, let active else {
            return homeCopy(de: "Aus mehreren Templates gebaut", en: "Built from multiple templates")
        }
        if program.isUnlimited {
            return homeCopy(
                de: "Woche \(active.currentWeek) läuft",
                en: "Week \(active.currentWeek) running"
            )
        }
        return homeCopy(
            de: "Woche \(min(active.currentWeek, program.durationWeeks)) von \(program.durationWeeks)",
            en: "Week \(min(active.currentWeek, program.durationWeeks)) of \(program.durationWeeks)"
        )
    }

    private func planProgress(program: TrainingProgram?, active: ActiveProgram?) -> Double {
        guard let program, let active else { return 0 }
        if program.isUnlimited {
            let cycle = max(1, program.schedule.count)
            return Double((active.currentWeek - 1) % cycle + 1) / Double(cycle)
        }
        return min(Double(active.currentWeek) / Double(max(1, program.durationWeeks)), 1)
    }

    private func estimatedMinutes(for template: TrainingTemplate) -> Int {
        max(30, min(90, template.exercises.count * 8))
    }

    private func planChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white.opacity(0.68))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(.white.opacity(0.09)))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func startTemplateFromPlan(_ template: TrainingTemplate) {
        sessionManager.startTraining(title: template.name, source: "from_plan", templateId: template.id, hasActivePlan: true)
        for name in template.exercises { sessionManager.addExercise(name) }
        sessionManager.activities = template.activities
        sessionManager.persistSnapshotIfNeeded()
        AnalyticsService.trackWorkoutStarted(source: "from_plan", template: template, hasActivePlan: true)
        showNewTraining = true
    }

    @ViewBuilder
    private func stepsOverviewCard() -> some View {
        let steps = healthManager.todaySteps
        let progress = min(Double(steps) / Double(max(1, stepsGoal)), 1)

        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(homeCopy(de: "Schritte heute", en: "Today's steps"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                    Text("\(steps)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .numericTextTransition()
                    Text(homeCopy(de: "Ziel: \(stepsGoal) Schritte", en: "Goal: \(stepsGoal) steps"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                }

                Spacer()

                ZStack {
                    HomeProgressRing(progress: progress, color: .cyan, lineWidth: 9)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.cyan)
                }
                .frame(width: 76, height: 76)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.11))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, t.palette.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(14, proxy.size.width * progress))
                }
            }
            .frame(height: 16)

            HStack {
                HomeMiniMetric(title: homeCopy(de: "Fortschritt", en: "Progress"), value: "\(Int(progress * 100))%")
                Spacer()
                Button { activeSheet = .steps } label: {
                    Label(homeCopy(de: "Details", en: "Details"), systemImage: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(.cyan)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 18)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func weightOverviewCard() -> some View {
        let displayWeight = latestHomeWeight ?? weightKg
        let currentWeight = displayWeight > 0 ? formatKg(displayWeight) : "—"
        let goalText = effectiveGoalWeightKg.map { "\(formatKg($0)) kg" } ?? "—"
        let delta = effectiveGoalWeightKg.map { displayWeight > 0 ? displayWeight - $0 : 0 } ?? 0

        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(homeCopy(de: "Gewicht", en: "Weight"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(currentWeight)
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("kg")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(displayWeight > 0 ? 0.64 : 0))
                    }
                    Text(homeCopy(de: "Ziel: \(goalText)", en: "Goal: \(goalText)"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                }

                Spacer()

                Image(systemName: "scalemass.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.pink)
                    .frame(width: 64, height: 64)
                    .background(.pink.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
            }

            HStack(spacing: 12) {
                HomeMiniMetric(
                    title: homeCopy(de: "Differenz", en: "Difference"),
                    value: effectiveGoalWeightKg == nil || displayWeight <= 0 ? "—" : "\(formatKg(abs(delta))) kg"
                )
                HomeMiniMetric(
                    title: homeCopy(de: "Trend", en: "Trend"),
                    value: weightStatusText(delta)
                )
            }

            Button { activeSheet = .weight } label: {
                Label(homeCopy(de: "Gewicht öffnen", en: "Open weight"), systemImage: "chart.xyaxis.line")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(.pink)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 18)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func quickStartSection() -> some View {
        HStack(spacing: 12) {
            HomeInsightTile(
                title: homeCopy(de: "Diese Woche", en: "This week"),
                value: "\(workoutsThisWeek())/\(weeklyGoal)",
                icon: "checkmark.seal.fill",
                tint: t.palette.primary
            ) { activeSheet = .lastTraining }

            HomeInsightTile(
                title: homeCopy(de: "Letzte Einheit", en: "Last session"),
                value: lastTrainingShortText(),
                icon: "clock.arrow.circlepath",
                tint: .cyan
            ) { activeSheet = .lastTraining }

            HomeInsightTile(
                title: homeCopy(de: "Routinen", en: "Routines"),
                value: "\(homeTemplates.count)",
                icon: "square.stack.3d.up.fill",
                tint: t.palette.primary
            ) { showTemplates = true }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func trainingHeroSection() -> some View {
        let completed = workoutsThisWeek()
        let goal = max(1, weeklyGoal)
        let progress = min(Double(completed) / Double(goal), 1.0)

        Button(action: { showStartMenu = true }) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(homeCopy(de: "HEUTE TRAINIEREN", en: "TRAIN TODAY"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(t.palette.primary)
                            .tracking(0.6)

                        Text(homeCopy(de: "Starte deine nächste Einheit", en: "Start your next session"))
                            .font(.system(size: 27, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(homeCopy(
                            de: "Krafttraining, Lauf oder manueller Eintrag.",
                            en: "Strength, run, or manual entry."
                        ))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    ZStack {
                        HomeProgressRing(progress: progress, color: t.palette.primary, lineWidth: 7)
                            .frame(width: 58, height: 58)
                        VStack(spacing: 0) {
                            Text("\(completed)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .numericTextTransition()
                            Text("/\(goal)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(appSettings.localized("home.weeklyGoal.title"))
                }

                HStack(spacing: 10) {
                    Label(homeCopy(de: "Training starten", en: "Start workout"), systemImage: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 46)
                        .background(t.palette.primary)
                        .clipShape(Capsule())

                    Label(homeCopy(de: "Wochenziel", en: "Weekly goal"), systemImage: "target")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(.separator).opacity(0.28), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func trainingPulseSection() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(homeCopy(de: "Dein Trainingsstand", en: "Training pulse"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button(appSettings.localized("common.edit")) { showEditDashboard = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(t.palette.primary)
            }
            .padding(.horizontal, 20)

            HomeStatsGrid(
                healthManager: healthManager,
                workoutsToday: workoutsCompletedToday(),
                lastTrainingDate: trainingHistory.sorted { $0.date > $1.date }.first?.date,
                onOpenSteps:  { activeSheet = .steps },
                onOpenWeight: { activeSheet = .weight },
                onOpenCalories: { activeSheet = .calories },
                onOpenWater:   { activeSheet = .water },
                onOpenSleep:   { activeSheet = .sleep },
                onOpenLastTraining: { activeSheet = .lastTraining },
                items: visibleDashboardItems
            )
            .id(visibleDashboardItems.map { $0.id }.joined())
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: visibleDashboardItems)
        }
        .sheet(isPresented: $showEditDashboard) {
            EditDashboardView(activeItems: $dashboardItems)
                .environmentObject(appSettings)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: dashboardItems) { newValue in
            let cleaned = newValue.filter { $0.isHomeVisible }
            if cleaned != newValue {
                dashboardItems = cleaned
                return
            }
            if let data = try? JSONEncoder().encode(cleaned) { dashboardItemsData = data }
        }
        .onAppear {
            if let items = try? JSONDecoder().decode([DashboardItem].self, from: dashboardItemsData), !items.isEmpty {
                let cleaned = items.filter { $0.isHomeVisible }
                dashboardItems = cleaned.isEmpty ? DashboardItem.defaultHomeItems : cleaned
            } else {
                dashboardItems = DashboardItem.defaultHomeItems
            }
        }
    }

    @ViewBuilder
    private func motivationalCard() -> some View {
        Button(action: {
            // showStartMenu = true
            showNewTraining = true
        }) {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Color.blue.opacity(0.15), lineWidth: 6).frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: min(Double(workoutsThisWeek()) / Double(max(1, weeklyGoal)), 1.0))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)
                        .animation(.easeInOut(duration: 0.35), value: workoutsThisWeek())
                    Image(systemName: "figure.run")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(appSettings.localized("home.weeklyGoal.title"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(workoutsThisWeek())")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .numericTextTransition()
                        Text(String(format: appSettings.localized("home.weeklyGoal.progress"), weeklyGoal))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    .scaleEffect(showStartMenu ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showStartMenu)
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(.separator).opacity(0.3), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    // Dashboard State
    @AppStorage("dashboard.items") private var dashboardItemsData: Data = Data()
    @State private var dashboardItems: [DashboardItem] = []
    @State private var showEditDashboard = false

    private var visibleDashboardItems: [DashboardItem] {
        let filtered = dashboardItems.filter { $0.isHomeVisible }
        return filtered.isEmpty ? DashboardItem.defaultHomeItems : filtered
    }

    @ViewBuilder
    private func statsGridSection() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(appSettings.localized("home.statsTitle"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button(appSettings.localized("common.edit")) { showEditDashboard = true }
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            HomeStatsGrid(
                healthManager: healthManager,
                workoutsToday: workoutsCompletedToday(),
                lastTrainingDate: trainingHistory.sorted { $0.date > $1.date }.first?.date,
                onOpenSteps:  { activeSheet = .steps },
                onOpenWeight: { activeSheet = .weight },
                onOpenCalories: { activeSheet = .calories },
                onOpenWater:   { activeSheet = .water },
                onOpenSleep:   { activeSheet = .sleep },
                onOpenLastTraining: { activeSheet = .lastTraining },
                items: dashboardItems
            )
            .id(dashboardItems.map { $0.id }.joined())
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: dashboardItems)
        }
        .sheet(isPresented: $showEditDashboard) {
            EditDashboardView(activeItems: $dashboardItems)
                .environmentObject(appSettings)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: dashboardItems) { newValue in
            if let data = try? JSONEncoder().encode(newValue) { dashboardItemsData = data }
        }
        .onAppear {
            if let items = try? JSONDecoder().decode([DashboardItem].self, from: dashboardItemsData), !items.isEmpty {
                dashboardItems = items
            } else {
                dashboardItems = [.steps, .calories, .weight, .lastTraining]
            }
        }
    }



    @ViewBuilder
    private func activeTrainingSection() -> some View {
        if sessionManager.isTrainingActive {
            CurrentTrainingCard(
                title: sessionManager.trainingTitle.isEmpty
                ? appSettings.localized("home.defaultTrainingTitle")
                : sessionManager.trainingTitle,
                sinceText: appSettings.localized("home.since"),
                elapsed: sessionManager.elapsedTime,
                completedSets: completedSets(),
                totalSets: totalSets(),
                onContinue: { showNewTraining = true }
            )
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func templatesSection() -> some View {
        let templates = homeTemplates

        VStack(spacing: 18) {
            HStack {
                Text(homeCopy(de: "Daily Program", en: "Daily Program"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button(appSettings.localized("common.viewAll")) { showTemplates = true }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.horizontal, 20)

            if templates.isEmpty {
                // Hint card to pin templates
                VStack(alignment: .leading, spacing: 12) {
                    Text(appSettings.localized("templates.favorites.title"))
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(appSettings.localized("templates.favorites.desc"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button {
                            showTemplates = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "pin")
                                Text(appSettings.localized("templates.favorites.select"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(t.palette.primary)
                    }
                }
                .padding(16)
                .background(.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(templates.prefix(3), id: \.id) { tpl in
                        HomeProgramRow(
                            template: tpl,
                            isDefaultFallback: !templateStore.isPinned(tpl),
                            onTap: { previewTemplate = tpl },
                            onStart: {
                                sessionManager.startTraining(title: tpl.name, source: "from_template", templateId: tpl.id)
                                for name in tpl.exercises { sessionManager.addExercise(name) }
                                sessionManager.activities = tpl.activities
                                sessionManager.persistSnapshotIfNeeded()
                                AnalyticsService.trackWorkoutStarted(source: "from_template", template: tpl)
                                showNewTraining = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var totalSetCount: Int {
        sessionManager.exercises.reduce(0) { $0 + $1.sets.count }
    }



    private func buildActiveWorkoutPayload() -> ActiveWorkoutPayload {
        // WorkoutId stabil halten, solange Training läuft
        let wid = watchWorkoutId.isEmpty ? UUID().uuidString : watchWorkoutId

        func strId(_ any: Any) -> String {
            if let u = any as? UUID { return u.uuidString }
            return String(describing: any)
        }

        func mirrorValue<T>(_ obj: Any, _ key: String, as: T.Type) -> T? {
            Mirror(reflecting: obj).children.first { $0.label == key }?.value as? T
        }

        func exerciseName(_ ex: Any, fallback: String) -> String {
            if let n: String = mirrorValue(ex, "name", as: String.self) { return n }
            if let t: String = mirrorValue(ex, "title", as: String.self) { return t }
            if let e = mirrorValue(ex, "exercise", as: Any.self) {
                if let n: String = mirrorValue(e, "name", as: String.self) { return n }
                if let t: String = mirrorValue(e, "title", as: String.self) { return t }
            }
            return fallback
        }

        let exercises: [ActiveWorkoutPayload.ExerciseItem] =
        sessionManager.exercises.enumerated().map { idx, ex in

            // exercise instance id
            let exAnyId = mirrorValue(ex, "id", as: Any.self) ?? UUID()
            let exId = strId(exAnyId)

            // name
            let name = exerciseName(ex, fallback: "Exercise \(idx + 1)")

            // sets array (best effort)
            let exSets: [Any] = mirrorValue(ex, "sets", as: [Any].self) ?? []

            let sets: [ActiveWorkoutPayload.LoggedSetItem] = exSets.enumerated().map { sIdx, s in
                let sAnyId = mirrorValue(s, "id", as: Any.self) ?? UUID()
                let sid = strId(sAnyId)

                let reps = mirrorValue(s, "reps", as: Int.self) ?? {
                    // try string reps to int
                    if let str: String = mirrorValue(s, "reps", as: String.self) {
                        return Int(str.filter("0123456789".contains)) ?? 0
                    }
                    return 0
                }()

                let weight = mirrorValue(s, "weight", as: Double.self) ?? {
                    if let str: String = mirrorValue(s, "weight", as: String.self) {
                        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        let nf = NumberFormatter(); nf.locale = .current; nf.numberStyle = .decimal
                        if let n = nf.number(from: trimmed) { return n.doubleValue }
                        if let d = Double(trimmed.replacingOccurrences(of: ",", with: ".")) { return d }
                        if let n = nf.number(from: trimmed.replacingOccurrences(of: ".", with: ",")) { return n.doubleValue }
                    }
                    return 0.0
                }()

                let completed = mirrorValue(s, "isCompleted", as: Bool.self) ?? false

                return .init(id: sid, reps: reps, weight: weight, completed: completed)
            }

            return .init(
                id: exId,
                name: name,
                order: idx,
                setCount: sets.count,
                sets: sets
            )
        }

        return ActiveWorkoutPayload(
            isActive: true,
            workoutId: wid,
            workoutName: sessionManager.trainingTitle.isEmpty ? "Training" : sessionManager.trainingTitle,
            exercises: exercises,
            selectedExerciseId: exercises.first?.id
        )
    }





    // MARK: - Next Rank Card
    private struct NextRankCard: View {
        let region: MuscleRegion
        let needed: Int
        let nextRank: MuscleRank

        @Environment(\.designTokens) private var t
        @EnvironmentObject var appSettings: AppSettings

        var body: some View {
            HStack(spacing: 16) {
                // Icon Circle
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [nextRank.color.opacity(0.8), nextRank.color.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)
                        .shadow(color: nextRank.color.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: iconName(for: region))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // "Nächstes Level: REGION"
                    Text("\(appSettings.localized("home.nextLevel")): \(localizedRegionName(region))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(needed)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("\(trainingWord(needed)) \(appSettings.localized("home.until"))")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(localizedRankTitle(nextRank))
                            .font(.body.weight(.bold))
                            .foregroundStyle(nextRank.color)
                    }
                }
                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [nextRank.color.opacity(0.5), nextRank.color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        }

        private func iconName(for region: MuscleRegion) -> String {
            switch region {
            case .chest: return "scalemass.fill"
            case .shoulders: return "figure.strengthtraining.traditional"
            case .biceps, .triceps, .forearms: return "figure.strengthtraining.traditional"
            case .abs: return "figure.core.training"
            case .quads, .hamstrings, .calves, .calvesBack, .glutes: return "figure.run"
            case .lats, .traps, .lowerBack: return "figure.strengthtraining.traditional"
            }
        }

        private func localizedRegionName(_ region: MuscleRegion) -> String {
            let key = "muscle.region.\(region.rawValue)"
            let val = appSettings.localized(key)
            if val != key { return val }
            // fallback to German names (previous implementation)
            switch region {
            case .chest: return "Brust"
            case .shoulders: return "Schultern"
            case .biceps: return "Bizeps"
            case .triceps: return "Trizeps"
            case .lats: return "Rücken (Lat)"
            case .abs: return "Bauch"
            case .quads: return "Beine (Quad)"
            case .hamstrings: return "Beinbeuger"
            case .glutes: return "Gesäß"
            case .calves, .calvesBack: return "Waden"
            case .forearms: return "Unterarme"
            case .traps: return "Nacken"
            case .lowerBack: return "Unterer Rücken"
            }
        }

        private func localizedRankTitle(_ rank: MuscleRank) -> String {
            let key = "rank.\(rank.rawValue)"
            let val = appSettings.localized(key)
            return (val == key) ? rank.title : val
        }

        private func trainingWord(_ n: Int) -> String {
            if appSettings.language.lowercased().hasPrefix("de") {
                return n == 1 ? "Punkt" : "Punkte"
            }
            return n == 1 ? "point" : "points"
        }
    }

    @ViewBuilder
    private func navigationLinks() -> some View {
        ZStack {
            // NewTrainingView wurde auf fullScreenCover umgestellt – hier NICHT mehr verlinken

            NavigationLink(isActive: $showManualEntry) {
                ManualTrainingView()
                    .environmentObject(trainingStore)
                    .environmentObject(gm)
                    .environmentObject(appSettings)
            } label: { EmptyView() }

            NavigationLink(isActive: $showTemplates) {
                TrainingTemplatesView(showNewTraining: $showNewTraining)
                    .environmentObject(sessionManager)
                    .environmentObject(templateStore)
                    .environmentObject(appSettings)
                    .environmentObject(exerciseLibrary)
            } label: { EmptyView() }

        }
        .frame(width: 0, height: 0)
    }

    // MARK: - Helpers

    private func homeCopy(de: String, en: String) -> String {
        appSettings.language.lowercased().hasPrefix("de") ? de : en
    }

    @ViewBuilder
    private func weightUpdateNotice() -> some View {
        if let notice = weightUpdateBanner {
            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(t.palette.primary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(homeCopy(de: "Gewicht aktualisiert", en: "Weight updated"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(homeCopy(de: "Neuer Wert: \(notice.formattedKg) kg", en: "New value: \(notice.formattedKg) kg"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.56))
                }

                Spacer()

                Button {
                    dismissWeightUpdateNotice()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.13), lineWidth: 1))
            .padding(.horizontal, 20)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func loadPendingWeightUpdateNotice() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "movo.latestWeightUpdate.kg") != nil,
              !defaults.bool(forKey: "movo.latestWeightUpdate.seen") else {
            weightUpdateBanner = nil
            return
        }

        let kg = defaults.double(forKey: "movo.latestWeightUpdate.kg")
        let date = defaults.object(forKey: "movo.latestWeightUpdate.date") as? Date ?? Date()
        guard Date().timeIntervalSince(date) < 7 * 24 * 60 * 60 else {
            dismissWeightUpdateNotice()
            return
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            weightUpdateBanner = WeightUpdateBanner(kg: kg)
        }
    }

    private func dismissWeightUpdateNotice() {
        UserDefaults.standard.set(true, forKey: "movo.latestWeightUpdate.seen")
        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            weightUpdateBanner = nil
        }
    }

    private func primaryGoalTitle() -> String {
        switch selectedFocusMetric {
        case .training:
            return homeCopy(de: "\(weeklyGoal) Trainings diese Woche", en: "\(weeklyGoal) workouts this week")
        case .plan:
            return homeCopy(de: "Trainingsplan", en: "Training plan")
        case .steps:
            return homeCopy(de: "\(healthManager.todaySteps) Schritte heute", en: "\(healthManager.todaySteps) steps today")
        case .weight:
            if let goal = effectiveGoalWeightKg {
                return homeCopy(de: "Zielgewicht \(formatKg(goal)) kg", en: "Goal weight \(formatKg(goal)) kg")
            }
            return homeCopy(de: "Gewicht im Blick behalten", en: "Keep weight in view")
        }
    }

    private func currentWeekTrainingDays() -> [HomeWeekDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2
        let start = calendar.date(from: components) ?? today

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let count = trainingHistory.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
            return HomeWeekDay(date: date, value: count, isToday: calendar.isDate(date, inSameDayAs: today))
        }
    }

    private func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func formatKg(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func loadHomeWeightTrend() {
        healthManager.fetchWeightHistory(days: 90) { entries in
            let sorted = entries.sorted { $0.date < $1.date }
            DispatchQueue.main.async {
                latestHomeWeight = sorted.last?.value
                previousHomeWeight = sorted.dropLast().last?.value
                if let latestHomeWeight {
                    weightKg = latestHomeWeight
                }
            }
        }
    }

    private func weightStatusText(_ delta: Double) -> String {
        guard let latest = latestHomeWeight ?? (weightKg > 0 ? weightKg : nil) else { return "—" }
        if let previousHomeWeight {
            let trend = latest - previousHomeWeight
            if abs(trend) < 0.05 { return "±0.0 kg" }
            let sign = trend > 0 ? "+" : "−"
            return "\(sign)\(formatKg(abs(trend))) kg"
        }
        guard effectiveGoalWeightKg != nil else { return "—" }
        if abs(delta) < 0.2 { return homeCopy(de: "Am Ziel", en: "On goal") }
        return delta > 0 ? homeCopy(de: "Darüber", en: "Above") : homeCopy(de: "Darunter", en: "Below")
    }

    private func lastTrainingShortText() -> String {
        guard let date = trainingHistory.sorted(by: { $0.date > $1.date }).first?.date else { return "—" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return homeCopy(de: "Heute", en: "Today") }
        if calendar.isDateInYesterday(date) { return homeCopy(de: "Gestern", en: "Yesterday") }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        if days > 0 && days < 10 { return "\(days)d" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US")
        formatter.dateFormat = "d. MMM"
        return formatter.string(from: date)
    }

    private var userName: String {
        if let displayName = authService.user?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let email = authService.user?.email {
            let namePart = email.split(separator: "@").first ?? ""
            let firstName = namePart.split(separator: ".").first ?? ""
            if !firstName.isEmpty {
                return String(firstName).capitalized
            }
        }
        if authService.isGuest {
            return "Guest"
        }
        return "Friend"
    }

    private func prettifiedTitle(for raw: String) -> String {
        let l = raw.lowercased()
        if l.hasPrefix("week ") || l.hasPrefix("woche ") {
            let digits = raw.filter(\.isNumber)
            if let n = Int(digits) {
                return String(format: appSettings.localized("week.number"), n)
            }
        }
        return raw
    }

    private func initialsFromUser() -> String { "MO" }

    private func totalSets() -> Int {
        sessionManager.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func completedSets() -> Int {
        sessionManager.exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }

    private func workoutsCompletedToday() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return trainingHistory.filter { entry in
            cal.isDate(entry.date, inSameDayAs: today)
        }.count
    }

    // NEU: Anzahl Workouts in der aktuellen Woche (Montag–Sonntag)
    private func workoutsThisWeek() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Montag
        guard let startOfWeek = calendar.date(from: components),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return 0
        }
        return trainingHistory.filter { entry in
            entry.date >= startOfWeek && entry.date < endOfWeek
        }.count
    }

    // MARK: - Schritte Panel (als Nested View)

    struct StepsPanelView: View {
        @ObservedObject var healthManager: HealthKitManager
        @Environment(\.dismiss) private var dismiss
        @Environment(\.designTokens) private var t
        @EnvironmentObject var appSettings: AppSettings
        @AppStorage("steps.goal") private var goal: Int = 8000

        @State private var daysBack: Int = 7
        @State private var days: [DaySteps] = []
        @State private var isAuthorized = false
        @State private var csvURL: URL?

        private let store = HKHealthStore()

        private var appLocale: Locale {
            let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
            return Locale(identifier: code)
        }

        private var total: Int { days.reduce(0) { $0 + $1.steps } }
        private var avg: Int { days.isEmpty ? 0 : total / days.count }
        private var best: Int { days.map(\.steps).max() ?? 0 }
        private var hit: Int { days.filter { $0.steps >= goal }.count }
        private var progressToday: Double {
            guard goal > 0 else { return 0 }
            return min(1, Double(healthManager.todaySteps) / Double(goal))
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.26), t.palette.primary.opacity(0.20), .clear],
                        center: .topLeading,
                        startRadius: 30,
                        endRadius: 420
                    )
                    .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 18) {
                        // HEADER
                        HStack(spacing: 16) {
                            ZStack {
                                HomeProgressRing(progress: progressToday, color: t.palette.primary, lineWidth: 10)
                                    .frame(width: 82, height: 82)
                                Image(systemName: "figure.walk")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(t.palette.primary)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(appSettings.localized("steps.unit"))
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(healthManager.todaySteps) / \(goal)")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .numericTextTransition()
                                ProgressView(value: min(Double(healthManager.todaySteps), Double(goal)),
                                             total: Double(goal))
                                .tint(.white)
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 1)
                        )
                        .padding(.horizontal)

                        // Zeitraum
                        Picker("", selection: $daysBack) {
                            Text("7 \(appSettings.localized("days"))").tag(7)
                            Text("14 \(appSettings.localized("days"))").tag(14)
                            Text("30 \(appSettings.localized("days"))").tag(30)
                            Text("90 \(appSettings.localized("days"))").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // KPIs
                        HStack(spacing: 12) {
                            kpiBox(title: appSettings.localized("steps.kpi.today"), value: healthManager.todaySteps)
                            kpiBox(title: appSettings.localized("steps.kpi.avgPerDay"), value: avg)
                            kpiBox(title: appSettings.localized("steps.kpi.best"), value: best)
                            kpiBox(title: appSettings.localized("steps.kpi.goalDays"), value: hit)
                        }
                        .padding(.horizontal)

                        // Verlauf
                        sectionCard(title: appSettings.localized("statistics.progress"), icon: "chart.bar.fill") {
                            if #available(iOS 16.0, *) {
                                if days.isEmpty {
                                    Text(appSettings.localized("steps.noDataRange"))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Chart {
                                        ForEach(days) { d in
                                            BarMark(
                                                x: .value(appSettings.localized("statistics.date"), d.date, unit: .day),
                                                y: .value(appSettings.localized("steps.unit"), d.steps)
                                            )
                                            .foregroundStyle(t.palette.primary)
                                        }
                                        RuleMark(y: .value("Goal", goal))
                                            .lineStyle(.init(lineWidth: 1, dash: [4,4]))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(height: 240)
                                    .chartYAxis { AxisMarks(position: .leading) }
                                    .chartXAxis {
                                        let strategy = xAxisStrategy(for: daysBack)
                                        AxisMarks(values: .stride(by: strategy.component, count: strategy.step)) { value in
                                            AxisGridLine(); AxisTick()
                                            AxisValueLabel {
                                                if let date = value.as(Date.self) {
                                                    Text(xAxisLabel(for: date, daysBack: daysBack, locale: appLocale))
                                                }
                                            }
                                        }
                                    }
                                    .environment(\.locale, appLocale)
                                    .animation(.easeInOut(duration: 0.3), value: days) // Bars wachsen sanft
                                }
                            } else {
                                Text(appSettings.localized("common.ios16.required"))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        // Ziel
                        sectionCard(title: appSettings.localized("steps.goal.title"), icon: "target") {
                            HStack {
                                Text(appSettings.localized("steps.dailyGoal"))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Stepper("",
                                        onIncrement: { setGoal(goal + 500) },
                                        onDecrement: { setGoal(goal - 500) })
                                Text("\(goal)")
                                    .monospacedDigit()
                                    .font(.subheadline)
                                    .frame(minWidth: 60, alignment: .trailing)
                                    .numericTextTransition()
                            }
                        }
                        .padding(.horizontal)

                        // Tage-Liste
                        sectionCard(title: appSettings.localized("steps.list.title"), icon: "list.bullet") {
                            if days.isEmpty {
                                Text(appSettings.localized("steps.noData"))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(days) { d in
                                        HStack {
                                            Text(dateString(d.date))
                                            Spacer()
                                            Text("\(d.steps)")
                                                .monospacedDigit()
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(d.steps >= goal ? t.palette.positive : .primary)
                                                .numericTextTransition()
                                        }
                                        .padding(.vertical, 10)
                                        Divider()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 8)
                    }
                    .padding(.top, 10)
                    }
                }
                .navigationTitle(appSettings.localized("steps.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(appSettings.localized("settings.done")) { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if let url = csvURL {
                                ShareLink(item: url) {
                                    Label(appSettings.localized("steps.menu.csvShare"), systemImage: "square.and.arrow.up")
                                }
                            } else {
                                Button { csvURL = makeCSV(from: days) } label: {
                                    Label(appSettings.localized("steps.menu.csvMake"), systemImage: "doc.plaintext")
                                }
                            }
                            Button { openHealthApp() } label: {
                                Label(appSettings.localized("steps.menu.openHealth"), systemImage: "heart.fill")
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                .task {
                    await ensureAuthorization()
                    await reload()
                    healthManager.refreshToday()
                }
                .onChange(of: daysBack) { _ in Task { await reload() } }
            }
            .presentationDetents([.fraction(0.5), .large])
            .presentationDragIndicator(.visible)
            .environment(\.locale, appLocale)
            .preferredColorScheme(.dark)
        }


        // Welche Abstände auf der X-Achse?
        private func xAxisStrategy(for daysBack: Int) -> (component: Calendar.Component, step: Int) {
            switch daysBack {
            case ...7:
                return (.day, 1)
            case 8...14:
                return (.day, 2)
            case 15...30:
                return (.day, 5)
            default:
                return (.day, 15)
            }
        }

        // Wie soll das Label aussehen?
        private func xAxisLabel(for date: Date, daysBack: Int, locale: Locale) -> String {
            let f = DateFormatter()
            f.locale = locale
            f.dateFormat = daysBack <= 7 ? "E" : "d."
            return f.string(from: date)
        }

        // MARK: - Steps helpers

        @ViewBuilder
        private func sectionCard<Content: View>(
            title: String,
            icon: String,
            @ViewBuilder content: () -> Content
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundStyle(t.palette.primary)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 2)
                content()
            }
            .padding(16)
            .background(.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }

        private func kpiBox(title: String, value: Int) -> some View {
            VStack(spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                Text(value.formatted(.number.grouping(.automatic)))
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .numericTextTransition()
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }

        private func ensureAuthorization() async {
            guard HKHealthStore.isHealthDataAvailable() else { return }
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            do {
                try await store.requestAuthorization(toShare: [], read: [stepType])
                isAuthorized = true
            } catch {
                isAuthorized = false
            }
        }

        private func reload() async {
            guard isAuthorized else { days = []; return }
            let now = Date()
            let cal = Calendar.current
            guard let start = cal.date(byAdding: .day, value: -(daysBack - 1), to: cal.startOfDay(for: now)) else {
                days = []
                return
            }
            await fetchSteps(from: start, to: now) { result in
                DispatchQueue.main.async {
                    self.days = result
                    self.csvURL = makeCSV(from: result)
                    let compact = result.map {
                        StepsDayCompact(d: Calendar.current.startOfDay(for: $0.date), s: $0.steps)
                    }
                    StepsShared.saveHistory(days: compact, goal: goal)
                    WidgetCenter.shared.reloadTimelines(ofKind: "StepsWeeklyWidget")
                }
            }
        }

        private func fetchSteps(
            from start: Date,
            to end: Date,
            completion: @escaping ([DaySteps]) -> Void
        ) async {
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let cal = Calendar.current
            let anchor = cal.startOfDay(for: Date())
            var interval = DateComponents()
            interval.day = 1

            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, _ in
                guard let collection else { completion([]); return }
                var tmp: [DaySteps] = []
                collection.enumerateStatistics(from: start, to: end) { stats, _ in
                    let sum = stats.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    tmp.append(DaySteps(date: stats.startDate, steps: Int(sum.rounded())))
                }
                completion(StepsPanelView.fillMissingDays(in: tmp, from: start, to: end))
            }
            store.execute(query)
        }

        private func setGoal(_ newVal: Int) {
            let oldHit = healthManager.todaySteps >= goal
            goal = max(1000, min(30000, newVal))
            let newHit = healthManager.todaySteps >= goal
#if os(iOS)
            if !oldHit && newHit { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
#endif
            let compact = days.map { StepsDayCompact(d: Calendar.current.startOfDay(for: $0.date), s: $0.steps) }
            StepsShared.saveHistory(days: compact, goal: goal)
            WidgetCenter.shared.reloadTimelines(ofKind: "StepsWeeklyWidget")
        }

        private func dateString(_ d: Date) -> String {
            let f = DateFormatter()
            f.locale = appLocale
            f.dateStyle = .medium
            return f.string(from: d)
        }

        private func makeCSV(from data: [DaySteps]) -> URL? {
            let header = "Date,Steps\n"
            let rows = data.map { "\(isoDate($0.date)),\($0.steps)" }.joined(separator: "\n")
            let csv = header + rows
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("steps.csv")
            do {
                try csv.data(using: .utf8)?.write(to: url)
                return url
            } catch {
                return nil
            }
        }

        private func isoDate(_ d: Date) -> String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withFullDate]
            return f.string(from: d)
        }

        private func openHealthApp() {
            guard let url = URL(string: "x-apple-health://") else { return }
            UIApplication.shared.open(url)
        }

        static func fillMissingDays(in arr: [DaySteps], from start: Date, to end: Date) -> [DaySteps] {
            let cal = Calendar.current
            var dict = Dictionary(uniqueKeysWithValues: arr.map { (cal.startOfDay(for: $0.date), $0.steps) })
            var out: [DaySteps] = []
            var day = cal.startOfDay(for: start)
            let last = cal.startOfDay(for: end)
            while day <= last {
                out.append(DaySteps(date: day, steps: dict[day] ?? 0))
                day = cal.date(byAdding: .day, value: 1, to: day)!
            }
            return out
        }
    }

    struct DaySteps: Identifiable, Hashable {
        let id = UUID()
        let date: Date
        let steps: Int
    }

    // MARK: - UI-Bausteine (Nested)

    private struct TrainingHeroCard: View {
        @EnvironmentObject var appSettings: AppSettings
        @Environment(\.designTokens) private var t

        let title: String
        let subtitle: String
        var onStart: () -> Void

        private var todayDateString: String {
            let formatter = DateFormatter()
            let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
            formatter.locale = Locale(identifier: code)
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: Date())
        }

        var body: some View {
            VStack(spacing: Spacing.m) {
                HStack {
                    Text(todayDateString)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }

                Spacer()

                VStack(spacing: Spacing.s) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text(appSettings.localized("home.startTraining"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.xl)
            .frame(height: 220)
            .background(
                LinearGradient(
                    colors: [
                        t.palette.primary.opacity(0.95),
                        t.palette.primary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .minimalShadow()
            .padding(.horizontal, Spacing.m)
        }
    }



    private struct CurrentTrainingCard: View {
        @EnvironmentObject var appSettings: AppSettings
        @Environment(\.designTokens) private var t

        let title: String
        let sinceText: String
        let elapsed: TimeInterval
        let completedSets: Int
        let totalSets: Int
        var onContinue: () -> Void

        private var progress: Double {
            totalSets == 0 ? 0 : Double(completedSets) / Double(totalSets)
        }

        private var metaLine: String {
            let setsLabel = appSettings.localized("history.sets")
            return totalSets == 0
            ? "\(sinceText): \(formatTime(elapsed))"
            : "\(completedSets)/\(totalSets) \(setsLabel) • \(formatTime(elapsed))"
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(t.palette.primary.opacity(0.16))
                            .frame(width: 48, height: 48)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(t.palette.primary)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(appSettings.localized("home.training.inProgress.prefix"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.52))
                            .tracking(0.5)
                        Text(title)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(metaLine)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                            .numericTextTransition()
                    }

                    Spacer()
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.12))
                            .frame(height: 8)

                        Capsule()
                            .fill(t.palette.primary)
                            .frame(width: max(8, geometry.size.width * progress), height: 8)
                            .animation(.easeOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)

                Button(action: onContinue) {
                    Label(appSettings.localized("home.continue"), systemImage: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(t.palette.primary)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                }
            }
            .padding(18)
            .background(.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 10)
        }

        private func formatTime(_ interval: TimeInterval) -> String {
            let m = Int(interval) / 60
            let s = Int(interval) % 60
            return String(format: appSettings.localized("time.mmss"), m, s)
        }
    }

    private struct RecentTrainingCard: View {
        @Environment(\.designTokens) private var t
        @EnvironmentObject var appSettings: AppSettings

        let entry: TrainingEntry
        let accent: Color
        let titleFallback: String
        let exercisesLabel: String
        let setsLabel: String
        let detailsLabel: String
        var titleOverride: String? = nil

        private var titleText: String {
            let t = titleOverride ?? entry.title
            return t.isEmpty ? titleFallback : t
        }
        private var exercisesCount: Int { entry.exercises.count }
        private var setsCount: Int { entry.exercises.reduce(0) { $0 + $1.sets.count } }

        private var isRunningWorkout: Bool {
            if let cardioType = entry.cardioType {
                return cardioType.lowercased().contains("run") || cardioType.lowercased().contains("jog")
            }
            return entry.title.lowercased().contains("run") || entry.title.lowercased().contains("jog")
        }

        private var dateString: String {
            let cal = Calendar.current
            if cal.isDateInToday(entry.date) {
                return appSettings.localized("date.today")
            } else if cal.isDateInYesterday(entry.date) {
                return appSettings.localized("date.yesterday")
            } else {
                let daysDiff = cal.dateComponents([.day], from: entry.date, to: Date()).day ?? 0
                if daysDiff < 7 {
                    return String(format: appSettings.localized("date.daysAgo"), daysDiff)
                }
                let df = DateFormatter()
                df.locale = .current
                df.dateStyle = .medium
                return df.string(from: entry.date)
            }
        }

        var body: some View {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dateString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(titleText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        if isRunningWorkout {
                            let distance = entry.loggedDistanceKm ?? 0
                            let minutes = Int(entry.duration / 60)
                            if distance > 0 {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.1f", distance))
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .numericTextTransition()
                                    Text("km")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                if minutes > 0 {
                                    HStack(spacing: 4) {
                                        Text("\(minutes)")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .numericTextTransition()
                                        Text("min")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else if minutes > 0 {
                                HStack(spacing: 4) {
                                    Text("\(minutes)")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .numericTextTransition()
                                    Text("min")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("—")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Text("\(exercisesCount)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .numericTextTransition()
                                Text(exercisesLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Text("\(setsCount)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .numericTextTransition()
                                Text(setsLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, Spacing.m)
                .padding(.horizontal, Spacing.m)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.s)
                .contentShape(Rectangle())
            }
        }
    }

    private struct HomeRoutineCard: View {
        let template: TrainingTemplate
        let onTap: () -> Void
        let onPin: () -> Void

        @Environment(\.designTokens) private var t
        @EnvironmentObject var appSettings: AppSettings

        private var previewExercises: String {
            template.exercises.prefix(3).joined(separator: " · ")
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [
                            t.palette.primary.opacity(0.70),
                            Color.blue.opacity(0.34),
                            Color.black.opacity(0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 38, height: 38)
                                .background(t.palette.primary)
                                .clipShape(Circle())
                            Spacer()
                            Button(action: onPin) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(.black.opacity(0.24))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Text(template.name)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(
                            String(
                                format: appSettings.localized("templates.exercisesCount"),
                                template.exercises.count
                            )
                        )
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(16)
                }
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )

                Text(previewExercises.isEmpty ? appSettings.localized("templates.favorites.desc") : previewExercises)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Label(appSettings.localized("common.start"), systemImage: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(t.palette.primary)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(16)
            .frame(height: 252)
            .background(.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onTapGesture(perform: onTap)
        }
    }

    private struct CircularMetricBadge: View {
        let progress: Double
        let icon: String
        let tint: Color

        var body: some View {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(tint)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
    }

    private struct SummaryMetric: View {
        let value: String
        let label: String

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }
        }
    }

    private struct HomeMiniMetric: View {
        let title: String
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.48))
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private struct HomeInsightTile: View {
        let title: String
        let value: String
        let icon: String
        let tint: Color
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 38, height: 38)
                        .background(tint.opacity(0.16))
                        .clipShape(Circle())
                    Text(value)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.13), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private struct HomeProgramRow: View {
        let template: TrainingTemplate
        let isDefaultFallback: Bool
        let onTap: () -> Void
        let onStart: () -> Void

        @Environment(\.designTokens) private var t
        @EnvironmentObject var appSettings: AppSettings

        private var previewExercises: String {
            template.exercises.prefix(3).joined(separator: " · ")
        }

        var body: some View {
            HStack(spacing: 14) {
                Button(action: onTap) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [t.palette.primary.opacity(0.75), .cyan.opacity(0.30)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .frame(width: 62, height: 62)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(template.name)
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if isDefaultFallback {
                                    Text("Movo")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(t.palette.primary)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(previewExercises.isEmpty ? appSettings.localized("templates.favorites.desc") : previewExercises)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)

                            Text(String(format: appSettings.localized("templates.exercisesCount"), template.exercises.count))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.44))
                        }

                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(t.palette.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        }
    }

    private struct ProfileAvatarButton: View {
        let customProfileImageData: Data?
        let initials: String?
        var size: CGFloat = 32

        var body: some View {
            Group {
                if let data = customProfileImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    ZStack {
                        Circle().fill(Color(.systemGray5))
                        Text(initials?.prefix(2).uppercased() ?? "")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .contentShape(Circle())
        }
    }

    private struct TemplateCard: View {
        @Environment(\.designTokens) private var t
        let template: TrainingTemplate
        @EnvironmentObject var appSettings: AppSettings

        var onTap: () -> Void

        // Explicit initializer to avoid any shadowing/overload resolution issues
        init(template: TrainingTemplate, onTap: @escaping () -> Void) {
            self.template = template
            self.onTap = onTap
        }

        private var emoji: String? {
            template.name.first?.isEmoji == true ? String(template.name.prefix(1)) : nil
        }

        private var displayTitle: String {
            if let emoji = emoji, template.name.hasPrefix(emoji) {
                return template.name.dropFirst().trimmingCharacters(in: .whitespaces)
            }
            return template.name
        }

        private var gradientColors: [Color] {
            let colors: [[Color]] = [
                [.blue, .purple],
                [.orange, .red],
                [.green, .teal],
                [.pink, .purple],
                [.indigo, .cyan]
            ]
            let index = abs(template.id.hashValue) % colors.count
            return colors[index]
        }

        var body: some View {
            Button(action: onTap) {
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("templatesScroll"))
                    // Parallax: je weiter vom Zentrum, desto stärker die Rotation/Scale
                    let midX = frame.midX
                    let screenMid = UIScreen.main.bounds.midX
                    let diff = (midX - screenMid) / UIScreen.main.bounds.width
                    let clamped = max(-1, min(1, diff))
                    let angle = Angle(degrees: Double(clamped) * 10)
                    let scale = 1.0 - abs(clamped) * 0.08

                    VStack(alignment: .leading, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 40, height: 40)

                            if let emoji = emoji {
                                Text(emoji)
                                    .font(.system(size: 20))
                            } else {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                            }
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayTitle)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Text(
                                String(
                                    format: appSettings.localized("templates.exercisesCount"),
                                    template.exercises.count
                                )
                            )
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                        }

                        HStack {
                            Text(appSettings.localized("common.start"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .frame(width: 160, height: 180)
                    .background(
                        LinearGradient(
                            colors: gradientColors.map { $0.opacity(0.9) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: gradientColors[0].opacity(0.3), radius: 8, x: 0, y: 4)
                    .rotation3DEffect(angle, axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.5, dampingFraction: 0.9), value: clamped)
                }
                .frame(width: 160, height: 180)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Widget Updates
    private func updateWidgetData() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.movo") else { return }

        // 1. Weekly Training Days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        guard let startOfWeek = calendar.date(from: components) else { return }

        let weekDays = (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }

        let trainingDays = weekDays.map { date in
            trainingHistory.contains { entry in
                calendar.isDate(entry.date, inSameDayAs: date)
            }
        }

        userDefaults.set(trainingDays, forKey: "widget.training.days")

        // 2. Steps
        userDefaults.set(healthManager.todaySteps, forKey: "widget.training.steps")
        let stepsGoal = UserDefaults.standard.integer(forKey: "steps.goal")
        userDefaults.set(stepsGoal > 0 ? stepsGoal : 8000, forKey: "widget.training.stepsGoal")

        // 3. Streak
        userDefaults.set(gm.streak, forKey: "widget.training.streak")

        WidgetCenter.shared.reloadTimelines(ofKind: "TrainingWeeklyWidget")
    }
}



// MARK: - Misc Helpers

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji
    }
}

// MARK: - Glass Card: Resume Training

private struct ResumeTrainingGlassCard: View {
    let title: String
    let elapsed: TimeInterval
    var onDismiss: () -> Void
    var onContinue: () -> Void
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title2.weight(.bold))
                Text(appSettings.localized("home.resume.title"))
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Label(formatTime(elapsed), systemImage: "stopwatch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button(role: .destructive, action: onDismiss) {
                    Text(appSettings.localized("home.resume.discard"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button(action: onContinue) {
                    Text(appSettings.localized("home.resume.continue"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(t.palette.primary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.separator, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%dm %02ds", m, s)
    }
}

// MARK: - Stat Grid Card Component

struct StatGridCard: View {
    @Environment(\.designTokens) private var t

    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String?
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                    Spacer()
                }
                .padding(.bottom, 12)

                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
