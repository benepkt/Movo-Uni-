import SwiftUI
import ActivityKit
import UniformTypeIdentifiers
import WidgetKit
import Combine
import UserNotifications
import FirebaseAuth
import HealthKit
import CoreLocation
import AudioToolbox
// ⛔️ Kein Firestore-Write aus diesem View

// MARK: - Adaptive surfaces (global nutzbar)
extension Color {
    static var dsFieldBG: Color { Color(uiColor: .secondarySystemBackground) }
    static var dsChipBG:  Color { Color(uiColor: .tertiarySystemBackground) }
    static var dsOutline: Color { Color(uiColor: .separator) }
}

struct DSFieldModifier: ViewModifier {
    let corner: CGFloat
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: corner).fill(Color.dsFieldBG))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Color.dsOutline, lineWidth: 0.5))
    }
}

struct DSChipModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Capsule().fill(Color.dsChipBG))
            .overlay(Capsule().stroke(Color.dsOutline, lineWidth: 0.5))
    }
}

extension View {
    func dsField(corner: CGFloat = 12) -> some View { modifier(DSFieldModifier(corner: corner)) }
    func dsChip() -> some View { modifier(DSChipModifier()) }
}

// ✅ Modell für das Popup
struct RewardMessage {
    let text: String
    let icon: String
    let color: Color
    let level: Int?
    let nextLevel: Int?
    let xpToNextLevel: Int?
    let progress: Double?

    init(
        text: String,
        icon: String,
        color: Color,
        level: Int? = nil,
        nextLevel: Int? = nil,
        xpToNextLevel: Int? = nil,
        progress: Double? = nil
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.level = level
        self.nextLevel = nextLevel
        self.xpToNextLevel = xpToNextLevel
        self.progress = progress
    }
}

// MARK: - RewardPopup moved to top-level (so modifiers can see it)
struct RewardPopup: View {
    let text: String
    let icon: String
    let color: Color
    var level: Int? = nil
    var nextLevel: Int? = nil
    var xpToNextLevel: Int? = nil
    var progress: Double? = nil
    @Environment(\.designTokens) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(text)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.primary)
                    if let xpToNextLevel, let nextLevel {
                        Text("\(xpToNextLevel) XP bis Level \(nextLevel)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            if let progress, let level, let nextLevel {
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.10))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [color, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * min(max(progress, 0), 1)))
                        }
                    }
                    .frame(height: 11)

                    HStack {
                        Text("Lvl \(level)")
                        Spacer()
                        Text("Lvl \(nextLevel)")
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [t.palette.surfaceA, t.palette.surfaceB],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(t.palette.outline, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        .padding()
    }
}

private struct ActivitySummaryView: View {
    let entry: TrainingEntry
    let onDone: () -> Void

    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [t.palette.primary.opacity(0.36), Color.blue.opacity(0.14), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 430
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(entry.emoji ?? "🔥")
                    .font(.system(size: 54))

                VStack(spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(isDE ? "Aktivität gespeichert" : "Activity saved")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metric(title: isDE ? "Dauer" : "Duration", value: durationText, icon: "timer")
                    if let distance = entry.loggedDistanceKm, distance > 0 {
                        metric(title: isDE ? "Distanz" : "Distance", value: String(format: "%.2f km", distance), icon: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                    if let calories = entry.activeCalories {
                        metric(title: isDE ? "Kalorien" : "Calories", value: "\(Int(calories.rounded())) kcal", icon: "flame.fill")
                    }
                    if let hr = entry.averageHeartRate {
                        metric(title: isDE ? "Ø Puls" : "Avg HR", value: "\(Int(hr.rounded())) bpm", icon: "heart.fill")
                    }
                    if let effort = entry.perceivedEffort {
                        metric(title: isDE ? "Anstrengung" : "Effort", value: "\(effort)/10", icon: "gauge.with.dots.needle.67percent")
                    }
                    if let elevation = entry.elevationGainM {
                        metric(title: isDE ? "Höhe" : "Elevation", value: "\(Int(elevation.rounded())) m", icon: "mountain.2.fill")
                    }
                }

                if let note = entry.activityNote, !note.isEmpty {
                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                }

                Button(action: onDone) {
                    Text(appSettings.localized("settings.done"))
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(t.palette.primary))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .preferredColorScheme(.dark)
    }

    private var durationText: String {
        let minutes = Int(entry.duration / 60)
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(t.palette.primary)
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - NewTrainingView (Kraft – nur lokal speichern)

struct NewTrainingView: View {
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService

    @EnvironmentObject var healthKit: HealthKitManager

    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t

    @State private var date = Date()
    @State private var entryMode: TrainingEntryMode = .strength
    @State private var selectedActivityKind: ActivityEntryKind = .running
    @State private var activityDistanceText = ""
    @State private var activityDurationMinutesText = "30"
    @State private var activityResistanceText = ""
    @State private var activityInclineText = ""
    @State private var activityWattsText = ""
    @State private var activityCaloriesText = ""
    @State private var activityHeartRateText = ""
    @State private var activityElevationText = ""
    @State private var perceivedEffort: Int = 5
    @State private var showActivityDropdown = false
    @State private var activityNotes = ""
    @State private var showStrengthActivityForm = false
    @State private var embeddedActivities: [WorkoutActivityBlock] = []
    @State private var editingActivityID: UUID? = nil
    @State private var activityCaptureMode: ActivityCaptureMode = .live
    @State private var rewardMessage: RewardMessage? = nil
    @State private var showExercisePicker = false
    @State private var exerciseSearchText = ""
    @State private var lastSetSuggestionCache: [String: (kg: Double, reps: Int, date: Date)] = [:]
    @FocusState private var focusedField: UUID?
    @FocusState private var titleFocused: Bool
    @State private var activityTimer: Timer?
    @State private var liveActivityActive = false
    @State private var watchWorkoutId: String = UUID().uuidString
    private var canUseLiveActivity: Bool { true }

    // 🔔 Pausen-Timer
    @State private var showPauseTimer = false
    @StateObject private var pauseTimer = PauseTimer() // FIX: use model, not sheet view
    @State private var pauseSheetDetent: PresentationDetent = .fraction(0.6)
    @State private var lastCompletedSetCount = 0
    @State private var lastWatchRestTimerPushAt: Date = .distantPast
    @AppStorage("restTimer.automaticSeconds") private var automaticRestSeconds: Double = 120

    // 🔁 Einheiten-Auswahl (kg/lb)
    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg

    // 🔒 Sichtbarkeit (merken; für späteres manuelles Publish/Push)
    @AppStorage("training.visibility.default") private var defaultVisibilityRaw: String = "public"
    @State private var visibility: Visibility = .public
    private enum Visibility: String, CaseIterable {
        case `public`, `private`
        var icon: String { self == .public ? "lock.open.fill" : "lock.fill" }
        var label: String { self == .public ? "Öffentlich" : "Privat" }
    }

    // ❌ Cancel / Summary
    @State private var showCancelConfirm = false
    @State private var showSummary = false
    @State private var lastSavedEntry: TrainingEntry?
    
    // 👉 Übungsinfo für Detail-Sheet
    @State private var selectedExerciseInfo: ExerciseInfo?

    // 🎉 Streak-Daten für Summary
    @State private var summaryStreakWeeks: Int? = nil
    @State private var summaryWeekProgress: [Bool] = Array(repeating: false, count: 7)
    @State private var summaryPersonalRecords: [WorkoutPersonalRecord] = []

    // Minimieren-Status, um Live Activity nicht zu beenden
    @State private var isMinimized = false

    // ✅ Animations (fix: ambig spring)
    private let reorderSpring = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0)
    private let rewardSpring  = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.9,  blendDuration: 0)

    private enum TrainingEntryMode: String, CaseIterable {
        case strength, activity
    }

    private enum ActivityCaptureMode: String, CaseIterable {
        case live, manual
    }

    private enum ActivityEntryKind: String, CaseIterable, Identifiable {
        case running, walking, cycling, hiking, swimming, rowing, elliptical, stairStepper, hiit, crossTraining, functionalTraining, yoga, pilates, mobility, stretching, dance, boxing, martialArts, climbing, soccer, basketball, tennis, volleyball, golf, skiing, snowboarding, skating, jumpRope, core, cooldown
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .running: return "figure.run"
            case .walking: return "figure.walk"
            case .cycling: return "figure.outdoor.cycle"
            case .hiking: return "figure.hiking"
            case .swimming: return "figure.pool.swim"
            case .rowing: return "figure.rower"
            case .elliptical: return "figure.elliptical"
            case .stairStepper: return "figure.stair.stepper"
            case .hiit: return "flame.fill"
            case .crossTraining: return "figure.cross.training"
            case .functionalTraining: return "figure.strengthtraining.functional"
            case .yoga: return "figure.yoga"
            case .pilates: return "figure.flexibility"
            case .mobility: return "figure.cooldown"
            case .stretching: return "figure.flexibility"
            case .dance: return "figure.dance"
            case .boxing: return "figure.boxing"
            case .martialArts: return "figure.martial.arts"
            case .climbing: return "figure.climbing"
            case .soccer: return "soccerball"
            case .basketball: return "basketball.fill"
            case .tennis: return "tennis.racket"
            case .volleyball: return "volleyball.fill"
            case .golf: return "figure.golf"
            case .skiing: return "figure.skiing.downhill"
            case .snowboarding: return "figure.snowboarding"
            case .skating: return "figure.skating"
            case .jumpRope: return "figure.jumprope"
            case .core: return "figure.core.training"
            case .cooldown: return "figure.cooldown"
            }
        }

        var tint: Color {
            switch self {
            case .running: return .blue
            case .walking: return .mint
            case .cycling: return .cyan
            case .hiking: return .green
            case .swimming: return .teal
            case .rowing: return .indigo
            case .elliptical: return .purple
            case .stairStepper: return .blue
            case .hiit: return .orange
            case .crossTraining: return .mint
            case .functionalTraining: return .green
            case .yoga: return .pink
            case .pilates: return .purple
            case .mobility: return .indigo
            case .stretching: return .teal
            case .dance: return .pink
            case .boxing: return .red
            case .martialArts: return .orange
            case .climbing: return .brown
            case .soccer: return .green
            case .basketball: return .orange
            case .tennis: return .yellow
            case .volleyball: return .cyan
            case .golf: return .green
            case .skiing: return .cyan
            case .snowboarding: return .indigo
            case .skating: return .blue
            case .jumpRope: return .orange
            case .core: return .purple
            case .cooldown: return .mint
            }
        }

        var emoji: String {
            switch self {
            case .running: return "🏃‍♂️"
            case .walking: return "🚶"
            case .cycling: return "🚴"
            case .hiking: return "🥾"
            case .swimming: return "🏊"
            case .rowing: return "🚣"
            case .elliptical: return "💪"
            case .stairStepper: return "🪜"
            case .hiit: return "🔥"
            case .crossTraining, .functionalTraining: return "🏋️‍♂️"
            case .yoga, .pilates, .mobility: return "🧘‍♂️"
            case .stretching, .cooldown: return "🧘‍♂️"
            case .dance: return "💃"
            case .boxing, .martialArts: return "🥊"
            case .climbing: return "🧗"
            case .soccer: return "⚽️"
            case .basketball: return "🏀"
            case .tennis: return "🎾"
            case .volleyball: return "🏐"
            case .golf: return "⛳️"
            case .skiing: return "⛷️"
            case .snowboarding: return "🏂"
            case .skating: return "⛸️"
            case .jumpRope: return "🔥"
            case .core: return "💪"
            }
        }

        func title(isDE: Bool) -> String {
            switch self {
            case .running: return isDE ? "Laufen" : "Running"
            case .walking: return isDE ? "Gehen" : "Walking"
            case .cycling: return isDE ? "Radfahren" : "Cycling"
            case .hiking: return isDE ? "Wandern" : "Hiking"
            case .swimming: return isDE ? "Schwimmen" : "Swimming"
            case .rowing: return isDE ? "Rudern" : "Rowing"
            case .elliptical: return isDE ? "Crosstrainer" : "Elliptical"
            case .stairStepper: return isDE ? "Stepper" : "Stair Stepper"
            case .hiit: return "HIIT"
            case .crossTraining: return isDE ? "Cross Training" : "Cross Training"
            case .functionalTraining: return isDE ? "Functional Training" : "Functional Training"
            case .yoga: return "Yoga"
            case .pilates: return "Pilates"
            case .mobility: return "Mobility"
            case .stretching: return isDE ? "Dehnen" : "Stretching"
            case .dance: return isDE ? "Tanzen" : "Dance"
            case .boxing: return isDE ? "Boxen" : "Boxing"
            case .martialArts: return isDE ? "Kampfsport" : "Martial Arts"
            case .climbing: return isDE ? "Klettern" : "Climbing"
            case .soccer: return isDE ? "Fußball" : "Soccer"
            case .basketball: return "Basketball"
            case .tennis: return "Tennis"
            case .volleyball: return "Volleyball"
            case .golf: return "Golf"
            case .skiing: return isDE ? "Ski" : "Skiing"
            case .snowboarding: return "Snowboarding"
            case .skating: return isDE ? "Skating" : "Skating"
            case .jumpRope: return isDE ? "Seilspringen" : "Jump Rope"
            case .core: return isDE ? "Core" : "Core"
            case .cooldown: return "Cooldown"
            }
        }
    }

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    // MARK: - Header
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isDE ? "Krafttraining" : "Strength training")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(isDE ? "Übungen und Gym-Geräte in einer Session tracken." : "Track exercises and gym machines in one session.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
            }

            TextField(appSettings.localized("training.title.placeholder"),
                      text: $sessionManager.trainingTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                .focused($titleFocused)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    dateChip
                    timeChip
                    Spacer(minLength: 8)
                    pauseKnobChip
                    heartRateChip
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        dateChip
                        timeChip
                    }
                    HStack(spacing: 10) {
                        pauseKnobChip
                        heartRateChip
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var modeSelector: some View {
        HStack(spacing: 8) {
            modeButton(.strength, title: isDE ? "Kraft" : "Strength", icon: "dumbbell.fill")
            modeButton(.activity, title: isDE ? "Aktivitäten" : "Activities", icon: "figure.run")
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func modeButton(_ mode: TrainingEntryMode, title: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                entryMode = mode
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(entryMode == mode ? .black : .white.opacity(0.64))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(entryMode == mode ? t.palette.primary : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // Chips
    private let chipHeight: CGFloat = 36

    // 🔤 Draft-Buffer für Gewichts-Text (Dezimal-Fix)
    @State private var weightDraft: [UUID: String] = [:]
    @State private var lastFocusedField: UUID? = nil

    // Filter für Übungen (Picker)
    private var filteredExercises: [ExerciseInfo] {
        exerciseSearchText.isEmpty
        ? exerciseLibrary.exercises
        : exerciseLibrary.exercises.filter { $0.name.localizedCaseInsensitiveContains(exerciseSearchText) }
    }

    // ⌚️ Nur-Watch-Update-Timer (wenn kein Premium)
    @State private var watchUpdateTimer: Timer?

    // 👉 NEU: HR-Info/Detail Overlays
    @State private var showHRInfo = false
    @State private var showHRDetail = false

    // MARK: - Recent Exercises (aus History, jüngste zuerst, eindeutig, limitiert)
    private var recentExerciseNames: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for entry in trainingStore.history.sorted(by: { $0.date > $1.date }) {
            for ex in entry.exercises {
                if !seen.contains(ex.name) {
                    seen.insert(ex.name)
                    out.append(ex.name)
                    if out.count >= 8 { return out }
                }
            }
        }
        return out
    }

    // MARK: - Body (refactored to help the compiler)
    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarBackButtonHidden(true)
                .toolbar { keyboardToolbar }
        }
        .modifier(LifecycleHandlersModifier(onAppear: handleOnAppear,
                                           onDisappear: handleOnDisappear))

        .onChange(of: visibility) { newVal in
            defaultVisibilityRaw = newVal.rawValue
        }
        .onChange(of: focusedField) { newFocus in
            if let prev = lastFocusedField, prev != newFocus {
                commitWeight(for: prev)
                weightDraft[prev] = nil
            }
            lastFocusedField = newFocus
        }
        .onChange(of: sessionManager.trainingTitle) { _ in
            pushActiveWorkoutToWatchIfNeeded()
        }
        .onChange(of: sessionManager.exercises.count) { _ in
            pushActiveWorkoutToWatchIfNeeded()
        }
        .onChange(of: totalSetCount) { _ in
            pushActiveWorkoutToWatchIfNeeded()
        }
        .onChange(of: completedSetCount) { newValue in
            guard newValue > lastCompletedSetCount else {
                lastCompletedSetCount = newValue
                return
            }
            lastCompletedSetCount = newValue
            startAutomaticRestTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCompleteSet)) { _ in
            startAutomaticRestTimer()
        }
        .onReceive(pauseTimer.$remaining) { _ in
            pushRestTimerToWatchIfNeeded()
        }
        .onChange(of: embeddedActivities) { activities in
            sessionManager.activities = activities
            sessionManager.persistSnapshotIfNeeded()
        }
        .onReceive(trainingStore.$history) { _ in
            rebuildLastSetSuggestionCache()
        }
        .modifier(exercisePickerSheetModifier)
        .modifier(pauseTimerSheetModifier)
        .modifier(exerciseDetailSheetModifier)
        .modifier(overlaysAlertsSummaryModifier)
        // 👉 NEU: HR Info Sheet (Details werden direkt darin als Sheet präsentiert)
        .sheet(isPresented: $showHRInfo) {
            HeartRateInfoSheet(
                bpm: healthKit.currentHeartRate.map { Int($0) },
                isMonitoring: healthKit.isHeartRateMonitoringActive,
                onStart: {
                    Task {
                        if let type = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                            await healthKit.requestReadAuthorizationIfNeeded(readTypes: [type], forcePrompt: true)
                            // AirPods/andere Quellen erlauben → nicht auf Watch filtern
                            healthKit.startHeartRateStreaming(filterToAppleWatch: false)
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStrengthActivityForm) {
            NavigationStack {
                ZStack {
                    trainingBackground
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(editingActivityID == nil
                                 ? (isDE ? "Gym-Gerät hinzufügen" : "Add gym machine")
                                 : (isDE ? "Gym-Gerät bearbeiten" : "Edit gym machine"))
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(isDE ? "Wird wie eine Übung in diesem Training gespeichert." : "Saved like an exercise inside this workout.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.56))
                            activityTypePicker
                            activityFields
                            Button {
                                saveEmbeddedActivityDraft()
                            } label: {
                                Label(editingActivityID == nil
                                      ? (isDE ? "Zum Training hinzufügen" : "Add to workout")
                                      : (isDE ? "Änderungen speichern" : "Save changes"),
                                      systemImage: "checkmark.circle.fill")
                                    .font(.headline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(.black)
                                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(t.palette.primary))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                    }
                }
                .preferredColorScheme(.dark)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(appSettings.localized("common.cancel")) {
                            clearActivityDraft()
                            showStrengthActivityForm = false
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
        }
        .watchPushOnAppear(
            elapsed: sessionManager.elapsedTime,
            completed: countCompletedExercises(),
            totalKg: calculateTotalWeight(),
            unitRaw: weightUnit.rawValue
        )
    }


    // MARK: - Split view pieces

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topLeftControls
                headerView
                addExerciseButton
                exerciseList
                gymActivitiesList
                discardTrainingButton
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .onTapGesture { hideKeyboard() }
        }
    }

    // Type-erased, grouped content to reduce inference complexity
    private var mainContent: some View {
        AnyView(
            ZStack {
                trainingBackground
                contentScroll
            }
                .modifier(ApplyBottomInset(height: 100))
                .scrollDismissesKeyboard(.interactively)
                .preferredColorScheme(.dark)
        )
    }

    private var trainingBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [t.palette.primary.opacity(0.36), Color.blue.opacity(0.15), .clear],
                center: .topLeading,
                startRadius: 24,
                endRadius: 460
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color.cyan.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    
    // MARK: - Small helpers to keep `body` lightweight

    private var totalSetCount: Int {
        sessionManager.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var completedSetCount: Int {
        sessionManager.exercises.reduce(0) { partial, exercise in
            partial + exercise.sets.filter(\.isCompleted).count
        }
    }

    private func pushActiveWorkoutToWatchIfNeeded() {
        guard sessionManager.isTrainingActive else { return }
        PhoneConnectivity.shared.pushActiveWorkoutState(buildActiveWorkoutPayloadForWatch())
    }

    private func pushRestTimerToWatchIfNeeded() {
        guard sessionManager.isTrainingActive else { return }
        guard pauseTimer.state == .running || pauseTimer.state == .paused else { return }
        let now = Date()
        guard now.timeIntervalSince(lastWatchRestTimerPushAt) >= 1 else { return }
        lastWatchRestTimerPushAt = now
        PhoneConnectivity.shared.pushActiveWorkoutState(buildActiveWorkoutPayloadForWatch())
    }

    private func openDetailFromPicker(info: ExerciseInfo) {
        showExercisePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedExerciseInfo = info
        }
    }

    private var exercisePickerSheetModifier: ExercisePickerSheetModifier {
        ExercisePickerSheetModifier(
            isPresented: $showExercisePicker,
            searchText: $exerciseSearchText,
            filteredExercises: filteredExercises,
            recentNames: recentExerciseNames,
            onSelectName: { name in
                sessionManager.addExercise(name)
                showExercisePicker = false
                exerciseSearchText = ""
            },
            onInfo: { info in
                openDetailFromPicker(info: info)
            },
            onCreate: { query in
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                exerciseLibrary.addExercise(trimmed)
                sessionManager.addExercise(trimmed)
                showExercisePicker = false
                exerciseSearchText = ""
            },
            onAddActivity: {
                showExercisePicker = false
                exerciseSearchText = ""
                clearActivityDraft()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    showStrengthActivityForm = true
                }
            },
            onCancel: {
                showExercisePicker = false
                exerciseSearchText = ""
            },
            navTitle: appSettings.localized("training.addExercise") ?? "Übung hinzufügen",
            cancelTitle: appSettings.localized("common.cancel") ?? "Abbrechen",
            searchPlaceholder: appSettings.localized("common.search") ?? "Suchen",
            recentTitle: appSettings.language.hasPrefix("de") ? "Zuletzt genutzt" : "Recently used",
            addNewPrefix: appSettings.language.hasPrefix("de") ? "Neue Übung hinzufügen" : "Add new exercise"
        )
    }

    private var pauseTimerSheetModifier: PauseTimerSheetModifierWrap {
        PauseTimerSheetModifierWrap(
            isPresented: $showPauseTimer,
            detent: $pauseSheetDetent,
            timer: pauseTimer,
            automaticRestSeconds: $automaticRestSeconds
        )
    }

    private var exerciseDetailSheetModifier: ExerciseDetailSheetModifier {
        ExerciseDetailSheetModifier(
            selectedExerciseInfo: $selectedExerciseInfo,
            trainingStore: trainingStore
        )
    }

    private var overlaysAlertsSummaryModifier: OverlaysAlertsSummaryModifier<AnyView> {
        OverlaysAlertsSummaryModifier(
            rewardMessage: $rewardMessage,
            showCancelConfirm: $showCancelConfirm,
            cancelAction: { cancelWithoutSaving() },
            doneTitle: appSettings.localized("settings.done") ?? "Fertig",
            cancelTitle: appSettings.localized("training.cancel") ?? "Abbrechen",
            discardMessage: appSettings.localized("training.discardConfirm") ?? "Training verwerfen?",
            showSummary: $showSummary,
            lastSavedEntry: $lastSavedEntry,
            summaryView: { entry, dismissAction in
                AnyView(summaryView(entry: entry, dismissAction: dismissAction))
            }
        )
    }


// MARK: - Keyboard toolbar
    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(appSettings.localized("settings.done")) {
                if let id = focusedField {
                    commitWeight(for: id)
                    weightDraft[id] = nil
                }
                focusedField = nil
                titleFocused = false
                hideKeyboard()
            }
            .tint(t.palette.primary)
        }
    }

    // MARK: - Summary view builder
    @ViewBuilder
    private func summaryView(entry: TrainingEntry, dismissAction: @escaping () -> Void) -> some View {
        if entry.exercises.isEmpty, entry.cardioType != nil {
            ActivitySummaryView(entry: entry, onDone: {
                showSummary = false
                dismiss()
            })
            .environmentObject(appSettings)
        } else {
            WorkoutSummaryView(
                entry: entry,
                streakWeeks: summaryStreakWeeks,
                weekProgress: summaryWeekProgress,
                personalRecords: summaryPersonalRecords
            ) {
                showSummary = false
                dismiss()
            }
        }
    }

    // MARK: - Top Controls
    private var topLeftControls: some View {
        HStack {
            Button(action: { minimizeToHome() }) {
                Label(isDE ? "Zurück" : "Back", systemImage: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appSettings.localized("common.back") ?? "Zurück")

            Spacer()

            Button(action: { save() }) {
                Label(isDE ? "Speichern" : "Save", systemImage: "tray.and.arrow.down.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 40)
                    .background(Capsule().fill(t.palette.primary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appSettings.localized("training.save"))
        }
        .padding(.horizontal, 0)
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header Chips
    private var dateChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar").foregroundStyle(t.palette.primary)
            DatePicker("", selection: $date, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
                .controlSize(.small)
                .tint(t.palette.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: chipHeight)
        .background(Capsule().fill(.white.opacity(0.09)))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var timeChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "stopwatch")
                .foregroundStyle(t.palette.primary)
            Text(formatTime(sessionManager.elapsedTime))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 110)
        .frame(height: chipHeight)
        .background(Capsule().fill(.white.opacity(0.09)))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var pauseKnobChip: some View {
        PauseKnob(
            progress: pauseTimer.progress,
            remaining: pauseTimer.remaining,
            action: { showPauseTimer = true }
        )
        .frame(height: chipHeight)
    }

    private var heartRateChip: some View {
        // optional: wenn du es nur für Pro anzeigen willst, lass diese Guard drin


        let hr = healthKit.currentHeartRate
        let text = hr == nil ? "—" : "\(Int(hr!))"

        return AnyView(
            Button {
                showHRInfo = true
            } label: {
                HStack(spacing: 6) {
                    Text(text)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(height: chipHeight)
                .background(Color.white.opacity(0.09))
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        )
    }


    // MARK: - Buttons
    private var discardTrainingButton: some View {
        Button(role: .destructive) { cancelTapped() } label: {
            Label(isDE ? "Training verwerfen" : "Discard workout", systemImage: "trash")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.red.opacity(0.86))
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.red.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Add Exercise Button
    private var addExerciseButton: some View {
        Button { showExercisePicker = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                Text(appSettings.localized("training.addExercise"))
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(t.palette.primary)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    @ViewBuilder
    private var gymActivitiesList: some View {
        if !embeddedActivities.isEmpty {
            VStack(spacing: 16) {
                ForEach(embeddedActivities) { block in
                    gymActivityCard(block)
                }
            }
        }
    }

    private func gymActivityCard(_ block: WorkoutActivityBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(block.emoji ?? "🚴")
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.09)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(t.palette.primary)
                    Text(isDE ? "Gym-Gerät" : "Gym machine")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Button {
                    beginEditingActivity(block)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(t.palette.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                Button {
                    embeddedActivities.removeAll { $0.id == block.id }
                    if editingActivityID == block.id {
                        clearActivityDraft()
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                gymMetric(title: isDE ? "Dauer" : "Duration", value: gymDurationText(block), icon: "timer")
                if let distance = block.distanceKm, distance > 0 {
                    gymMetric(title: isDE ? "Distanz" : "Distance", value: String(format: "%.2f km", distance), icon: "point.topleft.down.curvedto.point.bottomright.up")
                }
                if let resistance = block.resistanceLevel, resistance > 0 {
                    gymMetric(title: isDE ? "Level" : "Level", value: formatDecimal(resistance), icon: "dial.medium")
                }
                if let incline = block.inclinePercent, incline > 0 {
                    gymMetric(title: isDE ? "Steigung" : "Incline", value: "\(formatDecimal(incline))%", icon: "angle")
                }
                if let watts = block.averageWatts, watts > 0 {
                    gymMetric(title: "Watt", value: "\(Int(watts.rounded())) W", icon: "bolt.fill")
                }
                if let calories = block.activeCalories, calories > 0 {
                    gymMetric(title: isDE ? "Kalorien" : "Calories", value: "\(Int(calories.rounded())) kcal", icon: "flame.fill")
                }
                if let heartRate = block.averageHeartRate, heartRate > 0 {
                    gymMetric(title: isDE ? "Ø Puls" : "Avg HR", value: "\(Int(heartRate.rounded())) bpm", icon: "heart.fill")
                }
                if let effort = block.perceivedEffort {
                    gymMetric(title: isDE ? "Anstrengung" : "Effort", value: "\(effort)/10", icon: "gauge.with.dots.needle.67percent")
                }
            }

            if let note = block.note, !note.isEmpty {
                Text(note)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func gymMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(t.palette.primary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.46))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.07)))
    }

    private var activityEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isDE ? "Aktivität erfassen" : "Log activity")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            activityTypePicker
            activityModeSelector

            if activityCaptureMode == .live {
                liveActivityStartCard
            } else {
                detailedManualActivitySection
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var activityModeSelector: some View {
        HStack(spacing: 8) {
            activityModeButton(.live, title: isDE ? "Live tracken" : "Track live", icon: "dot.radiowaves.left.and.right")
            activityModeButton(.manual, title: isDE ? "Nachtragen" : "Log later", icon: "square.and.pencil")
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private func activityModeButton(_ mode: ActivityCaptureMode, title: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                activityCaptureMode = mode
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.heavy))
                .foregroundStyle(activityCaptureMode == mode ? .black : .white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(activityCaptureMode == mode ? t.palette.primary : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var liveActivityStartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: selectedActivityKind.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(selectedActivityKind.tint)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(selectedActivityKind.tint.opacity(0.16)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(isDE ? "Live Session starten" : "Start live session")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(liveActivityDescription)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            Button {
                activityCaptureMode = .manual
            } label: {
                Label(
                    isDE ? "Detailliert nachtragen" : "Log detailed",
                    systemImage: "square.and.pencil"
                )
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.black)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(t.palette.primary))
            }
            .buttonStyle(.plain)

            Text(isDE ? "Aktivitäten werden als Teil deines Krafttrainings erfasst, ohne separaten GPS-Live-Tracker." : "Activities are logged as part of your strength workout without a separate GPS live tracker.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var detailedManualActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isDE ? "Details nachtragen" : "Detailed log")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
            activityFields
        }
    }

    private var activityTypePicker: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    showActivityDropdown.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(selectedActivityKind.tint.opacity(0.18))
                            .frame(width: 42, height: 42)
                        Image(systemName: selectedActivityKind.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(selectedActivityKind.tint)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isDE ? "Art der Aktivität" : "Activity type")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.50))
                        Text(gymActivityTitle(selectedActivityKind))
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.46))
                        .rotationEffect(.degrees(showActivityDropdown ? 180 : 0))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if showActivityDropdown {
                activityDropdown
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var activityFields: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                activityInput(title: isDE ? "Distanz (km)" : "Distance (km)", text: $activityDistanceText, icon: "point.topleft.down.curvedto.point.bottomright.up")
                    .keyboardType(.decimalPad)
                activityInput(title: isDE ? "Dauer (Minuten)" : "Duration (minutes)", text: $activityDurationMinutesText, icon: "timer")
                    .keyboardType(.numberPad)
                activityInput(title: isDE ? "Level / Widerstand" : "Level / resistance", text: $activityResistanceText, icon: "dial.medium")
                    .keyboardType(.decimalPad)
                activityInput(title: isDE ? "Steigung (%)" : "Incline (%)", text: $activityInclineText, icon: "angle")
                    .keyboardType(.decimalPad)
                activityInput(title: isDE ? "Ø Watt" : "Avg watts", text: $activityWattsText, icon: "bolt.fill")
                    .keyboardType(.numberPad)
                activityInput(title: isDE ? "Kalorien" : "Calories", text: $activityCaloriesText, icon: "flame.fill")
                    .keyboardType(.numberPad)
                activityInput(title: isDE ? "Ø Puls" : "Avg heart rate", text: $activityHeartRateText, icon: "heart.fill")
                    .keyboardType(.numberPad)
                activityInput(title: isDE ? "Höhenmeter" : "Elevation gain", text: $activityElevationText, icon: "mountain.2.fill")
                    .keyboardType(.numberPad)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isDE ? "Anstrengung" : "Effort")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("\(perceivedEffort)/10")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(t.palette.primary)
                }
                Slider(value: Binding(
                    get: { Double(perceivedEffort) },
                    set: { perceivedEffort = Int($0.rounded()) }
                ), in: 1...10, step: 1)
                .tint(t.palette.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(isDE ? "Notiz" : "Note")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                TextEditor(text: $activityNotes)
                    .frame(minHeight: 92)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            }
        }
    }

    private var activityDropdown: some View {
        VStack(spacing: 6) {
            ForEach(gymActivityKinds) { kind in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedActivityKind = kind
                        showActivityDropdown = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: kind.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(kind.tint)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(kind.tint.opacity(0.14)))
                        Text(gymActivityTitle(kind))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Spacer()
                        if selectedActivityKind == kind {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(t.palette.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedActivityKind == kind ? kind.tint.opacity(0.16) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.black.opacity(0.36)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func activityInput(title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(t.palette.primary)
                .frame(width: 22)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Exercise List
    private var exerciseList: some View {
        VStack(spacing: 16) {
            ForEach(Array(sessionManager.exercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseSection(for: index, exercise: exercise)
                    .draggable("\(index)")
                    .dropDestination(for: String.self) { items, _ in
                        guard let fromString = items.first, let from = Int(fromString) else { return false }
                        reorderExercises(from: from, over: index)
                        return true
                    }
            }
        }
    }

    // MARK: - Exercise Section
    @ViewBuilder
    private func exerciseSection(for index: Int, exercise: Exercise) -> some View {
        ExerciseSectionView(
            index: index,
            exercise: $sessionManager.exercises[index], // Binding to exercise
            onOpenDetail: { openDetail(for: exercise) },
            onAddSet: { sessionManager.addSet(to: index) },
            onRemoveSet: { setIndex in
                sessionManager.removeSet(from: index, setIndex: setIndex)
            },
            onToggleSet: { setIndex in
                sessionManager.toggleSetCompleted(exerciseIndex: index, setIndex: setIndex)
            },
            onSetValuesChanged: { setIndex, weight, reps in
                handleSetValueChange(exerciseIndex: index, setIndex: setIndex, weight: weight, reps: reps)
            },
            suggestion: lastSetSuggestion(for: exercise.name).map { ($0.kg, $0.reps, $0.date) },
            onApplySuggestion: {
                if let sugg = lastSetSuggestion(for: exercise.name) {
                    applySuggestion(sugg, toExerciseIndex: index)
                }
            }
        )
    }

    private func handleSetValueChange(exerciseIndex: Int, setIndex: Int, weight: String, reps: String) {
        guard sessionManager.exercises.indices.contains(exerciseIndex),
              sessionManager.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }

        sessionManager.exercises[exerciseIndex].sets[setIndex].weight = weight
        sessionManager.exercises[exerciseIndex].sets[setIndex].reps = reps

        let hasWeight = parseWeightString(weight) > 0
        let hasReps = (Int(reps.filter(\.isNumber)) ?? 0) > 0
        sessionManager.exercises[exerciseIndex].sets[setIndex].isCompleted = hasWeight && hasReps
    }

    private func buildActiveWorkoutPayloadForWatch() -> ActiveWorkoutPayload {
        let exercises: [ActiveWorkoutPayload.ExerciseItem] =
            sessionManager.exercises.enumerated().map { idx, ex in
                let mappedSets: [ActiveWorkoutPayload.LoggedSetItem] = ex.sets.map { set in
                    let repsInt = Int(set.reps) ?? 0
                    let weightKg = parseWeightString(set.weight)
                    return ActiveWorkoutPayload.LoggedSetItem(
                        id: set.id.uuidString,
                        reps: repsInt,
                        weight: weightKg,
                        completed: set.isCompleted          // ✅
                    )
                }

                return ActiveWorkoutPayload.ExerciseItem(
                    id: ex.id.uuidString,
                    name: ex.name,
                    order: idx,
                    setCount: mappedSets.count,
                    sets: mappedSets
                )
            }

        return ActiveWorkoutPayload(
            isActive: true,
            workoutId: watchWorkoutId,
            workoutName: sessionManager.trainingTitle.isEmpty ? "Training" : sessionManager.trainingTitle,
            exercises: exercises,
            selectedExerciseId: exercises.first?.id,
            restTimer: ActiveWorkoutPayload.RestTimerState(
                isActive: pauseTimer.state == .running || pauseTimer.state == .paused,
                remaining: pauseTimer.remaining,
                total: pauseTimer.total
            )
        )
    }

    private func startLiveActivityIfNeeded() {
        guard !liveActivityActive, canUseLiveActivity else { return }
        LiveActivityManager.shared.startActivity()
        activityTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            LiveActivityManager.shared.updateActivity(
                elapsedTime: sessionManager.elapsedTime,
                completedExercises: countCompletedExercises(),
                totalWeight: calculateTotalWeight()
            )
            // WATCH ⬅ mit jedem Live-Update auch Watch updaten
            PhoneConnectivity.shared.sendLiveUpdate(
                elapsed: sessionManager.elapsedTime,
                completed: countCompletedExercises(),
                totalKg: calculateTotalWeight(),
                unitRaw: weightUnit.rawValue
            )
        }
        liveActivityActive = true
    }

    private func startWatchUpdatesIfNeeded() {
        guard watchUpdateTimer == nil else { return }
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            PhoneConnectivity.shared.sendLiveUpdate(
                elapsed: sessionManager.elapsedTime,
                completed: countCompletedExercises(),
                totalKg: calculateTotalWeight(),
                unitRaw: weightUnit.rawValue
            )
        }
    }

    private func stopLiveActivityIfNeeded() {
        guard liveActivityActive else { return }
        activityTimer?.invalidate()
        activityTimer = nil
        LiveActivityManager.shared.endActivity()
        liveActivityActive = false
    }

    // MARK: - Set Row (Deprecated / Removed, using SetRowView in Component)
    // Kept here if we need specific logic for the component, but the component handles it now.

    // Prompt (Gewicht) basierend auf vorherigem Satz
    private func weightPrompt(exerciseIndex: Int, setIndex: Int) -> String {
        guard setIndex > 0,
              sessionManager.exercises.indices.contains(exerciseIndex),
              sessionManager.exercises[exerciseIndex].sets.indices.contains(setIndex - 1) else {
            return appSettings.localized("training.kg")
        }
        let prev = sessionManager.exercises[exerciseIndex].sets[setIndex - 1]
        let prevKg = parseWeightString(prev.weight)
        if prevKg <= 0 { return appSettings.localized("training.kg") }
        let unitVal = roundedForDisplay(weightUnit.fromKilograms(prevKg))
        let s = displayFormatter.string(from: NSNumber(value: unitVal)) ?? String(unitVal)
        return s
    }

    // Prompt (Reps) basierend auf vorherigem Satz
    private func repsPrompt(exerciseIndex: Int, setIndex: Int) -> String {
        guard setIndex > 0,
              sessionManager.exercises.indices.contains(exerciseIndex),
              sessionManager.exercises[exerciseIndex].sets.indices.contains(setIndex - 1) else {
            return appSettings.localized("training.reps")
        }
        let prev = sessionManager.exercises[exerciseIndex].sets[setIndex - 1]
        let repsClean = prev.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        return repsClean.isEmpty ? appSettings.localized("training.reps") : repsClean
    }

    // MARK: - Reorder
    private func reorderExercises(from: Int, over index: Int) {
        guard from != index,
              from >= 0, from < sessionManager.exercises.count,
              index >= 0, index < sessionManager.exercises.count else { return }

        var arr = sessionManager.exercises
        let moved = arr.remove(at: from)
        let target = index > from ? min(index, arr.count) : index
        arr.insert(moved, at: target)

        withAnimation(reorderSpring) {
            sessionManager.exercises = arr
        }
    }

    // MARK: - Actions
    private func toggleAllCompletion() {
        let allCompleted = sessionManager.exercises.flatMap { $0.sets }.allSatisfy { $0.isCompleted }
        for i in sessionManager.exercises.indices {
            for j in sessionManager.exercises[i].sets.indices {
                sessionManager.exercises[i].sets[j].isCompleted = !allCompleted
            }
        }
    }

    private func toggleAllLabel() -> String {
        let allCompleted = sessionManager.exercises.flatMap { $0.sets }.allSatisfy { $0.isCompleted }
        return appSettings.localized(allCompleted ? "training.resetAll" : "training.completeAll")
    }

    // MARK: - Save (nur lokal; keinerlei Cloud-/Social-Write)
    private func save() {
        activityTimer?.invalidate(); activityTimer = nil
        watchUpdateTimer?.invalidate(); watchUpdateTimer = nil

        let newEntry: TrainingEntry
        if entryMode == .activity {
            let title = sessionManager.trainingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let minutes = Double(activityDurationMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let duration = minutes > 0 ? minutes * 60 : max(sessionManager.elapsedTime, 0)
            let distance = parseDecimal(activityDistanceText)
            let activityTitle = title.isEmpty ? selectedActivityKind.title(isDE: isDE) : title

            newEntry = TrainingEntry(
                date: date,
                title: activityTitle,
                exercises: [],
                duration: duration,
                totalWeight: 0,
                emoji: selectedActivityKind.emoji,
                updatedAt: Date(),
                routePolyline: nil,
                cardioType: selectedActivityKind.title(isDE: false),
                distanceKm: distance,
                activeCalories: parseDecimal(activityCaloriesText),
                averageHeartRate: parseDecimal(activityHeartRateText),
                elevationGainM: parseDecimal(activityElevationText),
                perceivedEffort: perceivedEffort,
                activityNote: activityNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : activityNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else {
            newEntry = TrainingEntry(
                date: date,
                title: sessionManager.trainingTitle.isEmpty
                    ? appSettings.localized("training.training")
                    : sessionManager.trainingTitle,
                exercises: sessionManager.exercises,
                duration: sessionManager.elapsedTime,
                totalWeight: calculateTotalWeight(),
                emoji: nil,
                updatedAt: Date(),
                activities: embeddedActivities
            )
        }

        completeSave(entry: newEntry)
    }
    
    private func completeSave(entry: TrainingEntry) {
        let prevDays = trainingStore.currentStreakDays()
        let prevWeeks = weeksCeil(fromDays: prevDays)
        let newPersonalRecords = personalRecords(for: entry, comparedTo: trainingStore.history)
        let historyCountBeforeSave = trainingStore.history.count
        
        trainingStore.add(entry: entry)
        AnalyticsService.trackWorkoutSaved(
            entry: entry,
            historyCountBeforeSave: historyCountBeforeSave,
            source: entryMode == .activity ? "manual_activity" : sessionManager.workoutStartSource
        )
        let xpReward = GamificationManager.xpReward(for: entry)
        gm.addXP(xpReward)
        gm.addCoins(10)

        Task { await syncService.saveProfile(level: gm.level, xp: gm.xp, coins: gm.coins) }
        gm.unlockBadge(.firstWorkout)
        if gm.streak == 7 { gm.unlockBadge(.streak7) }

        stopLiveActivityIfNeeded()
        sessionManager.reset()
        embeddedActivities = []
        clearActivityDraft()

        let newDays = trainingStore.currentStreakDays(reference: entry.date)
        let newWeeks = weeksCeil(fromDays: newDays)

        if newWeeks > prevWeeks {
            summaryStreakWeeks = newWeeks
            summaryWeekProgress = weekProgress(asOf: entry.date)
        } else {
            summaryStreakWeeks = nil
            summaryWeekProgress = Array(repeating: false, count: 7)
        }

        lastSavedEntry = entry
        summaryPersonalRecords = newPersonalRecords
        showSummary = true
    }

    private func personalRecords(for entry: TrainingEntry, comparedTo history: [TrainingEntry]) -> [WorkoutPersonalRecord] {
        let previousBest = bestWeightByExercise(in: history)
        var currentBestByExercise: [String: (name: String, weightKg: Double, reps: Int, volumeKg: Double)] = [:]

        for exercise in entry.exercises {
            let key = normalizedExerciseName(exercise.name)
            for set in exercise.sets where set.isCompleted {
                let weight = parseStoredSetNumber(set.weight)
                let reps = Int(parseStoredSetNumber(set.reps))
                guard weight > 0, reps > 0 else { continue }

                let volume = weight * Double(reps)
                let existing = currentBestByExercise[key]
                if existing == nil || weight > existing!.weightKg {
                    currentBestByExercise[key] = (exercise.name, weight, reps, volume)
                }
            }
        }

        return currentBestByExercise.compactMap { key, current in
            let old = previousBest[key]
            guard old == nil || current.weightKg > (old ?? 0) + 0.0001 else { return nil }
            return WorkoutPersonalRecord(
                exerciseName: current.name,
                newWeightKg: current.weightKg,
                previousWeightKg: old,
                reps: current.reps,
                setVolumeKg: current.volumeKg
            )
        }
        .sorted { lhs, rhs in
            let lhsDelta = lhs.newWeightKg - (lhs.previousWeightKg ?? 0)
            let rhsDelta = rhs.newWeightKg - (rhs.previousWeightKg ?? 0)
            if abs(lhsDelta - rhsDelta) > 0.0001 { return lhsDelta > rhsDelta }
            return lhs.newWeightKg > rhs.newWeightKg
        }
    }

    private func bestWeightByExercise(in history: [TrainingEntry]) -> [String: Double] {
        var output: [String: Double] = [:]
        for entry in history {
            for exercise in entry.exercises {
                let key = normalizedExerciseName(exercise.name)
                for set in exercise.sets where set.isCompleted {
                    let weight = parseStoredSetNumber(set.weight)
                    guard weight > 0, parseStoredSetNumber(set.reps) > 0 else { continue }
                    output[key] = max(output[key] ?? 0, weight)
                }
            }
        }
        return output
    }

    private func normalizedExerciseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func parseStoredSetNumber(_ text: String) -> Double {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    // ❌ Cancel-Flow
    private func cancelTapped() {
        let hasSets = !sessionManager.exercises.flatMap({ $0.sets }).isEmpty
        let hasTitle = !sessionManager.trainingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let ranForAWhile = sessionManager.elapsedTime > 5
        if hasSets || hasTitle || ranForAWhile {
            showCancelConfirm = true
        } else {
            cancelWithoutSaving()
        }
    }

    private func cancelWithoutSaving() {
        activityTimer?.invalidate(); activityTimer = nil
        watchUpdateTimer?.invalidate(); watchUpdateTimer = nil
        stopLiveActivityIfNeeded()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            sessionManager.reset()
            embeddedActivities = []
            clearActivityDraft()
        }
    }

    // 🔙 Minimieren: zurück zur HomeView ohne Training zu beenden
    private func minimizeToHome() {
        isMinimized = true
        dismiss()
    }

    // MARK: - Helpers
    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return "\(m)m \(s)s"
    }

    private func countCompletedExercises() -> Int {
        sessionManager.exercises.reduce(0) { count, exercise in
            count + exercise.sets.filter { $0.isCompleted }.count
        }
    }

    private func calculateTotalWeight() -> Double {
        let weightsPerExercise = sessionManager.exercises.map { exercise in
            exercise.sets.reduce(0.0) { partial, set in
                partial + parseWeightString(set.weight)
            }
        }
        return weightsPerExercise.reduce(0, +)
    }

    private func parseDecimal(_ raw: String) -> Double? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: text) {
            return number.doubleValue
        }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private var gymActivityKinds: [ActivityEntryKind] {
        [.running, .walking, .cycling, .elliptical, .rowing, .stairStepper, .jumpRope, .hiit, .mobility, .stretching, .cooldown]
    }

    private func gymActivityTitle(_ kind: ActivityEntryKind) -> String {
        switch kind {
        case .running: return isDE ? "Laufband" : "Treadmill"
        case .walking: return isDE ? "Walking Pad" : "Walking Pad"
        case .cycling: return isDE ? "Fahrrad-Ergometer" : "Stationary Bike"
        case .elliptical: return isDE ? "Crosstrainer" : "Elliptical"
        case .rowing: return isDE ? "Rudergerät" : "Rower"
        case .stairStepper: return isDE ? "Stepper" : "Stair Stepper"
        case .jumpRope: return isDE ? "Seilspringen" : "Jump Rope"
        case .hiit: return "HIIT"
        case .mobility: return "Mobility"
        case .stretching: return isDE ? "Dehnen" : "Stretching"
        case .cooldown: return "Cooldown"
        default: return kind.title(isDE: isDE)
        }
    }

    private var liveActivityDescription: String {
        return isDE
        ? "Dauer und Werte kannst du detailliert als Gym-Aktivität eintragen."
        : "You can add duration and details as a gym activity."
    }

    private func makeActivityBlockFromCurrentFields() -> WorkoutActivityBlock {
        let minutes = Double(activityDurationMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let duration = max(0, minutes * 60)
        let note = activityNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkoutActivityBlock(
            id: editingActivityID ?? UUID(),
            title: gymActivityTitle(selectedActivityKind),
            kindRaw: selectedActivityKind.rawValue,
            emoji: selectedActivityKind.emoji,
            duration: duration,
            distanceKm: parseDecimal(activityDistanceText),
            resistanceLevel: parseDecimal(activityResistanceText),
            inclinePercent: parseDecimal(activityInclineText),
            averageWatts: parseDecimal(activityWattsText),
            activeCalories: parseDecimal(activityCaloriesText),
            averageHeartRate: parseDecimal(activityHeartRateText),
            elevationGainM: parseDecimal(activityElevationText),
            perceivedEffort: perceivedEffort,
            note: note.isEmpty ? nil : note
        )
    }

    private func saveEmbeddedActivityDraft() {
        let block = makeActivityBlockFromCurrentFields()
        if let editingActivityID,
           let index = embeddedActivities.firstIndex(where: { $0.id == editingActivityID }) {
            embeddedActivities[index] = block
        } else {
            embeddedActivities.append(block)
        }
        clearActivityDraft()
        showStrengthActivityForm = false
    }

    private func clearActivityDraft() {
        editingActivityID = nil
        activityDistanceText = ""
        activityDurationMinutesText = "30"
        activityResistanceText = ""
        activityInclineText = ""
        activityWattsText = ""
        activityCaloriesText = ""
        activityHeartRateText = ""
        activityElevationText = ""
        perceivedEffort = 5
        activityNotes = ""
        showActivityDropdown = false
    }

    private func beginEditingActivity(_ block: WorkoutActivityBlock) {
        editingActivityID = block.id
        selectedActivityKind = activityKind(for: block)
        activityDurationMinutesText = block.duration > 0 ? "\(Int((block.duration / 60).rounded()))" : ""
        activityDistanceText = decimalText(block.distanceKm)
        activityResistanceText = decimalText(block.resistanceLevel)
        activityInclineText = decimalText(block.inclinePercent)
        activityWattsText = decimalText(block.averageWatts)
        activityCaloriesText = decimalText(block.activeCalories)
        activityHeartRateText = decimalText(block.averageHeartRate)
        activityElevationText = decimalText(block.elevationGainM)
        perceivedEffort = block.perceivedEffort ?? 5
        activityNotes = block.note ?? ""
        showStrengthActivityForm = true
    }

    private func activityKind(for block: WorkoutActivityBlock) -> ActivityEntryKind {
        if let raw = block.kindRaw, let kind = ActivityEntryKind(rawValue: raw) {
            return kind
        }
        let lowerTitle = block.title.lowercased()
        return gymActivityKinds.first { gymActivityTitle($0).lowercased() == lowerTitle } ?? .cycling
    }

    private func decimalText(_ value: Double?) -> String {
        guard let value, value > 0 else { return "" }
        return formatDecimal(value)
    }

    private func activityBlockSubtitle(_ block: WorkoutActivityBlock) -> String {
        var parts: [String] = []
        let minutes = max(0, Int((block.duration / 60).rounded()))
        if minutes > 0 {
            parts.append("\(minutes) min")
        }
        if let distance = block.distanceKm, distance > 0 {
            parts.append(String(format: "%.2f km", distance))
        }
        if let calories = block.activeCalories, calories > 0 {
            parts.append("\(Int(calories.rounded())) kcal")
        }
        if let effort = block.perceivedEffort {
            parts.append(isDE ? "Anstrengung \(effort)/10" : "Effort \(effort)/10")
        }
        return parts.isEmpty ? (isDE ? "Im Krafttraining erfasst" : "Logged in strength workout") : parts.joined(separator: " · ")
    }

    private func gymDurationText(_ block: WorkoutActivityBlock) -> String {
        let minutes = max(0, Int((block.duration / 60).rounded()))
        return minutes > 0 ? "\(minutes) min" : "—"
    }

    private func formatDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: isDE ? "de_DE" : "en_US")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func weeksCeil(fromDays d: Int) -> Int {
        d == 0 ? 0 : (d + 6) / 7
    }

    private func weekProgress(asOf date: Date) -> [Bool] {
        var cal = Calendar.current
        cal.locale = .current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: date) else {
            return Array(repeating: false, count: 7)
        }
        let trained = Set(trainingStore.history.map { cal.startOfDay(for: $0.date) })
        return (0..<7).map { i in
            let day = cal.date(byAdding: .day, value: i, to: interval.start)!
            return trained.contains(cal.startOfDay(for: day))
        }
    }

    private func openDetail(for exercise: Exercise) {
        if let info = exerciseLibrary.exercises.first(where: { $0.name == exercise.name }) {
            if showExercisePicker {
                // Falls Picker noch offen ist: erst schließen, dann Info nach kurzer Verzögerung öffnen.
                showExercisePicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.selectedExerciseInfo = info
                }
            } else {
                // Normalfall: asynchron auf den nächsten Runloop
                DispatchQueue.main.async {
                    self.selectedExerciseInfo = info
                }
            }
        } else {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
        }
    }

    // MARK: - Weight Parsing & Draft-gestütztes Binding
    private var inputFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .current
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 6
        return f
    }
    private var displayFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .current
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 3
        return f
    }
    private var storageFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 6
        return f
    }
    private func parseWeightString(_ text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("."), !trimmed.contains(","),
           let d = Double(trimmed) {
            return d
        }
        if let n = inputFormatter.number(from: trimmed) { return n.doubleValue }
        let swappedDot = trimmed.replacingOccurrences(of: ",", with: ".")
        if let d = Double(swappedDot) { return d }
        let swappedComma = trimmed.replacingOccurrences(of: ".", with: ",")
        if let n = inputFormatter.number(from: swappedComma) { return n.doubleValue }
        return 0
    }
    private func roundedForDisplay(_ x: Double) -> Double {
        let v3 = (x * 1000).rounded() / 1000
        if abs(v3 - v3.rounded()) < 0.0005 { return v3.rounded() }
        return v3
    }

    private func weightBinding(exerciseIndex: Int, setIndex: Int, set: ExerciseSet) -> Binding<String> {
        let base = $sessionManager.exercises[exerciseIndex].sets[setIndex].weight
        return Binding<String>(
            get: {
                if focusedField == set.id, let draft = weightDraft[set.id] {
                    return draft
                }
                let kg = parseWeightString(base.wrappedValue)
                let unitValue = roundedForDisplay(weightUnit.fromKilograms(kg))
                return displayFormatter.string(from: NSNumber(value: unitValue)) ?? String(unitValue)
            },
            set: { newText in
                weightDraft[set.id] = newText
            }
        )
    }

    private func commitWeight(for id: UUID) {
        guard let path = indexPath(for: id) else { return }
        let draft = (weightDraft[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.isEmpty == false else { return }
        let unitValue = parseWeightString(draft)
        let kgRaw = weightUnit.toKilograms(unitValue)
        let kg6 = (kgRaw * 1_000_000).rounded() / 1_000_000
        sessionManager.exercises[path.i].sets[path.j].weight =
            storageFormatter.string(from: NSNumber(value: kg6)) ?? String(format: "%.6f", kg6)

        // Nach Commit: Wenn dieser Satz echte Werte hat, in leere Sätze propagieren
        if parseWeightString(sessionManager.exercises[path.i].sets[path.j].weight) > 0 ||
            !sessionManager.exercises[path.i].sets[path.j].reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            sessionManager.exercises[path.i].sets[path.j].reps != "0" {
            sessionManager.propagateSuggestionToEmptySets(exerciseIndex: path.i, sourceSetIndex: path.j)
        }
    }

    private func indexPath(for setId: UUID) -> (i: Int, j: Int)? {
        for i in sessionManager.exercises.indices {
            if let j = sessionManager.exercises[i].sets.firstIndex(where: { $0.id == setId }) {
                return (i, j)
            }
        }
        return nil
    }

    // MARK: - „Letztes Mal“-Logik

    // Hole die jüngste Session mit dieser Übung und darin den letzten sinnvollen Satz.
    private func lastSetSuggestion(for exerciseName: String) -> (kg: Double, reps: Int, date: Date)? {
        lastSetSuggestionCache[exerciseName]
    }

    private func rebuildLastSetSuggestionCache() {
        var cache: [String: (kg: Double, reps: Int, date: Date)] = [:]
        for entry in trainingStore.history.sorted(by: { $0.date > $1.date }) {
            for ex in entry.exercises where cache[ex.name] == nil {
                for set in ex.sets.reversed() {
                    let kg = parseWeightString(set.weight)
                    let reps = Int(set.reps.filter("0123456789".contains)) ?? 0
                    if kg > 0, reps > 0 {
                        cache[ex.name] = (kg, reps, entry.date)
                        break
                    }
                }
            }
        }
        lastSetSuggestionCache = cache
    }

    // Kompakte Pill-View mit „Übernehmen“-Button
    @ViewBuilder
    private func lastTimePill(exerciseName: String,
                              kg: Double,
                              reps: Int,
                              date: Date,
                              onApply: @escaping () -> Void) -> some View {
        let unitValue = roundedForDisplay(weightUnit.fromKilograms(kg))
        let weightStr = displayFormatter.string(from: NSNumber(value: unitValue)) ?? String(unitValue)
        let dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)

        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(t.palette.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(appSettings.language.hasPrefix("de")
                     ? "Letztes Mal"
                     : "Last time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(weightStr) \(weightUnit.symbol) × \(reps)")
                    .font(.subheadline.weight(.semibold))
                Text(dateStr)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onApply()
            } label: {
                Text(appSettings.language.hasPrefix("de") ? "Übernehmen" : "Apply")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(t.palette.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.dsFieldBG)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.dsOutline, lineWidth: 0.5)
        )
    }

    // Trägt die Empfehlung in den ersten „leeren“ Satz dieser Übung ein
    private func applySuggestion(_ s: (kg: Double, reps: Int, date: Date), toExerciseIndex i: Int) {
        guard sessionManager.exercises.indices.contains(i) else { return }
        // finde ersten leeren Satz (0 kg und 0/leer reps)
        if let j = sessionManager.exercises[i].sets.firstIndex(where: { set in
            let kg = parseWeightString(set.weight)
            let reps = Int(set.reps.filter("0123456789".contains)) ?? 0
            return kg <= 0 && reps <= 0
        }) {
            // Gewicht als kg im Storage-Format speichern
            let kg6 = (s.kg * 1_000_000).rounded() / 1_000_000
            sessionManager.exercises[i].sets[j].weight =
                storageFormatter.string(from: NSNumber(value: kg6)) ?? String(format: "%.6f", kg6)
            sessionManager.exercises[i].sets[j].reps = String(s.reps)

            // danach ruhig die Propagation nutzen
            sessionManager.propagateSuggestionToEmptySets(exerciseIndex: i, sourceSetIndex: j)

            // kleines Haptic Feedback
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } else {
            // wenn keiner leer ist: hänge einen neuen Satz an
            sessionManager.addSet(to: i)
            if let j = sessionManager.exercises[i].sets.indices.last {
                let kg6 = (s.kg * 1_000_000).rounded() / 1_000_000
                sessionManager.exercises[i].sets[j].weight =
                    storageFormatter.string(from: NSNumber(value: kg6)) ?? String(format: "%.6f", kg6)
                sessionManager.exercises[i].sets[j].reps = String(s.reps)
            }
        }
    }

    // MARK: - Lifecycle handlers split

    private func handleOnAppear() {
        if !sessionManager.isTrainingActive {
            sessionManager.startTraining()
            AnalyticsService.trackWorkoutStarted(source: "quick_start")
        }
        if watchWorkoutId.isEmpty {
            watchWorkoutId = UUID().uuidString
        }
        if lastSetSuggestionCache.isEmpty {
            rebuildLastSetSuggestionCache()
        }
        if embeddedActivities.isEmpty, !sessionManager.activities.isEmpty {
            embeddedActivities = sessionManager.activities
        }

        PhoneConnectivity.shared.activate()
        
        PhoneConnectivity.shared.onHeartRate = { bpm in
            Task { @MainActor in
                healthKit.ingestWatchHeartRate(bpm)
            }
        }

        PhoneConnectivity.shared.pushActiveWorkoutState(buildActiveWorkoutPayloadForWatch())

        PhoneConnectivity.shared.sendLiveUpdate(
            elapsed: sessionManager.elapsedTime,
            completed: countCompletedExercises(),
            totalKg: calculateTotalWeight(),
            unitRaw: weightUnit.rawValue
        )

        startLiveActivityIfNeeded()

        visibility = Visibility(rawValue: defaultVisibilityRaw) ?? .public

        // ✅ HKWorkoutSession starten → öffnet Watch App automatisch!
        Task {
            await healthKit.startWorkoutSession()
        }

        pauseTimer.configure(total: automaticRestSeconds)
        pauseTimer.onFinished = {
            NotificationManager1.shared.sendPauseFinishedNow()
        }
        lastCompletedSetCount = completedSetCount

        Task {
                if let type = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                    await healthKit.requestReadAuthorizationIfNeeded(
                        readTypes: [type],
                        forcePrompt: true
                    )
                    // AirPods/andere Quellen erlauben → nicht auf Watch filtern
                    healthKit.startHeartRateStreaming(filterToAppleWatch: false)
                }
            }


        isMinimized = false

        // WATCH ⬅ Sofort initialen Stand an die Watch senden
        PhoneConnectivity.shared.sendLiveUpdate(
            elapsed: sessionManager.elapsedTime,
            completed: countCompletedExercises(),
            totalKg: calculateTotalWeight(),
            unitRaw: weightUnit.rawValue
        )
    }

    private func startAutomaticRestTimer() {
        guard sessionManager.isTrainingActive else { return }
        pauseTimer.configure(total: automaticRestSeconds)
        pauseTimer.start()
        pushActiveWorkoutToWatchIfNeeded()
    }

    private func handleOnDisappear() {
        activityTimer?.invalidate()
        activityTimer = nil
        PhoneConnectivity.shared.onHeartRate = nil


        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil

        if liveActivityActive && !isMinimized {
            LiveActivityManager.shared.endActivity()
            liveActivityActive = false
        }

        healthKit.stopHeartRateStreaming()
        
        // ✅ HKWorkoutSession beenden
        Task {
            await healthKit.stopWorkoutSession()
        }
    }
}

// MARK: - Mini Pause Knob
private struct PauseKnob: View {
    let progress: CGFloat
    let remaining: TimeInterval
    var action: () -> Void

    private var clampedProgress: CGFloat {
        max(CGFloat(0.001), min(CGFloat(1), progress))
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Color.dsOutline.opacity(0.6), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: clampedProgress)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "pause.fill").font(.system(size: 10, weight: .bold)))
                Text(formatMMSS(remaining))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .dsChip()
    }

    private func formatMMSS(_ interval: TimeInterval) -> String {
        let m = Int(max(0, interval)) / 60
        let s = Int(max(0, interval)) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
// MARK: - Keyboard helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - View Modifiers to break up large chains

private struct ApplyTopInsets: ViewModifier {
    let controls: AnyView
    init<Controls: View>(controls: Controls) {
        self.controls = AnyView(controls)
    }
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, alignment: .leading, spacing: 0) {
                controls
            }
    }
}

private struct ApplyBottomInset: ViewModifier {
    let height: CGFloat
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: height)
            }
    }
}

private struct ExercisePickerSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var searchText: String
    let filteredExercises: [ExerciseInfo]
    let recentNames: [String]
    let onSelectName: (String) -> Void
    let onInfo: (ExerciseInfo) -> Void
    let onCreate: (String) -> Void
    let onAddActivity: () -> Void
    let onCancel: () -> Void
    let navTitle: String
    let cancelTitle: String
    let searchPlaceholder: String
    let recentTitle: String
    let addNewPrefix: String
    
    @EnvironmentObject var appSettings: AppSettings

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    RadialGradient(
                        colors: [Color.blue.opacity(0.28), Color.cyan.opacity(0.10), .clear],
                        center: .topLeading,
                        startRadius: 24,
                        endRadius: 420
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.58))
                        TextField(searchPlaceholder, text: $searchText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                        if !recentNames.isEmpty && searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(recentTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.52))
                                ForEach(recentNames, id: \.self) { name in
                                    Button {
                                        onSelectName(name)
                                    } label: {
                                        exercisePickerRow(title: appSettings.localized(name), subtitle: nil, icon: "clock.arrow.circlepath", tint: .blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(appSettings.language.lowercased().hasPrefix("de") ? "Mehr hinzufügen" : "Add more")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.52))
                                Button {
                                    onAddActivity()
                                } label: {
                                    exercisePickerRow(
                                        title: appSettings.language.lowercased().hasPrefix("de") ? "Gym-Gerät hinzufügen" : "Add gym machine",
                                        subtitle: appSettings.language.lowercased().hasPrefix("de") ? "Laufband, Fahrrad, Crosstrainer, Rudergerät" : "Treadmill, bike, elliptical, rower",
                                        icon: "figure.outdoor.cycle",
                                        tint: .cyan
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(navTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.52))
                            if filteredExercises.isEmpty {
                                if !searchText.isEmpty {
                                    Button {
                                        onCreate(searchText)
                                    } label: {
                                        exercisePickerRow(title: "\(addNewPrefix) „\(searchText)“", subtitle: nil, icon: "plus", tint: .green)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Text("Keine Treffer")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.52))
                                }
                            } else {
                                ForEach(filteredExercises, id: \.self) { info in
                                    HStack(spacing: 10) {
                                        Button {
                                            onSelectName(info.name)
                                        } label: {
                                            exercisePickerRow(
                                                title: info.localizedName(using: appSettings),
                                                subtitle: [info.primaryMuscle ?? info.muscleGroup, info.equipment].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • "),
                                                icon: "dumbbell.fill",
                                                tint: .blue
                                            )
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            onInfo(info)
                                        } label: {
                                            Image(systemName: "info.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white.opacity(0.62))
                                                .frame(width: 42, height: 42)
                                                .background(Circle().fill(.white.opacity(0.08)))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Übungsdetails")
                                    }
                                }
                            }
                        }
                    }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                }
                }
                .preferredColorScheme(.dark)
                .navigationTitle(navTitle)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancelTitle) { onCancel() }
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func exercisePickerRow(title: String, subtitle: String?, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.16)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

private struct PauseTimerSheetModifierWrap: ViewModifier {
    @Environment(\.designTokens) private var t
    @EnvironmentObject private var appSettings: AppSettings

    @Binding var isPresented: Bool
    @Binding var detent: PresentationDetent
    var timer: PauseTimer
    @Binding var automaticRestSeconds: Double

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            PauseTimerSheet(timer: timer, automaticRestSeconds: $automaticRestSeconds, accent: t.palette.primary)
                .presentationDetents(
                    [PresentationDetent.fraction(0.72), PresentationDetent.large],
                    selection: $detent
                )
                // Falls du noch dein enum Visibility im File hast -> unbedingt so qualifizieren:
                .presentationDragIndicator(SwiftUI.Visibility.visible)
                .ignoresSafeArea(SwiftUI.SafeAreaRegions.keyboard)
                // WICHTIG: nicht mehr hart Dark erzwingen – respektiere App-Thema
                .preferredColorScheme(appSettings.themeMode.colorScheme)
                .modifier(ClearSheetBackground())
        }
    }
}


private struct ClearSheetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.clear)   // ✅ entfernt das helle System-Sheet
        } else {
            content
        }
    }
}
 
private struct ExerciseDetailSheetModifier: ViewModifier {
    @Binding var selectedExerciseInfo: ExerciseInfo?
    var trainingStore: TrainingStore

    func body(content: Content) -> some View {
        content.sheet(item: $selectedExerciseInfo) { info in
            ExerciseDetailView(exerciseInfo: info)
                .environmentObject(trainingStore)
        }
    }
}

private struct LifecycleHandlersModifier: ViewModifier {
    let onAppear: () -> Void
    let onDisappear: () -> Void
    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
    }
}

private struct WatchImmediatePushModifier: ViewModifier {
    let elapsed: TimeInterval
    let completed: Int
    let totalKg: Double
    let unitRaw: String
    func body(content: Content) -> some View {
        content
            .onAppear {
                PhoneConnectivity.shared.sendLiveUpdate(
                    elapsed: elapsed,
                    completed: completed,
                    totalKg: totalKg,
                    unitRaw: unitRaw
                )
            }
    }
}

// Expose WatchImmediatePushModifier as a chainable view extension
private extension View {
    func watchPushOnAppear(elapsed: TimeInterval,
                           completed: Int,
                           totalKg: Double,
                           unitRaw: String) -> some View {
        self.modifier(WatchImmediatePushModifier(elapsed: elapsed,
                                                 completed: completed,
                                                 totalKg: totalKg,
                                                 unitRaw: unitRaw))
    }
}

private struct OverlaysAlertsSummaryModifier<SummaryView: View>: ViewModifier {
    @Environment(\.designTokens) private var t

    @Binding var rewardMessage: RewardMessage?
    @Binding var showCancelConfirm: Bool

    let cancelAction: () -> Void
    let doneTitle: String
    let cancelTitle: String
    let discardMessage: String

    @Binding var showSummary: Bool
    @Binding var lastSavedEntry: TrainingEntry?

    let summaryView: (TrainingEntry, @escaping () -> Void) -> SummaryView

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if let reward = rewardMessage {
                    RewardPopup(
                        text: reward.text,
                        icon: reward.icon,
                        color: t.palette.primary,
                        level: reward.level,
                        nextLevel: reward.nextLevel,
                        xpToNextLevel: reward.xpToNextLevel,
                        progress: reward.progress
                    )
                        .transition(AnyTransition.scale.combined(with: AnyTransition.opacity))
                        .zIndex(999)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeOut) { rewardMessage = nil }
                            }
                        }
                }
            }
            .alert(cancelTitle, isPresented: $showCancelConfirm) {
                Button(cancelTitle, role: .destructive) { cancelAction() }
                Button(doneTitle, role: .cancel) { }
            } message: {
                Text(discardMessage)
            }
            .fullScreenCover(isPresented: $showSummary, onDismiss: { lastSavedEntry = nil }) {
                if let entry = lastSavedEntry {
                    summaryView(entry) {
                        showSummary = false
                    }
                } else {
                    VStack {
                        Text("Summary").font(.title2).padding()
                        Button("Fertig") { showSummary = false }
                    }
                }
            }
    }
}

// MARK: - 🔧 Pausen-Timer Engine + UI
// PauseTimerSheet UI is defined in PauseTimer.swift


// MARK: - 🔧 Pausen-Timer Engine + UI
private final class PauseTimer: ObservableObject {
    enum State { case idle, running, paused, finished }

    @Published var state: State = .idle
    @Published var total: TimeInterval = 60
    @Published var remaining: TimeInterval = 60
    @Published var progress: CGFloat = 1.0

    var onFinished: (() -> Void)?

    private var cancellable: AnyCancellable?
    private var startDate: Date?
    private var elapsedBeforePause: TimeInterval = 0

    func configure(total seconds: TimeInterval) {
        total = max(1, seconds)
        remaining = total
        progress = 1
        state = .idle
        cancelTimer()
    }

    func start() {
        guard total > 0 else { return }
        remaining = total
        progress = 1
        elapsedBeforePause = 0
        startDate = Date()
        state = .running
        runTimer()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        elapsedBeforePause += Date().timeIntervalSince(startDate ?? Date())
        cancelTimer()
    }

    func resume() {
        guard state == .paused else { return }
        startDate = Date()
        state = .running
        runTimer()
    }

    func add(seconds: TimeInterval) {
        guard state == .running || state == .paused || state == .idle else { return }
        total = max(1, total + seconds)
        remaining = max(0, remaining + seconds)
        progress = total > 0 ? CGFloat(remaining / total) : 0
    }

    func reset() {
        cancelTimer()
        remaining = total
        progress = 1
        elapsedBeforePause = 0
        state = .idle
    }

    private func finish() {
        cancelTimer()
        remaining = 0
        progress = 0
        state = .finished
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        AudioServicesPlaySystemSound(1057)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        onFinished?()
    }

    private func runTimer() {
        cancelTimer()
        let startRef = startDate ?? Date()
        let baseElapsed = elapsedBeforePause
        cancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.state == .running else { return }
                let elapsed = baseElapsed + Date().timeIntervalSince(startRef)
                let rem = max(0, self.total - elapsed)
                self.remaining = rem
                self.progress = self.total > 0 ? CGFloat(rem / self.total) : 0
                if rem <= 0.0001 { self.finish() }
            }
    }

    private func cancelTimer() {
        cancellable?.cancel(); cancellable = nil
    }
}

private struct PauseTimerSheet: View {
    @ObservedObject var timer: PauseTimer
    @Binding var automaticRestSeconds: Double
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    var accent: Color = .accentColor   // ✅ neu

    @State private var minutes: Int = 2
    @State private var seconds: Int = 0

    private let presets: [Int] = [60, 90, 120, 150, 180]

    private var clampedProgress: CGFloat {
        max(CGFloat(0.001), min(CGFloat(1), timer.progress))
    }


    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.34), .clear],
                           center: .topLeading,
                           startRadius: 20,
                           endRadius: 360)
                .ignoresSafeArea()

            VStack(spacing: 18) {
            HStack {
                Label(appSettings.localized("rest.pause"), systemImage: "pause.circle.fill")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.10)))
                }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)

            content()
                .padding(.horizontal)

            footer
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .padding(.top, 12)
        }
        .onAppear {
            if timer.state == .idle {
                let saved = Int(max(1, automaticRestSeconds))
                minutes = saved / 60
                seconds = saved % 60
                timer.configure(total: TimeInterval(saved))
            }
        }
    }

    @ViewBuilder
    private func content() -> some View {
        switch timer.state {
        case .idle:
            idleConfigurator
        case .running, .paused, .finished:
            runningView
        }
    }

    private var idleConfigurator: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appSettings.language.lowercased().hasPrefix("de") ? "Automatische Satzpause" : "Automatic rest timer")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Text(appSettings.language.lowercased().hasPrefix("de") ? "Diese Dauer startet nach jedem abgeschlossenen Satz." : "This duration starts after each completed set.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { s in
                        Button {
                            minutes = s / 60
                            seconds = s % 60
                            automaticRestSeconds = Double(s)
                            timer.configure(total: TimeInterval(s))
                        } label: {
                            Text(label(for: s))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                        }
                        .dsChip()
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(spacing: 12) {
                Picker(appSettings.localized("rest.minutes"), selection: $minutes) {
                    ForEach(0..<61, id: \.self) { Text("\($0)m").foregroundStyle(.white).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker(appSettings.localized("rest.seconds"), selection: $seconds) {
                    ForEach(0..<60, id: \.self) { Text("\($0)s").foregroundStyle(.white).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 160)
            .dsField(corner: 18)
            .onChange(of: minutes) { _ in updateAutomaticRestDuration() }
            .onChange(of: seconds) { _ in updateAutomaticRestDuration() }

            Button {
                let total = TimeInterval(minutes * 60 + seconds)
                automaticRestSeconds = total > 0 ? total : 1
                timer.configure(total: total > 0 ? total : 1)
                timer.start()
            } label: {
                Label(appSettings.localized("rest.start"), systemImage: "play.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.black)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent))
            }
            .buttonStyle(.plain)
        }
    }

    private var runningView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.25), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [accent, accent.opacity(0.5), accent]),
                                        center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: timer.progress)

                Text(formatMMSS(timer.remaining))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 240, height: 240)
            .padding(.vertical, 4)

            HStack(spacing: 10) {
                addButton("+15s", 15)
                addButton("+30s", 30)
                addButton("+1m", 60)
            }

            HStack(spacing: 12) {
                switch timer.state {
                case .running:
                    Button { timer.pause() } label: {
                        Label(appSettings.localized("rest.pause"), systemImage: "pause.fill").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.10)))
                case .paused:
                    Button { timer.resume() } label: {
                        Label(appSettings.localized("rest.resume"), systemImage: "play.fill").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent))
                case .finished:
                    Button { timer.reset() } label: {
                        Label(appSettings.localized("rest.reset"), systemImage: "gobackward").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.10)))
                case .idle:
                    EmptyView()
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if timer.state == .running || timer.state == .paused {
                Button(role: .destructive) { timer.reset() } label: {
                    Label(appSettings.localized("rest.cancel"), systemImage: "xmark")
                }
            }
            Spacer()
            if timer.state == .finished {
                Button {
                    timer.reset()
                    dismiss()
                } label: {
                    Label(appSettings.localized("rest.done"), systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func addButton(_ title: String, _ seconds: TimeInterval) -> some View {
        Button(title) { timer.add(seconds: seconds) }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .dsChip()
    }

    private func label(for seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    private func formatMMSS(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func updateAutomaticRestDuration() {
        guard timer.state == .idle else { return }
        let total = max(1, minutes * 60 + seconds)
        automaticRestSeconds = Double(total)
        timer.configure(total: TimeInterval(total))
    }
}
private extension PauseTimer {
    var isRunning: Bool { state == .running || state == .paused }
}

// MARK: - HR Sheets/Views

private struct HeartRateInfoSheet: View {
    let bpm: Int?
    let isMonitoring: Bool
    let onStart: () -> Void

    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.12)).frame(width: 44, height: 44)
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Herzfrequenz")
                            .font(.headline)
                        Text(isMonitoring ? "Live aktiv" : "Inaktiv")
                            .font(.footnote)
                            .foregroundStyle(isMonitoring ? .green : .secondary)
                    }
                    Spacer()
                    Text(bpm.map { "\($0) bpm" } ?? "—")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.horizontal)

                // Kurz erklärt (knapper Text)
                VStack(alignment: .leading, spacing: 8) {
                    Text("So funktioniert’s")
                        .font(.subheadline.weight(.semibold))
                    Text("Movo liest deine Herzfrequenz aus Apple Health. Mit Apple Watch oder kompatiblen Kopfhörern (z. B. AirPods) erhältst du oft aktuellere Werte.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsFieldBG))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsOutline, lineWidth: 0.5))
                .padding(.horizontal)

                // Aktionen
                VStack(spacing: 10) {
                    Button {
                        onStart()
                    } label: {
                        Label("Live‑HR starten", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showDetails = true
                    } label: {
                        Label("Details anzeigen", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Spacer(minLength: 8)
            }
            .navigationTitle("Herzfrequenz")
            .navigationBarTitleDisplayMode(.inline)
            // Detail-Sheet über diesem Sheet
            .sheet(isPresented: $showDetails) {
                HeartRateDetailView(
                    bpm: bpm,
                    isMonitoring: isMonitoring,
                    onClose: { showDetails = false }
                )
            }
        }
    }
}

private struct HeartRateDetailView: View {
    let bpm: Int?
    let isMonitoring: Bool
    let onClose: () -> Void

    private var zoneText: String {
        guard let bpm else { return "—" }
        // Einfache Heuristik ohne Alter: Zonen grob anhand 190 als Max
        let maxHR = 190.0
        let pct = Double(bpm) / maxHR
        switch pct {
        case ..<0.6: return "Zone 1 · Leicht"
        case ..<0.7: return "Zone 2 · Locker"
        case ..<0.8: return "Zone 3 · Mittel"
        case ..<0.9: return "Zone 4 · Hart"
        default:     return "Zone 5 · Maximal"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Große Zahl
                    VStack(spacing: 8) {
                        Text(bpm.map { "\($0)" } ?? "—")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                        Text("bpm")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)

                    // Zone
                    VStack(spacing: 6) {
                        Text(zoneText)
                            .font(.title3.weight(.semibold))
                        Text(isMonitoring ? "Monitoring aktiv" : "Monitoring inaktiv")
                            .font(.footnote)
                            .foregroundStyle(isMonitoring ? .green : .secondary)
                    }

                    // Hinweise
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tipps für genauere Werte")
                            .font(.headline)
                        Text("• Trage die Watch/Kopfhörer korrekt.\n• Starte ein Training in Movo.\n• Erlaube den Health‑Zugriff für Herzfrequenz.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.dsFieldBG))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsOutline, lineWidth: 0.5))
                    .padding(.horizontal)

                    // Troubleshooting
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Kein Puls sichtbar?")
                            .font(.headline)
                        Text("• Prüfe Health‑Zugriff unter Quellen.\n• Aktiviere Bluetooth.\n• Warte einige Sekunden – HealthKit hat oft geringe Verzögerung.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.dsFieldBG))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsOutline, lineWidth: 0.5))
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("HR‑Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { onClose() }
                }
            }
        }
    }
}

// MARK: - Polyline ENcodieren (CLLocationCoordinate2D[] -> String)

func encodePolyline(_ coords: [CLLocationCoordinate2D]) -> String {
    guard !coords.isEmpty else { return "" }
    
    var output = ""
    var lastLat = 0
    var lastLon = 0
    
    for coord in coords {
        let lat = Int(round(coord.latitude * 1e5))
        let lon = Int(round(coord.longitude * 1e5))
        
        let dLat = lat - lastLat
        let dLon = lon - lastLon
        
        output.append(encodeSigned(dLat))
        output.append(encodeSigned(dLon))
        
        lastLat = lat
        lastLon = lon
    }
    
    return output
}

private func encodeSigned(_ value: Int) -> String {
    var v = value << 1
    if value < 0 {
        v = ~v
    }
    
    var chunks: [UInt8] = []
    
    while v >= 0x20 {
        let chunk = UInt8((0x20 | (v & 0x1f)) + 63)
        chunks.append(chunk)
        v >>= 5
    }
    chunks.append(UInt8(v + 63))
    
    return String(bytes: chunks, encoding: .utf8) ?? ""
}
