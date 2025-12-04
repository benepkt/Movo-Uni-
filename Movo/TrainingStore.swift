import SwiftUI
import Foundation
import Combine

final class TrainingStore: ObservableObject {

    // MARK: - Trainingshistorie (lokal)
    @Published var history: [TrainingEntry] = [] {
        didSet { saveHistory() }
    }

    // MARK: - Trainingsvorlagen (lokal)
    @Published var templates: [TrainingTemplate] = [] {
        didSet { saveTemplates() }
    }

    // MARK: - UserDefaults Keys
    private let historyKey   = "trainingHistory"
    private let templatesKey = "trainingTemplates"

    init() {
        loadHistory()
        loadTemplates()
    }

    // MARK: - Persistenz: History
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        do {
            history = try JSONDecoder().decode([TrainingEntry].self, from: data)
        } catch {
            print("❌ Fehler beim Laden der Trainings: \(error)")
            history = []
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("❌ Fehler beim Speichern der Trainings: \(error)")
        }
    }

    func add(entry: TrainingEntry) { history.append(entry) }
    func update(entry: TrainingEntry) {
        if let idx = history.firstIndex(where: { $0.id == entry.id }) {
            history[idx] = entry
        }
    }
    func remove(at offsets: IndexSet) { history.remove(atOffsets: offsets) }

    // MARK: - Persistenz: Templates
    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: templatesKey) else { return }
        do {
            templates = try JSONDecoder().decode([TrainingTemplate].self, from: data)
        } catch {
            print("❌ Fehler beim Laden der Trainingsvorlagen: \(error)")
            templates = []
        }
    }

    private func saveTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            UserDefaults.standard.set(data, forKey: templatesKey)
        } catch {
            print("❌ Fehler beim Speichern der Trainingsvorlagen: \(error)")
        }
    }

    func addTemplate(_ template: TrainingTemplate) { templates.append(template) }
    func updateTemplate(_ template: TrainingTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        }
    }
    func removeTemplate(at offsets: IndexSet) { templates.remove(atOffsets: offsets) }
}

// MARK: - Challenges & Streaks
extension TrainingStore {

    /// Aktuelle Streak in Tagen (wenn heute nicht trainiert wurde, wird ab gestern gezählt).
    func currentStreakDays(reference: Date = Date()) -> Int {
        let cal = Calendar.current
        let trainedDays = Set(history.map { cal.startOfDay(for: $0.date) })

        var cursor = cal.startOfDay(for: reference)
        if !trainedDays.contains(cursor),
           let yesterday = cal.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yesterday
        }

        var count = 0
        while trainedDays.contains(cursor) {
            count += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    /// Anzahl unterschiedlicher Trainingstage in der **laufenden** Kalenderwoche.
    func distinctTrainingDaysThisWeek(reference: Date = Date()) -> Int {
        let cal = Calendar.current
        let thisWeek = history.filter { cal.isDate($0.date, equalTo: reference, toGranularity: .weekOfYear) }
        return Set(thisWeek.map { cal.startOfDay(for: $0.date) }).count
    }

    /// **NEU:** Bool-Array (7 Einträge) ab Wochenbeginn (Locale), ob an diesem Tag trainiert wurde.
    /// Verwendung: StreakCongrats-View (Häkchen-Reihe).
    func weekProgress(asOf reference: Date = Date()) -> [Bool] {
        var cal = Calendar.current
        cal.locale = .current

        guard let interval = cal.dateInterval(of: .weekOfYear, for: reference) else {
            return Array(repeating: false, count: 7)
        }
        let startOfWeek = cal.startOfDay(for: interval.start)

        let trainedSet: Set<Date> = Set(history.map { cal.startOfDay(for: $0.date) })

        return (0..<7).map { i in
            let day = cal.date(byAdding: .day, value: i, to: startOfWeek)!
            return trainedSet.contains(day)
        }
    }

    /// Optional praktisch: ganze Streak in **Wochen**.
    func currentStreakWeeks(reference: Date = Date()) -> Int {
        currentStreakDays(reference: reference) / 7
    }
}
