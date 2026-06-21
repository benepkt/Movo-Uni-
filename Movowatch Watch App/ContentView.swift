import SwiftUI
import WatchKit

// MARK: - Root

struct ContentView: View {
    @StateObject private var conn = WatchConnectivity.shared

    var body: some View {
        NavigationStack {
            if conn.activeWorkout.isActive {
                ExerciseListView(workoutId: conn.activeWorkout.workoutId ?? "")
            } else {
                WatchStartDashboard(status: conn.lastStatus)
            }
        }
        .overlay {
            if conn.showRestFinishedPopup {
                RestFinishedPopup()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: conn.showRestFinishedPopup)
        .onAppear { WatchConnectivity.shared.activate() }
    }
}

private struct RestFinishedPopup: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.green)
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.black)
            }
            Text("Pause fertig")
                .font(.headline.weight(.black))
            Text("Weiter geht's")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 12)
    }
}

// MARK: - Waiting Screen

struct WatchStartDashboard: View {
    @StateObject private var conn = WatchConnectivity.shared
    let status: String
    private var options: WatchStartOptionsPayload { conn.startOptions }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Movo")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                    Text("Starte ein Training auf dem iPhone, um es hier zu sehen.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)

                if status != "—" {
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.blue.opacity(0.16)))
                }

                if options.planItems.isEmpty && options.templates.isEmpty {
                    EmptyWatchStartCard()
                } else {
                    if let activePlanTitle = options.activePlanTitle, !activePlanTitle.isEmpty {
                        ActivePlanWatchCard(title: activePlanTitle, todaysItem: todaysPlanItem)
                    }
                    if !options.planItems.isEmpty {
                        startSection(title: "Plan", items: options.planItems, tint: .cyan)
                    }
                    if !options.templates.isEmpty {
                        startSection(title: "Templates", items: options.templates, tint: .blue)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        .containerBackground(for: .navigation) {
            LinearGradient(colors: [.black, .blue.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var todaysPlanItem: WatchStartItem? {
        guard let id = options.todaysPlanItemId else { return nil }
        return options.planItems.first(where: { $0.id == id })
    }

    private func startSection(title: String, items: [WatchStartItem], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(items.prefix(5)) { item in
                Button {
                    conn.requestStart(item)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(tint.opacity(0.22))
                            Image(systemName: item.source == .plan ? "calendar.badge.clock" : "doc.text.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(tint)
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.headline.weight(.bold))
                                .lineLimit(1)
                            Text(item.subtitle.isEmpty ? "\(item.exerciseCount) Übungen" : item.subtitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.black))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ActivePlanWatchCard: View {
    @StateObject private var conn = WatchConnectivity.shared
    let title: String
    let todaysItem: WatchStartItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.cyan)
                Text("Aktiver Plan")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(title)
                .font(.headline.weight(.heavy))
                .lineLimit(2)

            if let todaysItem {
                Button {
                    conn.requestStart(todaysItem)
                } label: {
                    Label("Heute starten", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.cyan))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.cyan.opacity(0.24), .blue.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

private struct EmptyWatchStartCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.title2.weight(.bold))
                .foregroundStyle(.blue)
            Text("Noch keine Starts")
                .font(.headline.weight(.bold))
            Text("Starte ein Training auf dem iPhone. Danach erscheint es automatisch auf der Apple Watch.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
    }
}

// MARK: - Exercise List (Step 1)

struct ExerciseListView: View {
    @StateObject private var conn = WatchConnectivity.shared
    let workoutId: String

    private var payload: ActiveWorkoutPayload { conn.activeWorkout }

    private var sortedExercises: [ActiveWorkoutPayload.ExerciseItem] {
        payload.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
            if let rest = payload.restTimer, rest.isActive {
                RestTimerWatchBanner(rest: rest)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(payload.workoutName?.isEmpty == false ? payload.workoutName! : "Training")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .lineLimit(2)
                Text("\(sortedExercises.count) Übungen")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            ForEach(sortedExercises) { ex in
                NavigationLink {
                    SetListView(
                        workoutId: workoutId,
                        exerciseId: ex.id,
                        workoutName: payload.workoutName
                    )
                } label: {
                    HStack {
                        ZStack {
                            Circle().fill(.blue.opacity(0.18))
                            Image(systemName: ex.sets.allSatisfy(\.completed) ? "checkmark" : "dumbbell.fill")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.blue)
                        }
                        .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.name)
                                .font(.headline)
                                .lineLimit(1)

                            Text("\(ex.sets.filter(\.completed).count)/\(ex.setCount) Sets")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .onAppear {
                    if !workoutId.isEmpty {
                        conn.selectExercise(workoutId: workoutId, workoutExerciseId: ex.id)
                    }
                }
            }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        .navigationTitle("")
    }
}

private struct RestTimerWatchBanner: View {
    let rest: ActiveWorkoutPayload.RestTimerState

    private var progress: Double {
        guard rest.total > 0 else { return 0 }
        return max(0, min(1, rest.remaining / rest.total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Pause", systemImage: "timer")
                    .font(.headline)
                Spacer()
                Text(format(rest.remaining))
                    .font(.headline.monospacedDigit())
            }
            ProgressView(value: progress)
                .tint(.blue)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.blue.opacity(0.30), .cyan.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func format(_ interval: TimeInterval) -> String {
        let seconds = Int(max(0, interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Set List (Step 2)

struct SetListView: View {
    @StateObject private var conn = WatchConnectivity.shared

    let workoutId: String
    let exerciseId: String
    let workoutName: String?

    private var exercise: ActiveWorkoutPayload.ExerciseItem? {
        conn.activeWorkout.exercises.first(where: { $0.id == exerciseId })
    }

    private var sets: [ActiveWorkoutPayload.LoggedSetItem] {
        exercise?.sets ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
            if let exercise {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.system(size: 23, weight: .black, design: .rounded))
                        .lineLimit(2)
                    Text("\(sets.filter(\.completed).count)/\(max(1, sets.count)) Sets")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)

                    ForEach(Array(sets.enumerated()), id: \.element.id) { (idx, s) in
                        NavigationLink {
                            SetLoggerView(
                                workoutId: workoutId,
                                workoutExerciseId: exercise.id,
                                exerciseName: exercise.name,
                                setId: s.id,
                                initialReps: s.reps,
                                initialWeight: s.weight
                            )
                        } label: {
                            SetRowCard(index: idx + 1, loggedSet: s)
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        SetLoggerView(
                            workoutId: workoutId,
                            workoutExerciseId: exercise.id,
                            exerciseName: exercise.name,
                            setId: nil,
                            initialReps: nil,
                            initialWeight: nil,
                            newSetNumber: exercise.setCount + 1
                        )
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("New set")
                                .font(.headline.weight(.bold))
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.green.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.green.opacity(0.20), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
            } else {
                Text("Exercise not found")
                    .foregroundStyle(.secondary)
            }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        .navigationTitle("")
    }

    private func formatWeight(_ w: Double) -> String {
        let v = (w * 10).rounded() / 10
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

private struct SetRowCard: View {
    let index: Int
    let loggedSet: ActiveWorkoutPayload.LoggedSetItem

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(loggedSet.completed ? .green.opacity(0.22) : .white.opacity(0.10))
                if loggedSet.completed {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.green)
                } else {
                    Text("\(index)")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Satz \(index)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                if hasValues {
                    Text(valueText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(loggedSet.completed ? .green.opacity(0.10) : .white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(loggedSet.completed ? .green.opacity(0.22) : .white.opacity(0.10), lineWidth: 1)
        )
    }

    private var hasValues: Bool {
        loggedSet.reps > 0 || loggedSet.weight > 0
    }

    private var valueText: String {
        switch (loggedSet.reps > 0, loggedSet.weight > 0) {
        case (true, true): return "\(loggedSet.reps) reps · \(formatWeight(loggedSet.weight)) kg"
        case (true, false): return "\(loggedSet.reps) reps"
        case (false, true): return "\(formatWeight(loggedSet.weight)) kg"
        default: return ""
        }
    }

    private func formatWeight(_ w: Double) -> String {
        let v = (w * 10).rounded() / 10
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - Logger (Step 3) – Wheel/Picker UI

enum EditPage: Int, CaseIterable {
    case reps = 0
    case weight = 1
}

struct SetLoggerView: View {
    @StateObject private var conn = WatchConnectivity.shared

    let workoutId: String
    let workoutExerciseId: String
    let exerciseName: String   // wird im Header nicht mehr gezeigt

    // Existing set (update) or nil (new)
    let setId: String?
    let initialReps: Int?
    let initialWeight: Double?

    // Optional label for new set
    var newSetNumber: Int? = nil

    // State defaults
    @State private var reps: Int = 0
    @State private var weight: Double = 0

    // Picker data sources
    private let repsRange: [Int] = Array(0...60)
    private let weightSteps: [Double] = stride(from: 0.0, through: 300.0, by: 1.0).map { $0 }

    private var isUpdatingExisting: Bool { setId != nil }

    private var setNumberForHeader: Int? {
        if let newSetNumber { return newSetNumber }
        guard
            let setId,
            let exercise = conn.activeWorkout.exercises.first(where: { $0.id == workoutExerciseId }),
            let idx = exercise.sets.firstIndex(where: { $0.id == setId })
        else { return nil }
        return idx + 1
    }

    private var headerSetLabel: String? {
        guard let n = setNumberForHeader else { return nil }
        return "Set \(n)"
    }

    private func lastValues(from exercise: ActiveWorkoutPayload.ExerciseItem) -> (reps: Int?, weight: Double?) {
        if let nextEmpty = exercise.sets.first(where: { $0.reps == 0 && $0.weight == 0 }) {
            let r = nextEmpty.reps > 0 ? nextEmpty.reps : nil
            let w = nextEmpty.weight > 0 ? nextEmpty.weight : nil
            return (r, w)
        }
        if let last = exercise.sets.last {
            let r = last.reps > 0 ? last.reps : nil
            let w = last.weight > 0 ? last.weight : nil
            return (r, w)
        }
        return (nil, nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header

                HStack(spacing: 8) {
                    metricPreview(title: "Reps", value: "\(reps)")
                    metricPreview(title: "Gewicht", value: "\(formatWeight(weight)) kg")
                }

                HStack(spacing: 8) {
                    wheelPicker(
                        title: "REPS",
                        items: repsRange.map { "\($0)" },
                        selectionIndex: Binding(
                            get: { max(0, min(repsRange.count - 1, reps)) },
                            set: { idx in
                                reps = repsRange[max(0, min(repsRange.count - 1, idx))]
                                WKInterfaceDevice.current().play(.click)
                            }
                        )
                    )

                    wheelPicker(
                        title: "KG",
                        items: weightSteps.map { formatWeight($0) },
                        selectionIndex: Binding(
                            get: {
                                let nearest = weight.rounded()
                                return Int(max(0, min(nearest, Double(weightSteps.count - 1))))
                            },
                            set: { idx in
                                let safe = max(0, min(weightSteps.count - 1, idx))
                                weight = weightSteps[safe]
                                WKInterfaceDevice.current().play(.click)
                            }
                        )
                    )
                }
                .frame(height: 128)

                Button {
                    saveSet()
                } label: {
                    Label(isUpdatingExisting ? "Aktualisieren" : "Speichern", systemImage: "checkmark")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .cyan.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Satz")
        .containerBackground(for: .navigation) {
            LinearGradient(colors: [.black, .blue.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .onAppear {
            if let r = initialReps, r >= 0 {
                reps = min(max(r, repsRange.first!), repsRange.last!)
            }

            if let w = initialWeight, w >= 0 {
                let stepped = w.rounded()
                weight = min(max(stepped, weightSteps.first ?? 0), weightSteps.last ?? 300)
            } else if initialWeight == nil {
                if let exercise = conn.activeWorkout.exercises.first(where: { $0.id == workoutExerciseId }) {
                    let (rOpt, wOpt) = lastValues(from: exercise)
                    if reps == 0, let r = rOpt { reps = min(max(r, repsRange.first!), repsRange.last!) }
                    if weight == 0, let w = wOpt {
                        let stepped = w.rounded()
                        weight = min(max(stepped, weightSteps.first ?? 0), weightSteps.last ?? 300)
                    }
                }
            }
        }
        .onChange(of: conn.activeWorkout) { _ in
            guard setId == nil else { return } // only for "New set"
            if let exercise = conn.activeWorkout.exercises.first(where: { $0.id == workoutExerciseId }) {
                let (rOpt, wOpt) = lastValues(from: exercise)
                if reps == 0, let r = rOpt { reps = min(max(r, repsRange.first!), repsRange.last!) }
                if weight == 0, let w = wOpt {
                    let stepped = w.rounded()
                    weight = min(max(stepped, weightSteps.first ?? 0), weightSteps.last ?? 300)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let headerSetLabel {
                Text(headerSetLabel)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.blue.opacity(0.18)))
            }
            Text(exerciseName)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [.blue.opacity(0.22), .white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func metricPreview(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.black))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Wheel Picker

    private func wheelPicker(title: String, items: [String], selectionIndex: Binding<Int>) -> some View {
        GeometryReader { _ in
            let rowHeight: CGFloat = 28

            ZStack {
                Picker("", selection: selectionIndex) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(height: rowHeight)
                    }
                }
                .pickerStyle(.wheel)

                VStack {
                    Spacer()
                    ZStack {
                        Capsule()
                            .fill(Color.accentColor)
                        HStack {
                            Spacer(minLength: 0)
                            Text(items[safe: selectionIndex.wrappedValue] ?? "")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: rowHeight + 8)
                    Spacer()
                }
                .allowsHitTesting(false)

                VStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Actions

    private func saveSet() {
        guard !workoutId.isEmpty else { return }
        let r = max(0, reps)
        let w = max(0, weight)

        if let setId = setId, !setId.isEmpty {
            conn.updateSet(
                workoutId: workoutId,
                workoutExerciseId: workoutExerciseId,
                setId: setId,
                reps: r,
                weight: w
            )
        } else {
            conn.logSet(
                workoutId: workoutId,
                workoutExerciseId: workoutExerciseId,
                reps: r,
                weight: w
            )
        }

        WKInterfaceDevice.current().play(.success)
    }

    private func formatWeight(_ w: Double) -> String {
        let v = (w * 10).rounded() / 10
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - Safe index helper
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
