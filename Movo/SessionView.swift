import SwiftUI
import Combine
import UIKit

// MARK: - HowToDB Helper (erste Lottie pro Übung finden)
extension HowToDB {
    static func firstLottie(for name: String)
        -> (source: LottieSource, fill: Bool, aspect: CGFloat)?
    {
        let (_, blocks) = blocks(for: name)
        for b in blocks {
            if case let .lottie(_, src, fill, aspect) = b { return (src, fill, aspect) }
        }
        return nil
    }
}

// MARK: - Phase
enum Phase { case ready, exercise, rest, finished }

// MARK: - TimerManager (Runden & Circuit)
final class TimerManager: ObservableObject {
    // Öffentlich beobachtbar
    @Published var timeRemaining: Double = 0
    @Published var progress: CGFloat = 1.0
    @Published var phase: Phase = .ready
    @Published var currentIndex: Int = 0
    @Published var currentRound: Int = 0
    @Published var totalRounds: Int = 2
    @Published var progressAnimationEnabled: Bool = true
    @Published var isPaused: Bool = false

    // Daten
    public var allExercises: [Exercise] = []

    // Timer intern
    private var timerCancellable: AnyCancellable?
    fileprivate var startTime: Date?
    fileprivate var durationSeconds: Int = 0
    private var pausedTimeRemaining: Double?

    // Konfiguration (~15 Min bei 5 Übungen × 3 Runden)
    private let targetTotalSeconds: Int = 900
    private let exerciseSeconds: Int = 35
    private let restBetweenExercisesSeconds: Int = 20
    private let restBetweenRoundsSeconds: Int = 45

    // Persistenz – namespaced pro Unit/Week
    private let defaultsIndexKey: String
    private let defaultsRoundKey: String
    private let defaultsTimeKey: String
    private let defaultsPhaseKey: String

    // Speicher throttlen
    private var lastSavedWholeSecond: Int = -1

    // Callback – setzt Sets der Übung als erledigt (nur in letzter Runde)
    var markExerciseInBoundWeek: ((_ exerciseIndex: Int) -> Void)?

    // MARK: - Init
    init(warmUp: [Exercise], exercises: [Exercise], coolDown: [Exercise], persistNamespace: String = "session") {
        self.allExercises = warmUp + exercises + coolDown

        self.defaultsIndexKey = "\(persistNamespace)_currentExerciseIndex"
        self.defaultsRoundKey = "\(persistNamespace)_currentRound"
        self.defaultsTimeKey  = "\(persistNamespace)_timeRemaining"
        self.defaultsPhaseKey = "\(persistNamespace)_phase"

        // Runden basierend auf Zielzeit
        let exCount = max(allExercises.count, 1)
        let oneRound = (exCount * exerciseSeconds)
                     + ((exCount - 1) * restBetweenExercisesSeconds)
                     + restBetweenRoundsSeconds
        let computedRounds = max(2, Int(ceil(Double(targetTotalSeconds) / Double(max(1, oneRound)))))
        self.totalRounds = computedRounds

        // Restore
        let savedIndex = UserDefaults.standard.object(forKey: defaultsIndexKey) as? Int
        let savedRound = UserDefaults.standard.object(forKey: defaultsRoundKey) as? Int
        let savedTime  = UserDefaults.standard.object(forKey: defaultsTimeKey) as? Double
        let savedPhase = UserDefaults.standard.object(forKey: defaultsPhaseKey) as? String

        // Falls jemals "finished" gespeichert wurde, sofort sauber resetten.
        if savedPhase == "finished" {
            clearSavedProgress()
        }

        if let si = savedIndex, let sr = savedRound, let st = savedTime,
           si >= 0, si < self.allExercises.count, sr >= 0, sr < self.totalRounds {

            self.currentIndex  = si
            self.currentRound  = sr
            self.timeRemaining = max(0, st)

            if savedPhase == "exercise" { self.phase = .exercise }
            else if savedPhase == "rest" { self.phase = .rest }
            else { self.phase = .ready }

            if (self.phase == .exercise || self.phase == .rest) && self.timeRemaining == 0 {
                self.timeRemaining = 0.5
            }

            let denom: Double = (self.phase == .rest)
                ? Double(restBetweenExercisesSeconds)
                : Double(exerciseSeconds)
            self.progress = CGFloat(self.timeRemaining / max(1, denom))

        } else {
            self.currentIndex = 0
            self.currentRound = 0
            self.timeRemaining = 0
            self.progress = 1.0
            self.phase = .ready
            clearSavedProgress()
        }
    }

    // MARK: - Public Control
    func startWorkout() {
        guard !allExercises.isEmpty else {
            phase = .finished // wird nicht persistiert, persistState filtert
            persistState()
            return
        }
        phase = .exercise
        startExercise()
    }

    func pause() {
        guard !isPaused, phase != .finished, phase != .ready else { return }
        isPaused = true
        pausedTimeRemaining = timeRemaining
        timerCancellable?.cancel()
        timerCancellable = nil
        persistState()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        let remaining = pausedTimeRemaining ?? timeRemaining
        startTimer(for: Int(ceil(remaining)))
    }

    func addTime(_ seconds: Int) {
        guard phase == .exercise || phase == .rest else { return }
        timeRemaining += Double(seconds)
        startTime = Date().addingTimeInterval(-Double(durationSeconds) + timeRemaining)
        persistState()
    }

    func skipCurrent() {
        timerCancellable?.cancel(); timerCancellable = nil
        if phase == .rest {
            goToNextAfterRest()
        } else {
            goToNextAfterExercise(markAsCompleted: false)
        }
        persistState()
    }

    func cancel() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // Sofortiges Beenden mit Statistik
    @discardableResult
    func finishNow() -> (completedStations: Int, totalStations: Int, completedRounds: Int) {
        timerCancellable?.cancel()
        timerCancellable = nil

        let totalStations = allExercises.count * totalRounds
        let completedRounds = currentRound

        let doneInCurrentRound: Int
        switch phase {
        case .rest:     doneInCurrentRound = min(currentIndex + 1, allExercises.count)
        case .exercise: doneInCurrentRound = min(currentIndex,     allExercises.count)
        default:        doneInCurrentRound = 0
        }

        let completedStations = completedRounds * allExercises.count + doneInCurrentRound

        phase = .finished
        persistState()      // persistState speichert "finished" NICHT
        clearSavedProgress()
        return (completedStations, totalStations, completedRounds)
    }

    // MARK: - Intern: Start & Timer
    private func startExercise() {
        phase = .exercise
        timeRemaining = Double(exerciseSeconds)
        progress = 1.0
        startTimer(for: exerciseSeconds)
        persistState()
    }

    private func startRest(betweenRounds: Bool) {
        guard restBetweenExercisesSeconds > 0 || betweenRounds else {
            betweenRounds ? startNextRoundOrFinish() : startNextExerciseOrRound()
            return
        }
        phase = .rest
        let seconds = betweenRounds ? restBetweenRoundsSeconds : restBetweenExercisesSeconds
        timeRemaining = Double(seconds)
        progress = 1.0
        startTimer(for: seconds)
        persistState()
    }

    private func startTimer(for seconds: Int) {
        timerCancellable?.cancel()
        timerCancellable = nil

        progressAnimationEnabled = false
        durationSeconds = seconds
        startTime = Date()
        if timeRemaining <= 0 { timeRemaining = Double(seconds) }
        progress = CGFloat(timeRemaining) / CGFloat(max(1, durationSeconds))

        DispatchQueue.main.async { [weak self] in self?.progressAnimationEnabled = true }

        timerCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.startTime, !self.isPaused else { return }

                let elapsed   = Date().timeIntervalSince(start)
                let remaining = max(Double(self.durationSeconds) - elapsed, 0)

                self.timeRemaining = remaining
                self.progress      = CGFloat(remaining) / CGFloat(max(1, self.durationSeconds))

                let whole = Int(self.timeRemaining.rounded(.down))
                if whole != self.lastSavedWholeSecond {
                    self.lastSavedWholeSecond = whole
                    self.persistState()
                }

                if remaining <= 0 {
                    self.timerCancellable?.cancel()
                    self.timerCancellable = nil
                    self.advancePhase()
                }
            }
    }

    private func persistState() {
        // Niemals "finished" speichern – sonst startet die View immer im CompletionView.
        if phase == .finished {
            clearSavedProgress()
            return
        }

        UserDefaults.standard.set(currentIndex, forKey: defaultsIndexKey)
        UserDefaults.standard.set(currentRound, forKey: defaultsRoundKey)
        UserDefaults.standard.set(timeRemaining, forKey: defaultsTimeKey)

        let phs: String
        switch phase {
        case .exercise: phs = "exercise"
        case .rest:     phs = "rest"
        case .ready:    phs = "ready"
        case .finished: phs = "other"
        }
        UserDefaults.standard.set(phs, forKey: defaultsPhaseKey)
    }

    private func clearSavedProgress() {
        UserDefaults.standard.removeObject(forKey: defaultsIndexKey)
        UserDefaults.standard.removeObject(forKey: defaultsRoundKey)
        UserDefaults.standard.removeObject(forKey: defaultsTimeKey)
        UserDefaults.standard.removeObject(forKey: defaultsPhaseKey)
        lastSavedWholeSecond = -1
    }

    // MARK: - Advance-Logik
    private func advancePhase() {
        switch phase {
        case .exercise:
            // Übung beendet → Sets nur in der letzten Runde als erledigt markieren
            goToNextAfterExercise(markAsCompleted: (currentRound == totalRounds - 1))
        case .rest:
            goToNextAfterRest()
        case .ready:
            startExercise()
        case .finished:
            break
        }
        persistState()
    }

    private func goToNextAfterExercise(markAsCompleted: Bool) {
        if markAsCompleted, currentIndex < allExercises.count {
            for i in 0..<allExercises[currentIndex].sets.count {
                allExercises[currentIndex].sets[i].isCompleted = true
            }
            DispatchQueue.main.async { self.markExerciseInBoundWeek?(self.currentIndex) }
        }

        // Nächster Schritt: kurze Pause oder Rundenpause
        if currentIndex < allExercises.count - 1 {
            startRest(betweenRounds: false)
        } else {
            startRest(betweenRounds: true)
        }
    }

    private func goToNextAfterRest() {
        if currentIndex < allExercises.count - 1 {
            currentIndex += 1
            startExercise()
        } else {
            startNextRoundOrFinish()
        }
    }

    private func startNextExerciseOrRound() {
        if currentIndex < allExercises.count - 1 {
            currentIndex += 1
            startExercise()
        } else {
            startNextRoundOrFinish()
        }
    }

    private func startNextRoundOrFinish() {
        if currentRound < totalRounds - 1 {
            currentRound += 1
            currentIndex = 0
            startExercise()
        } else {
            phase = .finished
            persistState()     // wird nicht gespeichert, siehe persistState()
            clearSavedProgress()
        }
    }
}

// === Planungshilfe ===
fileprivate struct PlannedSession {
    let rounds: Int
    let totalSeconds: Int
}

fileprivate enum WorkoutPlanner {
    private static let targetTotalSeconds = 900
    private static let exerciseSeconds = 35
    private static let restBetweenExercisesSeconds = 20
    private static let restBetweenRoundsSeconds = 45

    static func planned(for week: Week) -> PlannedSession {
        let exCount = max((week.warmUp + week.exercises + week.coolDown).count, 1)
        let perRound = exCount * exerciseSeconds
                     + max(0, exCount - 1) * restBetweenExercisesSeconds
        let approxPerRoundWithLongRest = perRound + restBetweenRoundsSeconds
        let rounds = max(2, Int(ceil(
            Double(targetTotalSeconds + restBetweenRoundsSeconds) /
            Double(max(1, approxPerRoundWithLongRest))
        )))
        let totalSeconds = rounds * perRound + max(0, rounds - 1) * restBetweenRoundsSeconds
        return PlannedSession(rounds: rounds, totalSeconds: totalSeconds)
    }
}

// MARK: - SessionView (mit Inline-Technikclip)
struct SessionView: View {
    @Binding var week: Week
    @StateObject private var timerManager: TimerManager

    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var challengeStore: ChallengeStore
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings

    let unitId: UUID

    @State private var didComplete: Bool = false
    @State private var rewardMessage: RewardMessage? = nil
    @State private var isPaused: Bool = false

    // Stats vom Sofort-Beenden (optional)
    @State private var completedStations: Int = 0
    @State private var totalStations: Int = 0

    // How-to Sheet State
    @State private var showHowTo: Bool = false
    @State private var howToTitle: String = ""
    @State private var howToBlocks: [HowToContent] = []

    init(week: Binding<Week>, unitId: UUID) {
        self._week = week
        self.unitId = unitId

        let ns = "session_\(unitId.uuidString)_week_\(week.wrappedValue.number)"
        let manager = TimerManager(
            warmUp: week.wrappedValue.warmUp,
            exercises: week.wrappedValue.exercises,
            coolDown: week.wrappedValue.coolDown,
            persistNamespace: ns
        )
        _timerManager = StateObject(wrappedValue: manager)
    }

    var body: some View {
        ZStack { Color(.systemBackground).ignoresSafeArea() }
            .overlay(
                ScrollView {
                    VStack(spacing: 16) {
                        if timerManager.phase != .finished {
                            PhaseChip(title: phaseTitle())
                                .padding(.top, 8)
                        }

                        WorkoutProgressBar(progress: CGFloat(timerManager.progress))
                            .padding(.horizontal)

                        // === EXERCISE ===
                        if timerManager.phase == .exercise,
                           timerManager.currentIndex < timerManager.allExercises.count {
                            let exercise = timerManager.allExercises[timerManager.currentIndex]
                            let hasHowTo = HowToDB.hasEntry(for: exercise.name)
                            let lottie = HowToDB.firstLottie(for: exercise.name) // ⬅️ Clip holen

                            ExerciseCard(
                                title: exercise.name,
                                timeRemaining: Int(timerManager.timeRemaining),
                                nextTitle: nextLabel(),
                                roundInfo: (timerManager.currentRound + 1, timerManager.totalRounds),
                                setCount: exercise.sets.count,
                                completedCount: exercise.sets.filter { $0.isCompleted }.count,
                                showInfo: hasHowTo,
                                onInfo: {
                                    (howToTitle, howToBlocks) = HowToDB.blocks(for: exercise.name)
                                    showHowTo = true
                                },
                                onSkip: { timerManager.skipCurrent() },
                                lottie: lottie // ⬅️ NEU: Inline-Technikclip
                            )
                            .padding(.horizontal)
                        }

                        // === REST ===
                        if timerManager.phase == .rest {
                            let nextName: String? = {
                                // nächste Übung in dieser Runde …
                                if timerManager.currentIndex < timerManager.allExercises.count - 1 {
                                    return timerManager.allExercises[timerManager.currentIndex + 1].name
                                }
                                // … oder erste Übung der nächsten Runde (falls es weitergeht)
                                else if timerManager.currentRound < timerManager.totalRounds - 1 {
                                    return timerManager.allExercises.first?.name
                                }
                                return nil
                            }()

                            let hasNextHowTo = nextName.map { HowToDB.hasEntry(for: $0) } ?? false

                            RestCard(
                                title: restTitle(),
                                timeRemaining: Int(timerManager.timeRemaining),
                                roundInfo: (timerManager.currentRound + 1, timerManager.totalRounds),
                                nextTitle: nextName,                       // ⬅️ nur Name anzeigen
                                showNextInfo: hasNextHowTo,               // ⬅️ Info-Button optional
                                onNextInfo: {
                                    if let n = nextName {
                                        (howToTitle, howToBlocks) = HowToDB.blocks(for: n)
                                        showHowTo = true
                                    }
                                },
                                onSkip: { timerManager.skipCurrent() }
                            )
                            .padding(.horizontal)
                        }


                        if timerManager.phase == .ready {
                            PrimaryCTA(title: appSettings.localized("workout.start")) {
                                timerManager.startWorkout()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        }

                        if timerManager.phase == .finished {
                            CompletionView { feedback, rating in
                                handleCompletion(feedback: feedback, rating: rating)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 120)
                }
            )
            .safeAreaInset(edge: .bottom) {
                if timerManager.phase == .exercise || timerManager.phase == .rest,
                   timerManager.currentIndex < timerManager.allExercises.count || timerManager.phase == .rest {
                    ControlBar(
                        onPauseToggle: {
                            if isPaused { timerManager.resume() } else { timerManager.pause() }
                            isPaused.toggle()
                        },
                        isPaused: isPaused,
                        onAddTime: { timerManager.addTime(15) },
                        onFinish: {
                            let stats = timerManager.finishNow()
                            completedStations = stats.completedStations
                            totalStations     = stats.totalStations
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
            .onAppear {
                // Wenn ein "fertiger" Manager reused wird, auf ready zurücksetzen.
                if timerManager.phase == .finished {
                    timerManager.cancel()
                    timerManager.phase = .ready
                    timerManager.timeRemaining = 0
                    timerManager.progress = 1
                }

                // Sets in die Week spiegeln, WENN die Übung in der letzten Runde beendet wurde
                timerManager.markExerciseInBoundWeek = { [weak timerManager] finalExerciseIdx in
                    guard let _ = timerManager else { return }
                    let idx = finalExerciseIdx
                    if idx < week.warmUp.count {
                        for s in 0..<week.warmUp[idx].sets.count { week.warmUp[idx].sets[s].isCompleted = true }
                    } else if idx < week.warmUp.count + week.exercises.count {
                        let ex = idx - week.warmUp.count
                        if ex >= 0 && ex < week.exercises.count {
                            for s in 0..<week.exercises[ex].sets.count { week.exercises[ex].sets[s].isCompleted = true }
                        }
                    } else {
                        let cd = idx - week.warmUp.count - week.exercises.count
                        if cd >= 0 && cd < week.coolDown.count {
                            for s in 0..<week.coolDown[cd].sets.count { week.coolDown[cd].sets[s].isCompleted = true }
                        }
                    }
                    challengeStore.saveWeekProgress(week, unitId: unitId)
                }
            }
            // Autosave: sobald die Session endet (Timeout ODER finishNow)
            .onChange(of: timerManager.phase) { newPhase in
                guard newPhase == .finished, !didComplete else { return }
                handleCompletion()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onDisappear { timerManager.cancel() }
            // How-to Sheet
            .sheet(isPresented: $showHowTo) {
                HowToSheet(title: howToTitle, blocks: howToBlocks)
            }
    }

    // MARK: - Titel/Labels
    private func phaseTitle() -> String {
        switch timerManager.phase {
        case .ready: return appSettings.localized("warmup")
        case .exercise:
            let exNumber = timerManager.currentIndex + 1
            let roundStr = String(format: appSettings.localized("round.number"), timerManager.currentRound + 1, timerManager.totalRounds)
            let exStr = String(format: appSettings.localized("exercise.number"), exNumber)
            return "\(roundStr) · \(exStr)"
        case .rest:
            return appSettings.localized("rest")
        case .finished:
            return appSettings.localized("cooldown")
        }
    }

    private func restTitle() -> String {
        if timerManager.currentIndex < timerManager.allExercises.count - 1 {
            return appSettings.localized("rest")
        } else {
            return String(format: appSettings.localized("round.next"), timerManager.currentRound + 2)
        }
    }

    private func nextLabel() -> String? {
        if timerManager.currentIndex < timerManager.allExercises.count - 1 {
            let next = timerManager.allExercises[timerManager.currentIndex + 1].name
            return String(format: appSettings.localized("next.exercise"), next)
        } else if timerManager.currentRound < timerManager.totalRounds - 1 {
            let first = timerManager.allExercises.first?.name ?? ""
            return String(format: appSettings.localized("next.round.exercise"), timerManager.currentRound + 2, first)
        } else {
            return nil
        }
    }

    // MARK: - Abschluss
    private func handleCompletion(feedback: String = "", rating: Int = 0) {
        guard !didComplete else { return }
        didComplete = true

        // Safety-Net: Alle Sets der Week als erledigt markieren
        for i in 0..<week.warmUp.count {
            for j in 0..<week.warmUp[i].sets.count { week.warmUp[i].sets[j].isCompleted = true }
        }
        for i in 0..<week.exercises.count {
            for j in 0..<week.exercises[i].sets.count { week.exercises[i].sets[j].isCompleted = true }
        }
        for i in 0..<week.coolDown.count {
            for j in 0..<week.coolDown[i].sets.count { week.coolDown[i].sets[j].isCompleted = true }
        }

        // Persistieren
        challengeStore.saveWeekProgress(week, unitId: unitId)

        // Trainingseintrag (einmal pro Tag/Week) — mit Unit-Namen im Titel
        let today = Date()

        let unitName = challengeStore.trainingUnits
            .first(where: { $0.id == unitId })?
            .title(using: appSettings) ?? ""

        let weekTitleLocalized = String(format: appSettings.localized("week.number"), week.number) // z. B. "Woche %d"
        let entryTitle = unitName.isEmpty ? weekTitleLocalized : "\(unitName) – \(weekTitleLocalized)"

        let alreadyExists = trainingStore.history.contains { entry in
            entry.title == entryTitle && Calendar.current.isDate(entry.date, inSameDayAs: today)
        }

        if !alreadyExists {
            let allStations = week.warmUp + week.exercises + week.coolDown
            let plan = WorkoutPlanner.planned(
                for: Week(number: week.number, warmUp: week.warmUp, exercises: week.exercises, coolDown: week.coolDown)
            )

            let entry = TrainingEntry(
                date: today,
                title: entryTitle, // <-- sprechender Titel inkl. Unit
                exercises: allStations,
                duration: TimeInterval(plan.totalSeconds),
                totalWeight: nil
            )
            DispatchQueue.main.async { trainingStore.add(entry: entry) }
        }

        // Gamification
        gm.addXP(100); gm.addCoins(20); gm.updateStreak()
        gm.unlockBadge(.firstWorkout)
        if gm.streak == 7 { gm.unlockBadge(.streak7) }

        withAnimation(.spring()) {
            rewardMessage = RewardMessage(text: "+100 XP & +20 Coins", icon: "star.fill", color: .blue)
        }
    }

    // MARK: - Subviews
    private struct PhaseChip: View {
        let title: String
        var body: some View {
            Label { Text(title).font(.subheadline.bold()) }
                icon: { Image(systemName: "bolt.fill") }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.9)))
                .foregroundColor(.white)
        }
    }

    private struct WorkoutProgressBar: View {
        let progress: CGFloat
        var body: some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.25)).frame(height: 10)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * progress)), height: 10)
                }
            }
            .frame(height: 10)
        }
    }

    private struct ExerciseCard: View {
        @EnvironmentObject var appSettings: AppSettings
        let title: String
        let timeRemaining: Int
        let nextTitle: String?
        let roundInfo: (current: Int, total: Int)
        let setCount: Int
        let completedCount: Int
        let showInfo: Bool
        var onInfo: () -> Void = {}
        var onSkip: () -> Void

        // ⬇️ optionaler Lottie-Clip
        let lottie: (source: LottieSource, fill: Bool, aspect: CGFloat)?

        @State private var pulse = false
        @State private var showClip = true

        var body: some View {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.title2.bold())
                        Text(String(format: appSettings.localized("round.of"), roundInfo.current, roundInfo.total))
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    Spacer()
                    if showInfo {
                        Button(action: {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            onInfo()
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .accessibilityLabel("Anleitung anzeigen")
                        .buttonStyle(.plain)
                    }
                }

                // Technik-Clip (ein-/ausklappbar)
                if let clip = lottie, showClip {
                    VStack(spacing: 8) {
                        LottieBlockView(source: clip.source, fill: clip.fill, aspect: clip.aspect)
                            .frame(maxHeight: 220)
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { showClip = false }
                        } label: {
                            Label("Clip ausblenden", systemImage: "chevron.down.circle")
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                } else if lottie != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showClip = true }
                    } label: {
                        Label("Technik-Clip zeigen", systemImage: "play.circle")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                // Countdown
                ZStack {
                    Circle().strokeBorder(Color.gray.opacity(0.2), lineWidth: 16).frame(width: 180, height: 180)
                    Circle().fill(Color.accentColor.opacity(0.15))
                        .frame(width: pulse ? 210 : 190, height: pulse ? 210 : 190)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                    Text("\(timeRemaining)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .onAppear { pulse = true }

                // Runden-Dots
                HStack(spacing: 8) {
                    ForEach(0..<roundInfo.total, id: \.self) { i in
                        Circle()
                            .fill(i < roundInfo.current ? Color.accentColor : Color.gray.opacity(0.25))
                            .frame(width: 10, height: 10)
                    }
                }

                // Set-Dots
                if setCount > 0 {
                    HStack(spacing: 8) {
                        ForEach(0..<setCount, id: \.self) { i in
                            Circle().fill(i < completedCount ? Color.accentColor : Color.gray.opacity(0.25))
                                .frame(width: 14, height: 14)
                        }
                    }
                }

                if let next = nextTitle {
                    Label(next, systemImage: "arrow.right.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }

                Button(action: onSkip) {
                    Text(appSettings.localized("exercise.skip"))
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.08)))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
            )
        }
    }

    private struct RestCard: View {
        @EnvironmentObject var appSettings: AppSettings
        let title: String
        let timeRemaining: Int
        let roundInfo: (current: Int, total: Int)

        // Neu: nur der Name der nächsten Übung
        let nextTitle: String?

        // Optionaler Info-Button (öffnet HowTo-Sheet)
        let showNextInfo: Bool
        var onNextInfo: () -> Void = {}

        var onSkip: () -> Void

        @Environment(\.colorScheme) private var scheme
        @State private var breathe = false

        private let lines = [
            "Deep breath. You’ve got this.",
            "Small break, big win.",
            "Reset. Stay smooth.",
            "Inhale calm, exhale power."
        ]
        private var line: String {
            let idx = (roundInfo.current + timeRemaining) % lines.count
            return lines[abs(idx)]
        }

        var body: some View {
            VStack(spacing: 18) {
                // Kopf
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.title2.bold())
                        Text(String(format: appSettings.localized("round.of"),
                                    roundInfo.current, roundInfo.total))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if showNextInfo {
                        Button(action: {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            onNextInfo()
                        }) {
                            Image(systemName: "info.circle").font(.title3)
                        }
                        .accessibilityLabel("Anleitung zur nächsten Übung")
                        .buttonStyle(.plain)
                    }
                }

                // Glas-Timer
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 10)

                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(scheme == .dark ? 0.20 : 0.22),
                            .clear
                        ]),
                        center: .center, startRadius: 6, endRadius: 160
                    )
                    .allowsHitTesting(false)

                    Text("\(timeRemaining)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .onAppear { breathe = true }

                // Nur Text: „Als Nächstes: <Übungsname>“
                if let next = nextTitle {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                        Text("Als Nächstes")
                            .font(.subheadline.weight(.semibold))
                        Text(next)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }

                // kurze Line
                Text(line)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // Skip
                Button(action: onSkip) {
                    Text(appSettings.localized("skip.rest"))
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            }
            .padding(18)
            .background(Color.clear)
        }
    }

    private struct ControlBar: View {
        @EnvironmentObject var appSettings: AppSettings
        var onPauseToggle: () -> Void
        var isPaused: Bool
        var onAddTime: () -> Void
        var onFinish: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                Button(action: onPauseToggle) {
                    Label(isPaused ? appSettings.localized("resume") : appSettings.localized("pause"),
                          systemImage: isPaused ? "play.fill" : "pause.fill")
                        .font(.callout.bold())
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
                }
                Button(action: onAddTime) {
                    Label(appSettings.localized("add.time"), systemImage: "plus.circle.fill")
                        .font(.callout.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange))
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                }
                Button(action: onFinish) {
                    Text(appSettings.localized("finish"))
                        .font(.callout.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
                }
            }
        }
    }

    private struct PrimaryCTA: View {
        let title: String
        var action: () -> Void
        var body: some View {
            Button(action: action) {
                Text(title)
                    .bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(20)
            }
        }
    }
}

// MARK: - CompletionView & RewardRow
struct CompletionView: View {
    @EnvironmentObject var appSettings: AppSettings
    let onComplete: (_ feedback: String, _ rating: Int) -> Void

    @State private var feedback: String = ""
    @State private var rating: Int = 0
    @State private var didSave = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.yellow)

                    Text(appSettings.localized("workout.complete"))
                        .font(.title.bold())
                    Text(appSettings.localized("week.complete"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: rating >= star ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundColor(.yellow)
                            .onTapGesture { rating = star }
                    }
                }

                TextField(
                    "",
                    text: $feedback,
                    prompt: Text(appSettings.localized("feedback.placeholder")).foregroundColor(.secondary)
                )
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .foregroundColor(.primary)
                .padding(.horizontal)

                VStack(spacing: 12) {
                    RewardRow(icon: "star.fill", color: .blue,   text: "+100 XP")
                    RewardRow(icon: "bitcoinsign.circle.fill", color: .orange, text: "+20 Coins")
                }

                Button {
                    onComplete(feedback, rating)
                    withAnimation { didSave = true }
                } label: {
                    Text(didSave ? appSettings.localized("saved") : appSettings.localized("save"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(didSave ? Color.green : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .disabled(didSave)
            }
        }
    }
}

struct RewardRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            Text(text)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
