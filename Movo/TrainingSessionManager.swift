import Foundation
import Combine
import ActivityKit

class TrainingSessionManager: ObservableObject {
    @Published var isTrainingActive = false
    @Published var startTime: Date?
    @Published var elapsedTime: TimeInterval = 0.0
    @Published var exercises: [Exercise] = []
    @Published var trainingTitle: String = ""
    @Published var completedExercises: Int = 0
    @Published var totalWeightLifted: Double = 0.0


    private var timer: Timer?
    
    
    
    // MARK: - Resume Snapshot (in TrainingSessionManager einfügen)

    private var resumeKey: String { "training.resume.snapshot.v1" }

    struct ResumeSnapshot: Codable {
        let createdAt: Date
        let date: Date
        let title: String
        let elapsed: TimeInterval
        let exercises: [ExerciseDTO]
    }
    struct ExerciseDTO: Codable {
        let name: String
        let sets: [SetDTO]
    }
    struct SetDTO: Codable {
        let weight: String
        let reps: String
        let isCompleted: Bool
    }

    // Snapshot speichern (z.B. wenn App in den Hintergrund geht)
    func persistSnapshotIfNeeded() {
        guard isTrainingActive else { clearResumeSnapshot(); return }

        let dto = exercises.map { ex in
            ExerciseDTO(
                name: ex.name,
                sets: ex.sets.map { SetDTO(weight: $0.weight, reps: $0.reps, isCompleted: $0.isCompleted) }
            )
        }
        let snap = ResumeSnapshot(
            createdAt: Date(),
            date: startTime ?? Date(),
            title: trainingTitle,
            elapsed: elapsedTime,
            exercises: dto
        )
        do { UserDefaults.standard.set(try JSONEncoder().encode(snap), forKey: resumeKey) }
        catch { print("[Resume] encode error:", error.localizedDescription) }
    }

    func loadResumeSnapshot() -> ResumeSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: resumeKey) else { return nil }
        do { return try JSONDecoder().decode(ResumeSnapshot.self, from: data) }
        catch { print("[Resume] decode error:", error.localizedDescription); return nil }
    }

    func clearResumeSnapshot() {
        UserDefaults.standard.removeObject(forKey: resumeKey)
    }

    /// Session aus Snapshot **fortsetzen** (Timer läuft weiter)
    @discardableResult
    func resume(from snap: ResumeSnapshot) -> Bool {
        // Zustand setzen
        isTrainingActive = true
        trainingTitle = snap.title
        exercises = snap.exercises.map {
            Exercise(name: $0.name,
                     sets: $0.sets.map { ExerciseSet(weight: $0.weight, reps: $0.reps, isCompleted: $0.isCompleted) })
        }
        // Startzeit so setzen, dass `elapsedTime` weiterzählt
        startTime = Date().addingTimeInterval(-snap.elapsed)
        elapsedTime = snap.elapsed

        // Timer neu starten
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = self.startTime {
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
        return true
    }

   


    
    func startTraining(title: String = "Training") {
        guard !isTrainingActive else { return }
        isTrainingActive = true
        trainingTitle = title
        startTime = Date()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = self.startTime {
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
    
    func startTraining(from template: TrainingTemplate) {
        startTraining(title: template.name)
        exercises = template.exercises.map { Exercise(name: $0, sets: [ExerciseSet(weight: "", reps: "", isCompleted: false)]) }
    }

    func addExercise(_ name: String) {
        let newExercise = Exercise(name: name, sets: [ExerciseSet(weight: "", reps: "", isCompleted: false)])
        exercises.append(newExercise)
    }

    func addSet(to index: Int) {
        exercises[index].sets.append(ExerciseSet(weight: "", reps: "", isCompleted: false))
    }

    func toggleSetCompleted(exerciseIndex: Int, setIndex: Int) {
        exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
    }

    func calculateTotalWeight() -> Double {
        exercises.flatMap { $0.sets }
            .compactMap { Double($0.weight) }
            .reduce(0, +)
    }
    
    func removeSet(from exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        
        exercises[exerciseIndex].sets.remove(at: setIndex)
        
        // Falls keine Sets mehr vorhanden → Übung löschen
        if exercises[exerciseIndex].sets.isEmpty {
            exercises.remove(at: exerciseIndex)
        }
    }



    func saveTraining() -> TrainingEntry? {
        guard isTrainingActive, let start = startTime else { return nil }

        let entry = TrainingEntry(
            date: start,
            title: trainingTitle.isEmpty ? "Training" : trainingTitle,
            exercises: exercises,
            duration: elapsedTime,
            totalWeight: calculateTotalWeight()
        )
        reset()
        return entry
    }

    func reset() {
        isTrainingActive = false
        startTime = nil
        elapsedTime = 0
        exercises = []
        trainingTitle = ""
        timer?.invalidate()
        timer = nil
    }
}
