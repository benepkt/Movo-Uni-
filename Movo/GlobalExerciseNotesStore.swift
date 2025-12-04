import SwiftUI
import Combine



class GlobalExerciseNotesStore: ObservableObject {
    @Published private(set) var notesDict: [UUID: [Note]] = [:]

    private let notesKey = "exerciseNotes"

    // Alle Notizen für eine Übung laden
    func notes(for exerciseId: UUID) -> [Note] {
        notesDict[exerciseId] ?? []
    }

    // Neue Notiz hinzufügen
    func addNote(for exerciseId: UUID) {
        var list = notes(for: exerciseId)
        list.append(Note(text: ""))
        notesDict[exerciseId] = list
        saveNotes(for: exerciseId)
    }

    // Notiz aktualisieren
    func updateNote(_ note: Note, for exerciseId: UUID) {
        var list = notes(for: exerciseId)
        if let index = list.firstIndex(where: { $0.id == note.id }) {
            list[index] = note
            notesDict[exerciseId] = list
            saveNotes(for: exerciseId)
        }
    }

    // Notiz löschen
    func removeNote(_ note: Note, for exerciseId: UUID) {
        var list = notes(for: exerciseId)
        list.removeAll { $0.id == note.id }
        notesDict[exerciseId] = list
        saveNotes(for: exerciseId)
    }

    // MARK: - Persistence
    private func saveNotes(for exerciseId: UUID) {
        do {
            let data = try JSONEncoder().encode(notesDict[exerciseId])
            UserDefaults.standard.set(data, forKey: "exerciseNotes_\(exerciseId.uuidString)")
            print("✅ Gespeichert für \(exerciseId)")
        } catch {
            print("❌ Fehler beim Speichern: \(error)")
        }
    }

    func loadNotes(for exerciseId: UUID) {
        guard let data = UserDefaults.standard.data(forKey: "exerciseNotes_\(exerciseId.uuidString)") else { return }
        do {
            let list = try JSONDecoder().decode([Note].self, from: data)
            notesDict[exerciseId] = list
            print("📥 Geladen für \(exerciseId)")
        } catch {
            print("❌ Fehler beim Laden: \(error)")
            notesDict[exerciseId] = []
        }
    }
}

