import SwiftUI
import ActivityKit
import UniformTypeIdentifiers
import WidgetKit
import Combine
import UserNotifications
import FirebaseAuth
import HealthKit
import CoreLocation
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
}

// MARK: - RewardPopup moved to top-level (so modifiers can see it)
struct RewardPopup: View {
    let text: String
    let icon: String
    let color: Color
    @Environment(\.designTokens) private var t

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(color)
            Text(text).font(.headline.bold())
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

// MARK: - NewTrainingView (Kraft – nur lokal speichern)

struct NewTrainingView: View {
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var healthKit: HealthKitManager

    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t

    @State private var date = Date()
    @State private var rewardMessage: RewardMessage? = nil
    @State private var showExercisePicker = false
    @State private var exerciseSearchText = ""
    @FocusState private var focusedField: UUID?
    @FocusState private var titleFocused: Bool
    @State private var activityTimer: Timer?
    @State private var liveActivityActive = false
    private var canUseLiveActivity: Bool { purchaseManager.hasUnlockedStatistics }

    // 🔔 Pausen-Timer
    @State private var showPauseTimer = false
    @StateObject private var pauseTimer = PauseTimer() // FIX: use model, not sheet view
    @State private var pauseSheetDetent: PresentationDetent = .fraction(0.6)

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

    // Minimieren-Status, um Live Activity nicht zu beenden
    @State private var isMinimized = false

    // ✅ Animations (fix: ambig spring)
    private let reorderSpring = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0)
    private let rewardSpring  = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.9,  blendDuration: 0)

    // MARK: - Header
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Titel
            TextField(appSettings.localized("training.title.placeholder"),
                      text: $sessionManager.trainingTitle)
                .font(.system(size: 28, weight: .bold))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .dsField(corner: 16)
                .focused($titleFocused)

            // Chips: Datum, Timer, Pause + ❤️ Puls
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

    // MARK: - Body (refactored to help the compiler)
    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarBackButtonHidden(true)
                .toolbar { keyboardToolbar }
        }
        .modifier(LifecycleHandlersModifier(onAppear: handleOnAppear,
                                           onDisappear: handleOnDisappear))
        .onChange(of: purchaseManager.hasUnlockedStatistics) { isPro in
            handleProChange(isPro)
        }
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
                headerView
                actionButtons
                addExerciseButton
                exerciseList
            }
            .padding()
            .onTapGesture { hideKeyboard() }
        }
    }

    // Type-erased, grouped content to reduce inference complexity
    private var mainContent: some View {
        AnyView(
            contentScroll
                .modifier(ApplyTopInsets(controls: topLeftControls))
                .modifier(ApplyBottomInset(height: 100))
                .scrollDismissesKeyboard(.interactively)
        )
    }

    
    // MARK: - Small helpers to keep `body` lightweight

    private var totalSetCount: Int {
        sessionManager.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func pushActiveWorkoutToWatchIfNeeded() {
        guard sessionManager.isTrainingActive else { return }
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
            onSelect: { info in
                sessionManager.addExercise(info.name)
                showExercisePicker = false
                exerciseSearchText = ""
            },
            onInfo: { info in
                openDetailFromPicker(info: info)
            },
            onCancel: {
                showExercisePicker = false
                exerciseSearchText = ""
            },
            navTitle: appSettings.localized("training.addExercise") ?? "Übung hinzufügen",
            cancelTitle: appSettings.localized("common.cancel") ?? "Abbrechen",
            searchPlaceholder: appSettings.localized("common.search") ?? "Suchen"
        )
    }

    private var pauseTimerSheetModifier: PauseTimerSheetModifierWrap {
        PauseTimerSheetModifierWrap(
            isPresented: $showPauseTimer,
            detent: $pauseSheetDetent,
            timer: pauseTimer
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
        WorkoutSummaryView(
            entry: entry,
            streakWeeks: summaryStreakWeeks,
            weekProgress: summaryWeekProgress
        ) {
            showSummary = false
            dismiss()
        }
    }

    // MARK: - Top Left Controls (✅ push down via safeAreaInset)
    private var topLeftControls: some View {
        VStack(spacing: 10) {
            Button(action: { minimizeToHome() }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .stroke(Color.dsOutline, lineWidth: 0.5)

                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appSettings.localized("common.back") ?? "Zurück")

            Button(action: { cancelTapped() }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .stroke(Color.dsOutline, lineWidth: 0.5)

                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appSettings.localized("training.cancel"))
        }
        .padding(.leading, 12)
        .padding(.top, 6)
        .padding(.bottom, 12)
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
        .dsChip()
    }

    private var timeChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "stopwatch")
            Text(formatTime(sessionManager.elapsedTime))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 110)
        .frame(height: chipHeight)
        .dsChip()
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
        guard purchaseManager.hasUnlockedStatistics else { return AnyView(EmptyView()) }

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
                .background(Color.black)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        )
    }


    // MARK: - Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { save() } label: {
                Label(appSettings.localized("training.save"), systemImage: "tray.and.arrow.down.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(t.palette.primary)

            Button { toggleAllCompletion() } label: {
                Text(toggleAllLabel())
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(t.palette.primary)
        }
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
            .padding(.vertical, 10)
            .foregroundStyle(t.palette.primary)
            .dsField(corner: 14)
        }
    }

    // MARK: - Exercise List
    private var exerciseList: some View {
        VStack(spacing: 16) {
            ForEach(Array(sessionManager.exercises.enumerated()), id: \.offset) { index, exercise in
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(t.palette.primary)
                    .contentShape(Rectangle())
                    .onTapGesture { openDetail(for: exercise) }

                Spacer()

                Button { openDetail(for: exercise) } label: {
                    Image(systemName: "info.circle").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(t.palette.primary)
                .accessibilityLabel("Übungsdetails")

                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
                    .draggable("\(index)")
            }

            VStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { setIndex, set in
                    setRow(exerciseIndex: index, setIndex: setIndex, set: set)
                }
            }
            .appElevatedCard()
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.dsChipBG))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.dsOutline, lineWidth: 0.5))

            Button {
                sessionManager.addSet(to: index)
            } label: {
                Label(appSettings.localized("training.addSet"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(t.palette.primary)
            }
            .padding(.top, 4)
        }
        .appElevatedCard()
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.dsFieldBG))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.dsOutline, lineWidth: 0.5))
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
            workoutId: UUID().uuidString,
            workoutName: sessionManager.trainingTitle.isEmpty ? "Training" : sessionManager.trainingTitle,
            exercises: exercises,
            selectedExerciseId: exercises.first?.id
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

    // MARK: - Set Row (Empfehlung als Prompt/Placeholder + Propagation Trigger)
    @ViewBuilder
    private func setRow(exerciseIndex: Int, setIndex: Int, set: ExerciseSet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    TextField("",
                              text: weightBinding(exerciseIndex: exerciseIndex, setIndex: setIndex, set: set),
                              prompt: Text(weightPrompt(exerciseIndex: exerciseIndex, setIndex: setIndex))
                                .foregroundStyle(.secondary)
                    )
                    .keyboardType(.decimalPad)
                    .padding(8)
                    .dsField()
                    .frame(width: 90)
                    .focused($focusedField, equals: set.id)
                    .onChange(of: weightDraft[set.id] ?? "") { _ in
                        // kein sofortiger Trigger – Commit passiert beim Focus-Verlust/Done
                    }

                    Text(weightUnit.symbol)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                TextField("",
                          text: $sessionManager.exercises[exerciseIndex].sets[setIndex].reps,
                          prompt: Text(repsPrompt(exerciseIndex: exerciseIndex, setIndex: setIndex))
                            .foregroundStyle(.secondary)
                )
                .keyboardType(.numberPad)
                .padding(8)
                .dsField()
                .frame(width: 80)
                .focused($focusedField, equals: set.id)
                .onChange(of: sessionManager.exercises[exerciseIndex].sets[setIndex].reps) { newVal in
                    // Wenn Reps nun „echt“ sind und Gewicht auch > 0 (in kg), in leere Sätze propagieren
                    let repsClean = newVal.trimmingCharacters(in: .whitespacesAndNewlines)
                    let kg = parseWeightString(sessionManager.exercises[exerciseIndex].sets[setIndex].weight)
                    if (!repsClean.isEmpty && repsClean != "0") || kg > 0 {
                        sessionManager.propagateSuggestionToEmptySets(exerciseIndex: exerciseIndex, sourceSetIndex: setIndex)
                    }
                }

                Spacer()

                Button {
                    sessionManager.toggleSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(set.isCompleted ? t.palette.positive : .secondary)
                }

                Button {
                    sessionManager.removeSet(from: exerciseIndex, setIndex: setIndex)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(t.palette.warning)
                }
            }
            .padding(.vertical, 4)
        }
    }

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

        let prevDays = trainingStore.currentStreakDays()
        let prevWeeks = weeksCeil(fromDays: prevDays)

        gm.addXP(80)
        gm.addCoins(10)

        let newEntry = TrainingEntry(
            date: date,
            title: sessionManager.trainingTitle.isEmpty
                ? appSettings.localized("training.training")
                : sessionManager.trainingTitle,
            exercises: sessionManager.exercises,
            duration: sessionManager.elapsedTime,
            totalWeight: calculateTotalWeight(),
            emoji: nil,
            updatedAt: Date()
        )

        trainingStore.add(entry: newEntry)

        Task { await syncService.saveProfile(level: gm.level, xp: gm.xp, coins: gm.coins) }

        withAnimation(rewardSpring) {
            rewardMessage = RewardMessage(text: "+80 XP & +10 Coins",
                                          icon: "star.fill",
                                          color: t.palette.primary)
        }
        gm.unlockBadge(.firstWorkout)
        if gm.streak == 7 { gm.unlockBadge(.streak7) }

        stopLiveActivityIfNeeded()
        sessionManager.reset()

        let newDays = trainingStore.currentStreakDays(reference: newEntry.date)
        let newWeeks = weeksCeil(fromDays: newDays)

        if newWeeks > prevWeeks {
            summaryStreakWeeks = newWeeks
            summaryWeekProgress = weekProgress(asOf: newEntry.date)
        } else {
            summaryStreakWeeks = nil
            summaryWeekProgress = Array(repeating: false, count: 7)
        }

        lastSavedEntry = newEntry
        showSummary = true
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
        sessionManager.reset()
        dismiss()
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

    // MARK: - Lifecycle handlers split

    private func handleOnAppear() {
        if !sessionManager.isTrainingActive {
            sessionManager.startTraining()
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

        if purchaseManager.hasUnlockedStatistics {
            startLiveActivityIfNeeded()
        } else {
            startWatchUpdatesIfNeeded()
        }

        visibility = Visibility(rawValue: defaultVisibilityRaw) ?? .public

        pauseTimer.configure(total: 60)
        pauseTimer.onFinished = {
            NotificationManager1.shared.scheduleWaterReminder(delayMinutes: 0)
        }

        if purchaseManager.hasUnlockedStatistics {
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
    }

    private func handleProChange(_ isPro: Bool) {
        if isPro {
            // Stoppe reinen Watch-Timer und starte Live Activity inkl. kombinierten Updates
            watchUpdateTimer?.invalidate()
            watchUpdateTimer = nil

            if !liveActivityActive {
                LiveActivityManager.shared.startActivity()
                liveActivityActive = true
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
            }
        } else {
            // Beende Live Activity, starte Watch-only Updates
            activityTimer?.invalidate()
            activityTimer = nil
            if liveActivityActive {
                LiveActivityManager.shared.endActivity()
                liveActivityActive = false
            }
            startWatchUpdatesIfNeeded()
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
    let onSelect: (ExerciseInfo) -> Void
    let onInfo: (ExerciseInfo) -> Void
    let onCancel: () -> Void
    let navTitle: String
    let cancelTitle: String
    let searchPlaceholder: String

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            NavigationStack {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(searchPlaceholder, text: $searchText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding(12)
                    .dsField(corner: 12)
                    .padding()

                    List(filteredExercises, id: \.self) { info in
                        HStack {
                            Text(info.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                onInfo(info)
                            } label: {
                                Image(systemName: "info.circle").font(.title3)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Übungsdetails")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(info)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                .navigationTitle(navTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancelTitle) { onCancel() }
                    }
                }
            }
        }
    }
}

private struct PauseTimerSheetModifierWrap: ViewModifier {
    @Environment(\.designTokens) private var t

    @Binding var isPresented: Bool
    @Binding var detent: PresentationDetent
    var timer: PauseTimer

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            PauseTimerSheet(timer: timer, accent: t.palette.primary)
                .presentationDetents(
                    [PresentationDetent.fraction(0.72), PresentationDetent.large],
                    selection: $detent
                )
                // Falls du noch dein enum Visibility im File hast -> unbedingt so qualifizieren:
                .presentationDragIndicator(SwiftUI.Visibility.visible)
                .ignoresSafeArea(SwiftUI.SafeAreaRegions.keyboard)
                .preferredColorScheme(.dark)
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
                    RewardPopup(text: reward.text, icon: reward.icon, color: t.palette.primary)
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
        onFinished?()
    }

    private func runTimer() {
        cancelTimer()
        let startRef = startDate ?? Date()
        let baseElapsed = elapsedBeforePause
        cancellable = Timer.publish(every: 0.05, on: .main, in: .common)
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
    @Environment(\.dismiss) private var dismiss
    var accent: Color = .accentColor   // ✅ neu

    @State private var minutes: Int = 1
    @State private var seconds: Int = 0

    private let presets: [Int] = [30, 45, 60, 90, 120]

    private var clampedProgress: CGFloat {
        max(CGFloat(0.001), min(CGFloat(1), timer.progress))
    }


    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Label("Pause", systemImage: "pause.circle.fill")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)

            content
                .padding(.horizontal)

            footer
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .onAppear {
            if timer.state == .idle {
                minutes = max(0, Int(timer.total) / 60)
                seconds = Int(timer.total) % 60
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch timer.state {
        case .idle:
            idleConfigurator
        case .running, .paused, .finished:
            runningView
        }
    }

    private var idleConfigurator: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { s in
                        Button {
                            minutes = s / 60
                            seconds = s % 60
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
                Picker("Minuten", selection: $minutes) {
                    ForEach(0..<61, id: \.self) { Text("\($0)m").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("Sekunden", selection: $seconds) {
                    ForEach(0..<60, id: \.self) { Text("\($0)s").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 160)
            .dsField(corner: 18)

            Button {
                let total = TimeInterval(minutes * 60 + seconds)
                timer.configure(total: total > 0 ? total : 1)
                timer.start()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
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
                        Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.bordered)
                case .paused:
                    Button { timer.resume() } label: {
                        Label("Weiter", systemImage: "play.fill").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                case .finished:
                    Button { timer.reset() } label: {
                        Label("Zurücksetzen", systemImage: "gobackward").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.bordered)
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
                    Label("Abbrechen", systemImage: "xmark")
                }
            }
            Spacer()
            if timer.state == .finished {
                Button {
                    timer.reset()
                    dismiss()
                } label: {
                    Label("Fertig", systemImage: "checkmark")
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
