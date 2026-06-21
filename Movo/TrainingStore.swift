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


    func add(entry: TrainingEntry) {
        history.append(entry)
    }
    
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
    /// Aktuelle Streak in Tagen (wenn heute nicht trainiert wurde, wird ab gestern gezählt).
    func currentStreakDays(reference: Date = Date()) -> Int {
        smartStreakDays(reference: reference, maxGap: 0)
    }
    
    /// Smarte Streak Logic: Erlaubt bis zu `maxGap` Tage Pause (Rest Days).
    /// Standard-Streak nutzt maxGap = 0. Für UI mit Rest Days z.B. maxGap = 2 nutzen.
    func smartStreakDays(reference: Date = Date(), maxGap: Int = 2) -> Int {
        let cal = Calendar.current
        let trainedDays = Set(history.map { cal.startOfDay(for: $0.date) })
        
        var cursor = cal.startOfDay(for: reference)
        
        // Wenn heute noch kein Training, prüfen wir ab gestern
        // (Aber nur wenn wir überhaupt schon mal trainiert haben, sonst 0)
        if !trainedDays.contains(cursor) {
            // Check if we trained recently within valid gap to keep streak alive
            var foundConnect = false
            for i in 1...maxGap+1 {
                if let check = cal.date(byAdding: .day, value: -i, to: cursor), trainedDays.contains(check) {
                    // Found a training within valid gap, so streak is active relative to that day
                    // Reset cursor to that day to start counting backwards
                    cursor = check
                    foundConnect = true
                    break
                }
            }
            if !foundConnect { return 0 }
        }
        
        var count = 0
        var currentGap = 0
        
        // Count backwards
        // We know 'cursor' is a trained day (or we found one above).
        
        // Logic:
        // We iterate backwards day by day.
        // If trained: increment count, reset gap.
        // If not trained: increment gap.
        // If gap > maxGap: stop.
        
        // Initial setup
        // The loop needs to start checking from cursor downwards.
        // Since we established cursor IS a trained day (or point of connection), current streak is at least 1?
        // Wait, standard definition: "Consecutive days". With gap tolerance, it means "sequences separated by <= maxGap".
        
        // Let's iterate backwards indefinitely until we break
        
        var checkDate = cursor
        
        // We count DAYS involved in the streak timeframe, or just TRAINED days?
        // Usually users want "Streak Length". If I train Mon, Wed, Fri (gap 1), is streak 5 days (Mon-Fri) or 3 days (Mon, Wed, Fri)?
        // User request: "Streak logic... im gym ja auch nicht jeden tag trainieren".
        // Usually this implies checking consistency.
        // Let's count "Trained Days" within the connected chain.
        // If user wants "Time Span", we would calculate (EndDate - StartDate).
        // Let's stick to "Count of Workouts/Days" but allow gaps primarily to KEEP the chain alive.
        
        // PROPOSAL: We count the SPAN of the streak in days, assuming gaps are "rest days" that count towards the "consistency lifestyle".
        // e.g. Mon(T), Tue(Rest), Wed(T).  Streak = 3 days? Or 2?
        // Most apps (like Duolingo with freezes) count the active days + freezes used?
        // Actually, straightforward "Gym Streak":
        // "I've been going for 3 weeks".
        // Let's count the number of TRAINING DAYS found in the valid chain.
        
        var streakCount = 0
        
        while true {
            if trainedDays.contains(checkDate) {
                streakCount += 1
                currentGap = 0 // Reset gap counter
            } else {
                currentGap += 1
                if currentGap > maxGap {
                    break // Gap too large, streak ends
                }
            }
            
            // Move back 1 day
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        
        return streakCount
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
