import Foundation
import Combine
import ActivityKit

extension Notification.Name {
    static let didCompleteSet = Notification.Name("training.didCompleteSet")
}

class TrainingSessionManager: ObservableObject {
    @Published var isTrainingActive = false
    @Published var startTime: Date?
    @Published var elapsedTime: TimeInterval = 0.0
    @Published var exercises: [Exercise] = []
    @Published var activities: [WorkoutActivityBlock] = []
    @Published var trainingTitle: String = ""
    @Published var completedExercises: Int = 0
    @Published var totalWeightLifted: Double = 0.0
    @Published var workoutStartSource: String = "quick_start"
    @Published var workoutTemplateId: String?
    @Published var workoutHasActivePlan: Bool = false

    private var timer: Timer?

    // MARK: - Resume Snapshot (nested)
    struct ResumeSnapshot: Codable {
        var title: String
        var startedAt: Date
        var elapsed: TimeInterval
        var exercises: [Exercise]
        var activities: [WorkoutActivityBlock]
        var startSource: String
        var templateId: String?
        var hasActivePlan: Bool

        enum CodingKeys: String, CodingKey {
            case title, startedAt, elapsed, exercises, activities, startSource, templateId, hasActivePlan
        }

        init(
            title: String,
            startedAt: Date,
            elapsed: TimeInterval,
            exercises: [Exercise],
            activities: [WorkoutActivityBlock] = [],
            startSource: String = "quick_start",
            templateId: String? = nil,
            hasActivePlan: Bool = false
        ) {
            self.title = title
            self.startedAt = startedAt
            self.elapsed = elapsed
            self.exercises = exercises
            self.activities = activities
            self.startSource = startSource
            self.templateId = templateId
            self.hasActivePlan = hasActivePlan
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
            startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
            elapsed = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsed) ?? 0
            exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
            activities = try container.decodeIfPresent([WorkoutActivityBlock].self, forKey: .activities) ?? []
            startSource = try container.decodeIfPresent(String.self, forKey: .startSource) ?? "quick_start"
            templateId = try container.decodeIfPresent(String.self, forKey: .templateId)
            hasActivePlan = try container.decodeIfPresent(Bool.self, forKey: .hasActivePlan) ?? false
        }
    }

    private let snapshotKey = "session.resume.snapshot.v1"

    // MARK: - Public session controls

    func startTraining(title: String? = nil,
                       source: String = "quick_start",
                       templateId: String? = nil,
                       hasActivePlan: Bool = false) {
        if let t = title {
            trainingTitle = t
        }
        workoutStartSource = source
        workoutTemplateId = templateId
        workoutHasActivePlan = hasActivePlan
        startTime = Date()
        elapsedTime = 0
        isTrainingActive = true
        startTimer()
        persistSnapshotIfNeeded()
    }

    // Convenience used by NewTrainingView
    func startTraining() {
        startTraining(title: trainingTitle.isEmpty ? "" : trainingTitle)
    }

    func reset() {
        stopTimer()
        isTrainingActive = false
        startTime = nil
        elapsedTime = 0
        exercises = []
        activities = []
        trainingTitle = ""
        workoutStartSource = "quick_start"
        workoutTemplateId = nil
        workoutHasActivePlan = false
        completedExercises = 0
        totalWeightLifted = 0
        clearResumeSnapshot()
    }

    // MARK: - Exercise editing used by views

    func addExercise(_ name: String) {
        // Direkt 1 Satz mit "0" Gewicht und "0" Wiederholungen anlegen
        let defaultSets = [
            ExerciseSet(weight: "0", reps: "0", isCompleted: false)
        ]
        exercises.append(Exercise(name: name, sets: defaultSets))
        persistSnapshotIfNeeded()
    }

    func addSet(to exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }
        // Vorbelegung: letzten Satz derselben Übung kopieren, falls vorhanden
        let sets = exercises[exerciseIndex].sets
        if let last = sets.last {
            exercises[exerciseIndex].sets.append(
                ExerciseSet(weight: last.weight, reps: last.reps, isCompleted: false)
            )
        } else {
            exercises[exerciseIndex].sets.append(
                ExerciseSet(weight: "0", reps: "0", isCompleted: false)
            )
        }
        persistSnapshotIfNeeded()
    }

    func toggleSetCompleted(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        // Flip
        exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
        let isNowCompleted = exercises[exerciseIndex].sets[setIndex].isCompleted
        persistSnapshotIfNeeded()

        // Wenn der Satz jetzt abgeschlossen ist und Werte hat -> auf leere Sätze der Übung propagieren
        if isNowCompleted, hasRealValues(exerciseIndex: exerciseIndex, setIndex: setIndex) {
            propagateSuggestionToEmptySets(exerciseIndex: exerciseIndex, sourceSetIndex: setIndex)
        }

        // Auto rest timer trigger when set becomes completed
        if isNowCompleted {
            NotificationCenter.default.post(name: .didCompleteSet, object: nil)
        }
    }

    func removeSet(from exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        exercises[exerciseIndex].sets.remove(at: setIndex)

        // Wenn keine Sätze mehr übrig sind → Übung entfernen
        if exercises[exerciseIndex].sets.isEmpty {
            exercises.remove(at: exerciseIndex)
        }

        persistSnapshotIfNeeded()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let base = startTime ?? Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isTrainingActive else { return }
            self.elapsedTime = Date().timeIntervalSince(base)
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Snapshot persistence

    func persistSnapshotIfNeeded() {
        guard isTrainingActive, let startedAt = startTime else { return }
        let snap = ResumeSnapshot(
            title: trainingTitle,
            startedAt: startedAt,
            elapsed: elapsedTime,
            exercises: exercises,
            activities: activities,
            startSource: workoutStartSource,
            templateId: workoutTemplateId,
            hasActivePlan: workoutHasActivePlan
        )
        do {
            let data = try JSONEncoder().encode(snap)
            UserDefaults.standard.set(data, forKey: snapshotKey)
        } catch {
            // ignore encode errors
        }
    }

    func loadResumeSnapshot() -> ResumeSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(ResumeSnapshot.self, from: data)
    }

    func clearResumeSnapshot() {
        UserDefaults.standard.removeObject(forKey: snapshotKey)
    }

    @discardableResult
    func resume(from snapshot: ResumeSnapshot) -> Bool {
        // Restore state
        trainingTitle = snapshot.title
        exercises = snapshot.exercises
        activities = snapshot.activities
        workoutStartSource = snapshot.startSource
        workoutTemplateId = snapshot.templateId
        workoutHasActivePlan = snapshot.hasActivePlan
        startTime = snapshot.startedAt
        elapsedTime = snapshot.elapsed
        isTrainingActive = true
        startTimer()
        return true
    }

    // MARK: - ⌚️ Watch → iPhone: Satz hinzufügen
    func addSetFromWatch(workoutExerciseId: String, reps: Int, weightKg: Double, markCompleted: Bool = true) {
        guard isTrainingActive else {
            print("[Session] ignore Watch set: no active training")
            return
        }
        guard let exIndex = exercises.firstIndex(where: { $0.id.uuidString == workoutExerciseId }) else {
            print("[Session] exercise not found for id:", workoutExerciseId)
            return
        }
        let weightString = formatWeightForStorage(weightKg)

        let set = ExerciseSet(
            weight: weightString,
            reps: String(reps),
            isCompleted: markCompleted
        )
        exercises[exIndex].sets.append(set)

        // Nach dem Hinzufügen: Werte in leere Sätze der Übung propagieren
        let newIndex = exercises[exIndex].sets.count - 1
        if hasRealValues(exerciseIndex: exIndex, setIndex: newIndex) {
            propagateSuggestionToEmptySets(exerciseIndex: exIndex, sourceSetIndex: newIndex)
        }

        persistSnapshotIfNeeded()
    }

    // MARK: - ⌚️ Watch → iPhone: Satz aktualisieren (mit optionalem Auto-Complete)
    func updateSetFromWatch(workoutExerciseId: String, setId: String, reps: Int, weightKg: Double, markCompletedOnUpdate: Bool = true) {
        guard isTrainingActive else {
            print("[Session] ignore Watch update: no active training")
            return
        }
        guard let exIndex = exercises.firstIndex(where: { $0.id.uuidString == workoutExerciseId }) else {
            print("[Session] exercise not found for id:", workoutExerciseId)
            return
        }
        guard let setIndex = exercises[exIndex].sets.firstIndex(where: { $0.id.uuidString == setId }) else {
            print("[Session] set not found for id:", setId)
            return
        }

        let weightString = formatWeightForStorage(weightKg)

        exercises[exIndex].sets[setIndex].reps = String(reps)
        exercises[exIndex].sets[setIndex].weight = weightString
        if markCompletedOnUpdate {
            exercises[exIndex].sets[setIndex].isCompleted = true
        }

        // Nach Update: Werte in leere Sätze der Übung propagieren
        if hasRealValues(exerciseIndex: exIndex, setIndex: setIndex) {
            propagateSuggestionToEmptySets(exerciseIndex: exIndex, sourceSetIndex: setIndex)
        }

        persistSnapshotIfNeeded()
    }

    // MARK: - ⌚️ Watch → iPhone: Satz löschen
    func removeSetFromWatch(workoutExerciseId: String, setId: String) {
        guard isTrainingActive else {
            print("[Session] ignore Watch remove: no active training")
            return
        }
        guard let exIndex = exercises.firstIndex(where: { $0.id.uuidString == workoutExerciseId }) else {
            print("[Session] exercise not found for id:", workoutExerciseId)
            return
        }
        guard let setIndex = exercises[exIndex].sets.firstIndex(where: { $0.id.uuidString == setId }) else {
            print("[Session] set not found for id:", setId)
            return
        }

        exercises[exIndex].sets.remove(at: setIndex)
        if exercises[exIndex].sets.isEmpty {
            exercises.remove(at: exIndex)
        }
        persistSnapshotIfNeeded()
    }

    // MARK: - Propagation Helpers

    // Ein Satz hat „echte“ Werte, wenn Gewicht > 0 ODER Reps nicht leer/„0“ sind.
    private func hasRealValues(exerciseIndex: Int, setIndex: Int) -> Bool {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return false }
        let s = exercises[exerciseIndex].sets[setIndex]
        let w = parseWeight(s.weight)
        let r = s.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        return w > 0 || (!r.isEmpty && r != "0")
    }

    // „Leer“ = Gewicht == 0 UND Reps leer oder "0"
    private func isEmptySet(_ s: ExerciseSet) -> Bool {
        let w = parseWeight(s.weight)
        let r = s.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        return w == 0 && (r.isEmpty || r == "0")
    }

    private func parseWeight(_ text: String) -> Double {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("."), !t.contains(","),
           let d = Double(t) {
            return d
        }
        if let d = Double(t) { return d }
        let swapped = t.replacingOccurrences(of: ",", with: ".")
        return Double(swapped) ?? 0
    }

    private func formatWeightForStorage(_ kg: Double) -> String {
        let rounded = (kg * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.0001 {
            return "\(Int(rounded.rounded()))"
        }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }

    // Kopiert Werte des Quell‑Satzes in alle „leeren“ Sätze derselben Übung (ohne den Quell‑Satz).
    func propagateSuggestionToEmptySets(exerciseIndex: Int, sourceSetIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(sourceSetIndex) else { return }

        let source = exercises[exerciseIndex].sets[sourceSetIndex]
        let srcWeight = source.weight
        let srcReps = source.reps

        for idx in exercises[exerciseIndex].sets.indices where idx != sourceSetIndex {
            if isEmptySet(exercises[exerciseIndex].sets[idx]) {
                exercises[exerciseIndex].sets[idx].weight = srcWeight
                exercises[exerciseIndex].sets[idx].reps = srcReps
            }
        }
        persistSnapshotIfNeeded()
    }
}
