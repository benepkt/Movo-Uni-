import SwiftUI
import HealthKit
import UIKit
import Charts
import WidgetKit
import FirebaseFirestore

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
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
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

// MARK: - HomeView (ohne Feed, ohne Freunde) + Resume-Popup
struct HomeView: View {
    @Binding var trainingHistory: [TrainingEntry]
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var syncService: SyncService          // ⬅️ NEU
    @Environment(\.designTokens) private var t
    @Environment(\.scenePhase) private var scenePhase

    // 🔹 Avatar wird hier reingecacht (Base64 → Data)
    @AppStorage("profile.imageData") private var profileImageData: Data?

    @StateObject private var healthManager = HealthKitManager()

    @State private var showNewTraining = false
    @State private var showTemplates = false
    @State private var showRunningTraining = false           // ⬅️ NEU
    @State private var showStartMenu = false                 // ⬅️ NEU

    // 🔸 Promo-State: erscheint immer wieder, bis CTA gedrückt wurde
    @AppStorage("betaPromo.seen.v2") private var betaPromoSeen = false
    @State private var showBetaPromo = false

    // ⬇️ Resume-Popup State
    @State private var showResumeCard = false
    @State private var pendingResume: TrainingSessionManager.ResumeSnapshot? = nil

    // zentraler Sheet-Status
    @State private var activeSheet: ActiveSheet? = nil
    enum ActiveSheet: Identifiable { case steps, profile
        var id: String { self == .steps ? "steps" : "profile" }
    }

    // Neu: wirklich die 2 neuesten Trainings
    private var recentEntries: [TrainingEntry] {
        Array(
            trainingHistory
                .sorted { $0.date > $1.date }   // neueste zuerst
                .prefix(2)
        )
    }
    private var templates: [TrainingTemplate] { templateStore.allTemplates }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection()
                    activeTrainingSection()
                    templatesSection()
                    recentSection()
                    Spacer(minLength: 24)
                }
                .padding(.bottom, 8)
                .background(navigationLinks())
            }
            .navigationTitle("Movo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { activeSheet = .profile } label: {
                        ProfileAvatarButton(customProfileImageData: profileImageData, initials: initialsFromUser())
                    }
                    .accessibilityLabel(appSettings.localized("profile.title"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { activeSheet = .steps } label: {
                        StepCounterView(healthManager: healthManager)
                    }
                }
            }
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
                }
            }
            // ⬇️ Start-Menü Sheet
            .sheet(isPresented: $showStartMenu) {
                TrainingStartMenu { type in
                    switch type {
                    case .strength:
                        showNewTraining = true
                    case .running:
                        showRunningTraining = true
                    }
                }
                .presentationDetents([.fraction(0.34)])
                .presentationDragIndicator(.hidden)
            }
            .onAppear {
                Task {
                    await prefetchAvatarIntoAppStorage()
                    healthManager.refreshAll()
                }
                // Resume prüfen bei Kaltstart
                if !sessionManager.isTrainingActive,
                   let snap = sessionManager.loadResumeSnapshot() {
                    pendingResume = snap
                    withAnimation(.spring()) { showResumeCard = true }
                }
                // ⬅️ Overlay nur zeigen, wenn NICHT freigeschaltet und noch nicht per CTA bestätigt
                if !purchaseManager.hasUnlockedStatistics && !betaPromoSeen {
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
            // ⬇️ Szene-Änderungen: Snapshot sichern / wieder anbieten
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .inactive, .background:
                    sessionManager.persistSnapshotIfNeeded()
                case .active:
                    if !sessionManager.isTrainingActive,
                       let snap = sessionManager.loadResumeSnapshot() {
                        pendingResume = snap
                        withAnimation(.spring()) { showResumeCard = true }
                    }
                default:
                    break
                }
            }
        }
        // === Overlay: Resume-Glass-Card ======================================
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
                        // direkt in den Trainingsscreen (Kraft)
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

    // MARK: - Sections
    @ViewBuilder private func heroSection() -> some View {
        TrainingHeroCard(
            title: appSettings.localized("home.title"),
            subtitle: appSettings.localized("home.today"),
            onStart: { showStartMenu = true }        // ⬅️ statt direkt showNewTraining
        )
        .padding(.top, 16)
    }

    @ViewBuilder private func activeTrainingSection() -> some View {
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
        }
    }

    @ViewBuilder private func templatesSection() -> some View {
        if !templates.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    Text(appSettings.localized("templates.title")).font(.title3).bold()
                    Spacer()
                    Button(appSettings.localized("common.viewAll")) { showTemplates = true }
                        .foregroundStyle(t.palette.primary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(templates, id: \.id) { tpl in
                            TemplateChip(title: tpl.name) {
                                sessionManager.startTraining(from: tpl)
                                showNewTraining = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    @ViewBuilder private func recentSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appSettings.localized("home.recentTrainings"))
                .font(.title3).bold()
                .padding(.horizontal)
            if recentEntries.isEmpty {
                Text(appSettings.localized("home.recentTrainingsPlaceholder"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .appElevatedCard()
                    .padding(.horizontal)
            } else {
                VStack(spacing: 14) {
                    ForEach(recentEntries, id: \.id) { entry in
                        NavigationLink {
                            detailDestination(for: entry)
                        } label: {
                            RecentTrainingCard(
                                entry: entry,
                                accent: t.palette.primary,
                                titleFallback: appSettings.localized("training.training"),
                                exercisesLabel: appSettings.localized("history.exercises"),
                                setsLabel: appSettings.localized("history.sets"),
                                detailsLabel: appSettings.localized("home.viewDetails"),
                                titleOverride: prettifiedTitle(for: entry.title)
                            )
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private func detailDestination(for entry: TrainingEntry) -> some View {
        TrainingDetailView(training: entry)
            .environmentObject(appSettings)
            .environmentObject(trainingStore)
    }

    @ViewBuilder private func navigationLinks() -> some View {
        ZStack {
            NavigationLink(isActive: $showNewTraining) {
                NewTrainingView()
                    .environmentObject(sessionManager)
                    .environmentObject(appSettings)
                    .environmentObject(exerciseLibrary)
                    .environmentObject(trainingStore)
                    .environmentObject(gm)
                    .environmentObject(authService)
                    .environmentObject(syncService)
                    .environmentObject(purchaseManager)
            } label: { EmptyView() }

            NavigationLink(isActive: $showRunningTraining) {         // ⬅️ NEU
                RunningTrainingView()
                    .environmentObject(trainingStore)
                    .environmentObject(gm)
                    .environmentObject(syncService)
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
    private func totalSets() -> Int { sessionManager.exercises.reduce(0) { $0 + $1.sets.count } }
    private func completedSets() -> Int {
        sessionManager.exercises.reduce(0) { $0 + $1.sets.filter { $0.isCompleted }.count }
    }
}

// MARK: - Schritte Panel (voll lokalisiert + App-Locale)
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

    // 👉 erzwinge App-gewählte Sprache für Datum/Charts
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
            ScrollView {
                VStack(spacing: 18) {
                    // HEADER
                    HStack(spacing: 16) {
                        ZStack {
                            HomeProgressRing(progress: progressToday, color: t.palette.primary, lineWidth: 10)
                                .frame(width: 82, height: 82)
                            Image(systemName: "figure.walk")
                                .resizable().scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundStyle(t.palette.primary)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appSettings.localized("steps.unit"))
                                .font(.headline).foregroundStyle(.white)
                            Text("\(healthManager.todaySteps) / \(goal)")
                                .font(.title3.bold()).foregroundStyle(.white)
                            ProgressView(value: min(Double(healthManager.todaySteps), Double(goal)),
                                         total: Double(goal))
                                .tint(.white)
                        }
                        Spacer()
                    }
                    .appHeroCard()
                    .padding(.horizontal)

                    // Zeitraum
                    Picker("", selection: $daysBack) {
                        Text("7 \(appSettings.localized("days"))").tag(7)
                        Text("14 \(appSettings.localized("days"))").tag(14)
                        Text("30 \(appSettings.localized("days"))").tag(30)
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
                                    .font(.footnote).foregroundStyle(.secondary)
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
                                    AxisMarks(values: .stride(by: .day)) {
                                        AxisGridLine(); AxisTick()
                                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                    }
                                }
                                .environment(\.locale, appLocale)
                            }
                        } else {
                            Text(appSettings.localized("common.ios16.required"))
                                .font(.footnote).foregroundStyle(.secondary)
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
                            Text("\(goal)").monospacedDigit().font(.subheadline)
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal)

                    // Tage-Liste
                    sectionCard(title: appSettings.localized("steps.list.title"), icon: "list.bullet") {
                        if days.isEmpty {
                            Text(appSettings.localized("steps.noData"))
                                .font(.footnote).foregroundStyle(.secondary)
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
            .navigationTitle(appSettings.localized("steps.title"))
            .navigationBarTitleDisplayMode(.inline)
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
    }

    // MARK: - Subviews
    private func num(_ v: Int, locale: Locale) -> String {
        v.formatted(.number.locale(locale).grouping(.automatic))
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(.primary)
                Text(title).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 2)
            content()
        }
        .appElevatedCard()
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
        }
        .frame(maxWidth: .infinity)
        .appElevatedCard()
    }

    // MARK: - HealthKit + Helpers
    private func ensureAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        do { try await store.requestAuthorization(toShare: [], read: [stepType]); isAuthorized = true }
        catch { isAuthorized = false }
    }

    private func reload() async {
        guard isAuthorized else { days = []; return }
        let now = Date()
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -(daysBack - 1), to: cal.startOfDay(for: now)) else {
            days = []; return
        }
        await fetchSteps(from: start, to: now) { result in
            DispatchQueue.main.async {
                self.days = result
                self.csvURL = makeCSV(from: result)
                let compact = result.map { StepsDayCompact(d: Calendar.current.startOfDay(for: $0.date), s: $0.steps) }
                StepsShared.saveHistory(days: compact, goal: goal)
                WidgetCenter.shared.reloadTimelines(ofKind: "StepsWeeklyWidget")
            }
        }
    }

    private func fetchSteps(from start: Date, to end: Date, completion: @escaping ([DaySteps]) -> Void) async {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: Date())
        var interval = DateComponents(); interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType, quantitySamplePredicate: nil,
            options: .cumulativeSum, anchorDate: anchor, intervalComponents: interval
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
        do { try csv.data(using: .utf8)?.write(to: url); return url } catch { return nil }
    }

    private func isoDate(_ d: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; return f.string(from: d)
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

// MARK: - UI-Bausteine
private struct TrainingHeroCard: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t

    let title: String
    let subtitle: String
    var onStart: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            ViewThatFits(in: .horizontal) {
                wideHero.padding(18)
                narrowHero.padding(18)
            }
        }
        .frame(height: 120)
        .appHeroCard()
        .padding(.horizontal)
    }

    private var wideHero: some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold()).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.75)
                Text(subtitle).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button(action: onStart) {
                Label(appSettings.localized("home.startTraining"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
            }
            .foregroundStyle(.white)
        }
    }

    private var narrowHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold()).foregroundStyle(.white)
                        .lineLimit(2).minimumScaleFactor(0.75)
                    Text(subtitle).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            Button(action: onStart) {
                Label(appSettings.localized("home.startTraining"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
            }
            .foregroundStyle(.white)
        }
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

    private var progress: Double { totalSets == 0 ? 0 : Double(completedSets) / Double(totalSets) }
    private var metaLine: String {
        let setsLabel = appSettings.localized("history.sets")
        return "\(completedSets)/\(totalSets) \(setsLabel) • \(sinceText): \(formatTime(elapsed))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    HomeProgressRing(progress: progress, color: t.palette.primary)
                        .frame(width: 58, height: 58)
                    Text("\(Int(progress * 100))%").font(.caption2.bold()).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                    Text(metaLine).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }

            Button(action: onContinue) {
                Text(appSettings.localized("home.continue"))
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(t.palette.primary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .appElevatedCard()
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return "\(m)m \(s)s"
    }
}

private struct RecentTrainingCard: View {
    @Environment(\.designTokens) private var t

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
    private var dateString: String {
        let df = DateFormatter(); df.locale = .current; df.dateStyle = .medium
        return df.string(from: entry.date)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                HomeProgressRing(progress: 1.0, color: accent)
                    .frame(width: 46, height: 46)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text("\(dateString) • \(exercisesCount) \(exercisesLabel) • \(setsCount) \(setsLabel)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(detailsLabel)
                    .font(.caption)
                    .foregroundStyle(t.palette.primary)
                    .padding(.top, 2)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.footnote)
        }
        .appElevatedCard()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                        .font(.caption).fontWeight(.semibold).foregroundColor(.primary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .contentShape(Circle())
    }
}

private struct TemplateChip: View {
    @Environment(\.designTokens) private var t
    let title: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(t.palette.primary.opacity(0.14)))
                .overlay(Capsule().stroke(t.palette.outline, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Glass Card: Resume Training
private struct ResumeTrainingGlassCard: View {
    let title: String
    let elapsed: TimeInterval
    var onDismiss: () -> Void
    var onContinue: () -> Void
    @Environment(\.designTokens) private var t

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title2.weight(.bold))
                Text("Training fortsetzen?")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Label(formatTime(elapsed), systemImage: "stopwatch")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button(role: .destructive, action: onDismiss) {
                    Text("Verwerfen").frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button(action: onContinue) {
                    Text("Fortsetzen").frame(maxWidth: .infinity).padding(.vertical, 10)
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
