import Foundation
import Combine

class ExerciseLibrary: ObservableObject {
    @Published private(set) var exercisesInfo: [ExerciseInfo] = []
    
    var exercises: [ExerciseInfo] {
        exercisesInfo
    }

    private let exercisesKey = "exerciseLibrary.exercises"

    init() {
        loadExercises()
    }

    func addExercise(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !exercisesInfo.contains(where: { $0.name == trimmed }) else { return }

        let newExercise = ExerciseInfo(
            name: trimmed,
            muscleGroup: "Unbekannt",
            instructions: "Keine Anleitung verfügbar"
        )
        exercisesInfo.append(newExercise)
        saveExercises()
    }

    func deleteExercise(at offsets: IndexSet) {
        exercisesInfo.remove(atOffsets: offsets)
        saveExercises()
    }

    private func saveExercises() {
        if let encoded = try? JSONEncoder().encode(exercisesInfo) {
            UserDefaults.standard.set(encoded, forKey: exercisesKey)
        }
    }

    private func loadExercises() {
        // 1. Load saved user data first
        if let data = UserDefaults.standard.data(forKey: exercisesKey),
           let decoded = try? JSONDecoder().decode([ExerciseInfo].self, from: data),
           !decoded.isEmpty {
            self.exercisesInfo = decoded
            // Optional: Merge new exercises from JSON if needed, but keeping it simple as requested
            mergeWithBundledData()
        } else {
            // 2. No saved data, load from JSON
            loadFromJSON()
        }
    }
    
    private func loadFromJSON() {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            print("❌ exercises.json not found!")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let bundledExercises = try JSONDecoder().decode([ExerciseInfo].self, from: data)
            self.exercisesInfo = bundledExercises
            saveExercises()
        } catch {
            print("❌ Error loading exercises.json: \(error)")
        }
    }
    
    private func mergeWithBundledData() {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let bundledExercises = try JSONDecoder().decode([ExerciseInfo].self, from: data)
            
            var updated = false
            for bundledEx in bundledExercises {
                if !exercisesInfo.contains(where: { $0.name == bundledEx.name }) {
                    exercisesInfo.append(bundledEx)
                    updated = true
                }
            }
            
            if updated {
                exercisesInfo.sort { $0.name < $1.name }
                saveExercises()
            }
        } catch {
            print("❌ Error merging exercises.json: \(error)")
        }
    }

    func exerciseInfo(for name: String) -> ExerciseInfo? {
        exercisesInfo.first { $0.name == name }
    }
}


extension ExerciseLibrary {
    func addNote(for exerciseId: UUID, text: String = "") {
        if let index = exercisesInfo.firstIndex(where: { $0.id == exerciseId }) {
            exercisesInfo[index].notes.append(Note(text: text))
            saveExercises()
        }
    }

    func updateNote(for exerciseId: UUID, note: Note) {
        if let exIndex = exercisesInfo.firstIndex(where: { $0.id == exerciseId }),
           let noteIndex = exercisesInfo[exIndex].notes.firstIndex(where: { $0.id == note.id }) {
            exercisesInfo[exIndex].notes[noteIndex] = note
            saveExercises()
        }
    }

    func deleteNote(for exerciseId: UUID, noteId: UUID) {
        if let exIndex = exercisesInfo.firstIndex(where: { $0.id == exerciseId }) {
            exercisesInfo[exIndex].notes.removeAll { $0.id == noteId }
            saveExercises()
        }
    }
}



