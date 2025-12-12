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
                WaitingForPhoneView(status: conn.lastStatus)
            }
        }
        .onAppear { WatchConnectivity.shared.activate() }
    }
}

// MARK: - Waiting Screen

struct WaitingForPhoneView: View {
    let status: String

    var body: some View {
        VStack(spacing: 10) {
            Text("Movo")
                .font(.headline)

            Text("Starte ein Training\nauf dem iPhone")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if status != "—" {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Exercise List (Schritt 1)

struct ExerciseListView: View {
    @StateObject private var conn = WatchConnectivity.shared
    let workoutId: String

    private var payload: ActiveWorkoutPayload { conn.activeWorkout }

    private var sortedExercises: [ActiveWorkoutPayload.ExerciseItem] {
        payload.exercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            if let name = payload.workoutName, !name.isEmpty {
                Text(name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(sortedExercises) { ex in
                NavigationLink {
                    SetListView(
                        workoutId: workoutId,
                        exerciseId: ex.id,
                        workoutName: payload.workoutName
                    )
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.name)
                                .font(.headline)
                                .lineLimit(1)

                            Text("Sets: \(ex.setCount)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .onAppear {
                    if !workoutId.isEmpty {
                        conn.selectExercise(workoutId: workoutId, workoutExerciseId: ex.id)
                    }
                }
            }
        }
        .navigationTitle("Übungen")
    }
}

// MARK: - Set List (Schritt 2)

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
        List {
            if let exercise {
                Section {
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
                            HStack {
                                Text("Satz #\(idx + 1)")
                                    .font(.headline)
                                Spacer()
                                if s.completed {
                                    HStack(spacing: 6) {
                                        Text("\(s.reps)")
                                            .font(.footnote.weight(.semibold))
                                            .monospacedDigit()
                                        Text("reps")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        Text("·")

                                        Text(formatWeight(s.weight))
                                            .font(.footnote.weight(.semibold))
                                            .monospacedDigit()
                                        Text("kg")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .foregroundStyle(.secondary)
                                } else {
                                    Text("—")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    // Neuer Satz
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
                            Text("Neuer Satz")
                        }
                    }
                }
            } else {
                Text("Übung nicht gefunden")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(exercise?.name ?? "Übung")
    }

    private func formatWeight(_ w: Double) -> String {
        let v = (w * 10).rounded() / 10
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - Logger (Schritt 3) – Wheel/Picker UI

enum EditPage: Int, CaseIterable {
    case reps = 0
    case weight = 1
}

struct SetLoggerView: View {
    @StateObject private var conn = WatchConnectivity.shared

    let workoutId: String
    let workoutExerciseId: String
    let exerciseName: String

    // Konkreter Satz (Update) oder nil (Neuanlage)
    let setId: String?
    let initialReps: Int?
    let initialWeight: Double?

    // Optional für Label bei Neuanlage
    var newSetNumber: Int? = nil

    // State: 0/0 als Default
    @State private var reps: Int = 0
    @State private var weight: Double = 0
    @State private var showSavedToast = false

    // Picker-Datenquellen
    private let repsRange: [Int] = Array(0...60)
    private let weightSteps: [Double] = stride(from: 0.0, through: 300.0, by: 2.5).map { $0 }

    private var isUpdatingExisting: Bool { setId != nil }
    private var headerSetLabel: String { "" }

    // Empfehlung: bevorzugt „nächster leerer Satz“ (falls iPhone schon propagiert hat),
    // sonst Fallback: letzter Satz der Übung
    private func recommendedValues(from exercise: ActiveWorkoutPayload.ExerciseItem) -> (reps: Int?, weight: Double?) {
        // Nächster „neuer“ Satz: erster mit reps == 0 UND weight == 0
        if let nextEmpty = exercise.sets.first(where: { $0.reps == 0 && $0.weight == 0 }) {
            // Falls iPhone bereits Werte hinein kopiert hat, sind die > 0; sonst nil = bei 0/0 bleiben
            let r = nextEmpty.reps > 0 ? nextEmpty.reps : nil
            let w = nextEmpty.weight > 0 ? nextEmpty.weight : nil
            return (r, w)
        }
        // Fallback: letzter Satz
        if let last = exercise.sets.last {
            let r = last.reps > 0 ? last.reps : nil
            let w = last.weight > 0 ? last.weight : nil
            return (r, w)
        }
        return (nil, nil)
    }

    private var recommendationText: String? {
        guard let exercise = conn.activeWorkout.exercises.first(where: { $0.id == workoutExerciseId }) else { return nil }
        let (rOpt, wOpt) = recommendedValues(from: exercise)
        let repsPart = rOpt.map { "\($0) reps" }
        let weightPart = wOpt.map { formatWeight($0) + " kg" }
        switch (repsPart, weightPart) {
        case let (r?, w?): return "Empfohlen: \(r) · \(w)"
        case let (r?, nil): return "Empfohlen: \(r)"
        case let (nil, w?): return "Empfohlen: \(w)"
        default: return nil
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            if let recommendationText {
                Text(recommendationText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
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
                            let nearest = (weight / 2.5).rounded()
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
            .frame(height: 120)

            Button {
                saveSet()
            } label: {
                Text(isUpdatingExisting ? "Satz aktualisieren" : "Satz speichern")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if showSavedToast {
                Text(isUpdatingExisting ? "Aktualisiert ✅" : "Gespeichert ✅")
                    .font(.footnote)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 0/0 Basis; falls Startwerte da sind, setze die
            if let r = initialReps, r >= 0 {
                reps = min(max(r, repsRange.first!), repsRange.last!)
            }
            if let w = initialWeight, w >= 0 {
                let stepped = (w / 2.5).rounded() * 2.5
                weight = min(max(stepped, weightSteps.first ?? 0), weightSteps.last ?? 300)
            } else if initialWeight == nil {
                // Empfehlung ins Wheel übernehmen
                if let exercise = conn.activeWorkout.exercises.first(where: { $0.id == workoutExerciseId }) {
                    let (rOpt, wOpt) = recommendedValues(from: exercise)
                    if reps == 0, let r = rOpt { reps = min(max(r, repsRange.first!), repsRange.last!) }
                    if weight == 0, let w = wOpt {
                        let stepped = (w / 2.5).rounded() * 2.5
                        weight = min(max(stepped, weightSteps.first ?? 0), weightSteps.last ?? 300)
                    }
                }
            }
        }
        // WICHTIG: Wenn iPhone die Werte propagiert und die Watch den Payload aktualisiert,
        // dann die Wheel-Voreinstellung automatisch übernehmen, solange Nutzer noch 0/0 hat.
        .onChange(of: conn.activeWorkout) { _ in
            guard setId == nil else { return } // nur für „Neuer Satz“
            if let exercise = conn.activeWorkout.exercises.first(where: { $0.id == workoutExerciseId }) {
                let (rOpt, wOpt) = recommendedValues(from: exercise)
                if reps == 0, let r = rOpt { reps = min(max(r, repsRange.first!), repsRange.last!) }
                if weight == 0, let w = wOpt {
                    let stepped = (w / 2.5).rounded() * 2.5
                    weight = min(max(stepped, weightSteps.first ?? 0), weightSteps.last ?? 300)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(headerSetLabel)
                    .font(.footnote.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Wheel Picker-Baustein

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

    // MARK: - Aktionen

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

        withAnimation(.easeOut(duration: 0.15)) { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.15)) { showSavedToast = false }
        }
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
