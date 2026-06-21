import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Projekt-Typen, die es bei dir schon gibt
// Exercise, ExerciseSet, TrainingStore, HealthKitManager, GamificationManager,
// AppSettings, LanguageManager, LocalizedStrings, SessionView

// MARK: - ChallengeType
enum ChallengeType: String, Codable, CaseIterable {
    case workouts           // Workouts pro Woche
    case steps              // Schritte (heute oder Ziel-basiert)
    case weeklyVolume       // Gesamt bewegtes Gewicht pro Woche (kg)
    case streak             // X Tage am Stück trainiert
    case weeklySessions     // an X unterschiedlichen Tagen trainiert
}

// MARK: - Challenge Model
struct Challenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let type: ChallengeType
    let description: String
    let goal: Int
    var progress: Int
    var unit: String

    init(
        id: UUID = UUID(),
        title: String,
        type: ChallengeType,
        description: String,
        goal: Int,
        progress: Int,
        unit: String
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.description = description
        self.goal = goal
        self.progress = progress
        self.unit = unit
    }

    var isCompleted: Bool { progress >= goal }

    var badge: Badge {
        let r = Double(progress) / Double(max(goal, 1))
        switch r {
        case let x where x >= 1.0: return .gold
        case let x where x >= 0.8: return .silver
        case let x where x >= 0.5: return .bronze
        default: return .none
        }
    }

    var icon: String {
        switch type {
        case .workouts:       return "figure.strengthtraining.traditional"
        case .steps:          return "figure.walk"
        case .weeklyVolume:   return "dumbbell.fill"
        case .streak:         return "flame"
        case .weeklySessions: return "calendar"
        }
    }
}

// MARK: - Week & TrainingUnit
struct Week: Identifiable, Codable {
    var id: Int { number }
    let number: Int
    var warmUp: [Exercise] = []
    var exercises: [Exercise]
    var coolDown: [Exercise] = []

    var isCompleted: Bool {
        func allDone(_ list: [Exercise]) -> Bool {
            list.allSatisfy { e in e.sets.allSatisfy { $0.isCompleted } }
        }
        return allDone(warmUp) && allDone(exercises) && allDone(coolDown)
    }
}

struct TrainingUnit: Identifiable, Codable {
    let id = UUID()
    let titleKey: String
    let subtitleKey: String
    let durationKey: String
    let levelKey: String
    let icon: String
    var completedWeeks: Int = 0
    var weeks: [Week] = []

    func title(using s: AppSettings) -> String { s.localized(titleKey) }
    func subtitle(using s: AppSettings) -> String { s.localized(subtitleKey) }
    func duration(using s: AppSettings) -> String { s.localized(durationKey) }
    func level(using s: AppSettings) -> String { s.localized(levelKey) }
}

// MARK: - Badge
enum Badge: Codable { case none, bronze, silver, gold
    var color: Color {
        switch self {
        case .none:   return .gray
        case .bronze: return .orange
        case .silver: return .gray
        case .gold:   return .yellow
        }
    }
}

// MARK: - Notifications
import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let dailyId = "dailyChallengeReminder"
    
    // Get user name for personalization
    private func getUserName() -> String {
        return UserDefaults.standard.string(forKey: "userName") ?? ""
    }
    
    // Helper to personalize text
    private func personalize(_ text: String) -> String {
        let name = getUserName()
        if !name.isEmpty {
            return text.replacingOccurrences(of: "{name}", with: name)
        } else {
            return text.replacingOccurrences(of: "{name}, ", with: "")
                      .replacingOccurrences(of: "{name} ", with: "")
                      .replacingOccurrences(of: "{name}", with: "")
        }
    }

    // App-Start: nur Zustand prüfen & (de-)schedulen – KEIN Prompt
    func bootstrap(appSettings: AppSettings) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let isAuth: Bool = {
                    switch settings.authorizationStatus {
                    case .authorized, .provisional, .ephemeral: return true
                    default: return false
                    }
                }()

                if !isAuth || !appSettings.notificationsEnabled {
                    self.cancelAll()
                } else {
                    self.cancel(ids: [self.dailyId])
                }
            }
        }
    }

    // Schalter in den App-Einstellungen
    func setEnabled(_ enabled: Bool, appSettings: AppSettings) {
        if enabled {
            requestAuthorizationIfNeeded(forcePrompt: false, appSettings: appSettings) { granted in
                DispatchQueue.main.async {
                    if !granted { appSettings.notificationsEnabled = false }
                }
            }
        } else {
            cancelAll()
        }
    }

    // Nach Sprachwechsel etc.
    func rescheduleIfNeeded(appSettings: AppSettings) {
        cancel(ids: [dailyId])
    }

    // Onboarding-CTA: hiermit explizit anfragen (zeigt Prompt nur wenn nötig)
    func requestAuthorizationIfNeeded(forcePrompt: Bool = false,
                                      appSettings: AppSettings,
                                      completion: ((Bool)->Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { s in
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    completion?(true)
                }

            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        appSettings.notificationsEnabled = granted
                        completion?(granted)
                    }
                }

            case .denied:
                DispatchQueue.main.async {
                    appSettings.notificationsEnabled = false
                    if forcePrompt { self.openSystemSettingsIfDenied() }
                    completion?(false)
                }

            @unknown default:
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    // Einfache Sofort-Notification (Debug/Timer etc.)
    func scheduleNotification(title: String, body: String, inSeconds: TimeInterval = 1) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: inSeconds, repeats: false)
        UNUserNotificationCenter.current().add(.init(identifier: UUID().uuidString, content: c, trigger: trigger))
    }

    // Tägliche Erinnerung (20:00) – Sprache via AppSettings.language (String)
    func scheduleDailyReminder(language: String = "de", hour: Int = 20, minute: Int = 0) {
        cancel(ids: [dailyId])
    }

    // MARK: - Convenience notifications used in ChallengeStore

    func notifyStreakMilestone(days: Int) {
        let title = LocalizedStrings.de["notifications.streakMilestone"] ?? personalize("{name}Streak-Meilenstein! 🔥")
        let body = String(format: LocalizedStrings.de["notifications.streakMilestoneBody"] ?? "Du bist seit %d Tagen am Stück aktiv. Weiter so!", days)
        scheduleNotification(title: title, body: body)
    }

    func notifyChallengeProgress(challengeName: String, progress: Int, goal: Int) {
        let percent = Int((Double(progress) / Double(max(goal, 1))) * 100.0)
        let title = LocalizedStrings.de["notifications.challengeProgress"] ?? personalize("{name}Fast geschafft! ⭐")
        let bodyTemplate = LocalizedStrings.de["notifications.challengeProgressBody"] ?? "%@: %d%% erreicht."
        let body = String(format: bodyTemplate, challengeName, percent)
        scheduleNotification(title: title, body: body)
    }

    // MARK: - Helpers

    private func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func cancel(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func openSystemSettingsIfDenied() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - ChallengeStore
struct LiftEntry: Codable {
    let date: Date
    let kg: Double
}
@MainActor
final class ChallengeStore: ObservableObject {
    let appSettings: AppSettings

    @Published var challenges: [Challenge] = []
    @Published var trainingUnits: [TrainingUnit] = []
    @Published var challengeTemplatesStore: [Challenge] = []
    
    // MARK: - Smart Programmes (New)
    @Published var activeProgram: ActiveProgram? = nil
    @Published var availablePrograms: [TrainingProgram] = []

    // Logs
    @Published private(set) var liftLog: [LiftEntry] = []                // für weeklyVolume
    @Published private(set) var stepsLog: [String: Int] = [:]            // ISO-Tag -> Schritte (für Wochenziele)

    private let defaults = UserDefaults.standard
    private let activeChallengesKey = "activeChallengesData"
    private let activeProgramKey = "activeProgramData" // NEW
    private let availableProgramsKey = "availableTrainingProgramsData"
    private let templatesKey = "challengeTemplatesData"
    private let unitsKey = "trainingUnitsData"
    private let liftLogKey = "liftLogData"
    private let stepsLogKey = "stepsLogData"

    // Eindeutiger Schlüssel für Challenge-Templates
    private func templateKey(_ c: Challenge) -> String {
        "\(c.type.rawValue)|\(c.title)|\(c.goal)|\(c.unit)"
    }

    // Gespeicherte Templates mit Defaults mergen (vorhandene behalten, neue ergänzen)
    private func mergeTemplatesWithDefaults(_ stored: [Challenge], defaults: [Challenge]) -> [Challenge] {
        var merged = [String: Challenge](uniqueKeysWithValues: stored.map { (templateKey($0), $0) })
        for def in defaults {
            let key = templateKey(def)
            if merged[key] == nil { merged[key] = def }
        }
        return Array(merged.values)
    }

    // MARK: - Init (bereinigt)
    init(appSettings: AppSettings = AppSettings()) {
        self.appSettings = appSettings

        // --- Aktive Challenges ---
        if let data = defaults.data(forKey: activeChallengesKey),
           let decoded = try? JSONDecoder().decode([Challenge].self, from: data) {
            self.challenges = decoded
        } else {
            self.challenges = [
                Challenge(
                    title: appSettings.localized("challenge.workouts.title"),
                    type: .workouts,
                    description: appSettings.localized("challenge.workouts.desc"),
                    goal: 5, progress: 0,
                    unit: appSettings.localized("workouts.unit")
                ),
                Challenge(
                    title: "3-Tage-Streak",
                    type: .streak,
                    description: "Trainiere 3 Tage am Stück.",
                    goal: 3, progress: 0, unit: "Tage"
                )
            ]
            saveActiveChallenges()
        }

        // --- Templates: laden/mergen + Fallback ---
        let currentTemplateDefaults = Self.defaultTemplates(appSettings: appSettings)
        if let t = defaults.data(forKey: templatesKey),
           let stored = try? JSONDecoder().decode([Challenge].self, from: t) {
            let merged = mergeTemplatesWithDefaults(stored, defaults: currentTemplateDefaults)
            self.challengeTemplatesStore = merged.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if self.challengeTemplatesStore.isEmpty {
                // Safety: falls leer persistiert war
                self.challengeTemplatesStore = currentTemplateDefaults
                saveTemplates()
            } else if merged.count != stored.count {
                // neue Defaults ergänzt -> speichern
                saveTemplates()
            }
        } else {
            self.challengeTemplatesStore = currentTemplateDefaults
            saveTemplates()
        }

        // --- Units: laden/mergen (nur EIN Block) ---
        let currentUnitDefaults = Self.defaultUnits()
        if let data = defaults.data(forKey: unitsKey),
           let decoded = try? JSONDecoder().decode([TrainingUnit].self, from: data) {
            let merged = mergeUnitsWithDefaults(decoded, defaults: currentUnitDefaults)
            self.trainingUnits = merged
            if merged.count != decoded.count { saveTrainingUnits() }
        } else {
            self.trainingUnits = currentUnitDefaults
            saveTrainingUnits()
        }

        // gespeicherten Week-Fortschritt injizieren
        for u in trainingUnits.indices {
            for w in trainingUnits[u].weeks.indices {
                loadWeekProgress(&trainingUnits[u].weeks[w], unitId: trainingUnits[u].id)
            }
        }

        // --- Logs ---
        if let l = defaults.data(forKey: liftLogKey),
           let d = try? JSONDecoder().decode([LiftEntry].self, from: l) {
            self.liftLog = d
        }
        if let s = defaults.data(forKey: stepsLogKey),
           let d = try? JSONDecoder().decode([String: Int].self, from: s) {
            self.stepsLog = d
        }
        
        // --- Smart Programs ---
        loadActiveProgram()
        setupMockPrograms()
    }

    /// Safety-Net: Falls Templates mal leer in den UserDefaults landen.
    func ensureTemplatesPopulated() {
        if challengeTemplatesStore.isEmpty {
            challengeTemplatesStore = Self.defaultTemplates(appSettings: appSettings)
            saveTemplates()
        }
    }


    
    // MARK: - Smart Program Logic
    
    func todaysScheduledTemplate() -> TrainingTemplate? {
        guard let active = activeProgram else { return nil }
        guard let program = availablePrograms.first(where: { $0.id == active.programId }) else { return nil }
        
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1=Sun, 2=Mon...
        
        // Check schedule for today
        if let templateId = program.schedule[weekday],
           let template = program.routines.first(where: { $0.id == templateId }) {
            return template
        }
        return nil
    }

    func activeTrainingProgram() -> TrainingProgram? {
        guard let active = activeProgram else { return nil }
        return availablePrograms.first(where: { $0.id == active.programId })
    }

    func recommendedTemplate(from history: [TrainingEntry]) -> TrainingTemplate? {
        guard let program = activeTrainingProgram() else { return nil }
        guard program.smartOrderingEnabled else {
            return todaysScheduledTemplate()
        }

        let orderedTemplateIds = program.schedule
            .sorted { $0.key < $1.key }
            .map(\.value)
            .reduce(into: [String]()) { result, id in
                if !result.contains(id) { result.append(id) }
            }
        let orderedTemplates = orderedTemplateIds.compactMap { id in
            program.routines.first(where: { $0.id == id })
        }
        guard !orderedTemplates.isEmpty else { return todaysScheduledTemplate() }

        let recent = history
            .sorted { $0.date > $1.date }
            .first { entry in
                orderedTemplates.contains { template in
                    entry.title.localizedCaseInsensitiveContains(template.name)
                    || template.name.localizedCaseInsensitiveContains(entry.title)
                }
            }

        guard let recent else {
            return todaysScheduledTemplate() ?? orderedTemplates.first
        }

        guard let recentIndex = orderedTemplates.firstIndex(where: { template in
            recent.title.localizedCaseInsensitiveContains(template.name)
            || template.name.localizedCaseInsensitiveContains(recent.title)
        }) else {
            return todaysScheduledTemplate() ?? orderedTemplates.first
        }

        return orderedTemplates[(recentIndex + 1) % orderedTemplates.count]
    }
    
    func startProgram(_ program: TrainingProgram) {
        upsertProgram(program)
        let active = ActiveProgram(programId: program.id, startDate: Date())
        self.activeProgram = active
        saveActiveProgram()
    }

    func upsertProgram(_ program: TrainingProgram) {
        if let index = availablePrograms.firstIndex(where: { $0.id == program.id }) {
            availablePrograms[index] = program
        } else {
            availablePrograms.insert(program, at: 0)
        }
        saveAvailablePrograms()
    }

    func deleteProgram(_ program: TrainingProgram) {
        availablePrograms.removeAll { $0.id == program.id }
        if activeProgram?.programId == program.id {
            leaveCurrentProgram()
        }
        saveAvailablePrograms()
    }
    
    func leaveCurrentProgram() {
        self.activeProgram = nil
        defaults.removeObject(forKey: activeProgramKey)
    }
    
    private func loadActiveProgram() {
        if let data = defaults.data(forKey: activeProgramKey),
           let decoded = try? JSONDecoder().decode(ActiveProgram.self, from: data) {
            self.activeProgram = decoded
        }
    }
    
    private func saveActiveProgram() {
        if let data = try? JSONEncoder().encode(activeProgram) {
            defaults.set(data, forKey: activeProgramKey)
        }
    }

    private func saveAvailablePrograms() {
        if let data = try? JSONEncoder().encode(availablePrograms) {
            defaults.set(data, forKey: availableProgramsKey)
        }
    }
    
    private func setupMockPrograms() {
        // Create templates first
        let fullBodyA = TrainingTemplate(id: "fb_a", name: "Full Body A", exercises: ["Kniebeugen (Langhantel)", "Bankdrücken (Langhantel)", "Rudern (Langhantel)"], ownerId: "builtin")
        let fullBodyB = TrainingTemplate(id: "fb_b", name: "Full Body B", exercises: ["Kreuzheben", "Schulterdrücken", "Klimmzüge"], ownerId: "builtin")
        
        let upper = TrainingTemplate(id: "ul_upper", name: "Upper Body Power", exercises: ["Bankdrücken", "Rudern", "Overhead Press"], ownerId: "builtin")
        let lower = TrainingTemplate(id: "ul_lower", name: "Lower Body Power", exercises: ["Squat", "Deadlift", "Lunges"], ownerId: "builtin")

        // 1. Beginner
        let beginnerSplit = TrainingProgram(
            id: "beginner_split",
            title: "Beginner Full Body",
            description: "Perfect for starting out. 3 days a week covering all major muscle groups.",
            difficulty: .beginner,
            durationWeeks: 8,
            routines: [fullBodyA, fullBodyB],
            schedule: [
                2: "fb_a", // Mon
                4: "fb_b", // Wed
                6: "fb_a"  // Fri
            ]
        )
        
        // 2. Intermediate Upper/Lower
        let intermediateSplit = TrainingProgram(
            id: "inter_ul",
            title: "Upper / Lower Split",
            description: "Balanced 4-day split for muscle growth and recovery.",
            difficulty: .intermediate,
            durationWeeks: 12,
            routines: [upper, lower],
            schedule: [
                2: "ul_upper", // Mon
                3: "ul_lower", // Tue
                5: "ul_upper", // Thu
                6: "ul_lower"  // Fri
            ]
        )
        
        // 3. Advanced PPL (Placeholder)
        let pplPush = TrainingTemplate(id: "ppl_push", name: "Push Day", exercises: ["Incline Bench", "Dips", "Lateral Raise"], ownerId: "builtin")
        let pplPull = TrainingTemplate(id: "ppl_pull", name: "Pull Day", exercises: ["Pullups", "Rows", "Curls"], ownerId: "builtin")
        let pplLegs = TrainingTemplate(id: "ppl_legs", name: "Leg Day", exercises: ["Squat", "RDL", "Calves"], ownerId: "builtin")
        
        let advancedPPL = TrainingProgram(
            id: "adv_ppl",
            title: "Push Pull Legs",
            description: "High volume 6-day split for advanced lifters.",
            difficulty: .advanced,
            durationWeeks: 16,
            routines: [pplPush, pplPull, pplLegs],
            schedule: [
                2: "ppl_push", 3: "ppl_pull", 4: "ppl_legs",
                5: "ppl_push", 6: "ppl_pull", 7: "ppl_legs"
            ]
        )
        
        let defaultPrograms = [beginnerSplit, intermediateSplit, advancedPPL]

        if let data = defaults.data(forKey: availableProgramsKey),
           let stored = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
            var merged = stored
            for program in defaultPrograms where !merged.contains(where: { $0.id == program.id }) {
                merged.append(program)
            }
            self.availablePrograms = merged
        } else {
            self.availablePrograms = defaultPrograms
            saveAvailablePrograms()
        }
    }

    // MARK: - Persistenz
    func saveActiveChallenges() {
        if let data = try? JSONEncoder().encode(challenges) {
            defaults.set(data, forKey: activeChallengesKey)
        }
    }
    func saveTemplates() {
        if let data = try? JSONEncoder().encode(challengeTemplatesStore) {
            defaults.set(data, forKey: templatesKey)
        }
    }
    func saveTrainingUnits() {
        if let data = try? JSONEncoder().encode(trainingUnits) {
            defaults.set(data, forKey: unitsKey)
        }
    }
    private func saveLiftLog() {
        if let data = try? JSONEncoder().encode(liftLog) {
            defaults.set(data, forKey: liftLogKey)
        }
    }
    private func saveStepsLog() {
        if let data = try? JSONEncoder().encode(stepsLog) {
            defaults.set(data, forKey: stepsLogKey)
        }
    }

    // MARK: - Week-Fortschritt speichern / laden / resetten
    private func progressKey(unitId: UUID, weekNumber: Int) -> String {
        "week_\(unitId.uuidString)_\(weekNumber)_progress"
    }
    func saveWeekProgress(_ week: Week, unitId: UUID) {
        var weekProgress: [String: Bool] = [:]
        func dump(_ list: [Exercise], prefix: String) {
            for (i, ex) in list.enumerated() {
                for (j, set) in ex.sets.enumerated() {
                    weekProgress["\(prefix)_\(i)_\(j)"] = set.isCompleted
                }
            }
        }
        dump(week.warmUp,  prefix: "warmUp")
        dump(week.exercises, prefix: "exercises")
        dump(week.coolDown,  prefix: "coolDown")
        defaults.set(weekProgress, forKey: progressKey(unitId: unitId, weekNumber: week.number))

        if let u = trainingUnits.firstIndex(where: { $0.id == unitId }),
           let w = trainingUnits[u].weeks.firstIndex(where: { $0.number == week.number }) {
            trainingUnits[u].weeks[w] = week
        }
        saveTrainingUnits()
    }
    func loadWeekProgress(_ week: inout Week, unitId: UUID) {
        guard let dict = defaults.dictionary(forKey: progressKey(unitId: unitId, weekNumber: week.number)) as? [String: Bool]
        else { return }
        func restore(_ list: inout [Exercise], prefix: String) {
            for i in list.indices {
                for j in list[i].sets.indices {
                    if let v = dict["\(prefix)_\(i)_\(j)"] { list[i].sets[j].isCompleted = v }
                }
            }
        }
        restore(&week.warmUp,  prefix: "warmUp")
        restore(&week.exercises, prefix: "exercises")
        restore(&week.coolDown,  prefix: "coolDown")
    }
    func resetWeekProgress(_ week: Week, unitId: UUID) {
        var w = week
        func reset(_ list: inout [Exercise]) {
            for i in list.indices { for j in list[i].sets.indices { list[i].sets[j].isCompleted = false } }
        }
        reset(&w.warmUp); reset(&w.exercises); reset(&w.coolDown)
        saveWeekProgress(w, unitId: unitId)
    }

    // MARK: - Progress-Updater
    func updateWorkoutProgress(from trainingStore: TrainingStore) {
        let thisWeek = trainingStore.history.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
        if let i = challenges.firstIndex(where: { $0.type == .workouts }) {
            let prev = challenges[i].progress
            challenges[i].progress = thisWeek.count
            if thisWeek.count > prev {
                // More celebratory notifications
                let emojis = ["🔥", "💪", "⭐", "🎉", "🏆"]
                let emoji = emojis.randomElement()!
                let userName = UserDefaults.standard.string(forKey: "userName") ?? ""
                let namePrefix = userName.isEmpty ? "" : "\(userName), "
                
                let title = LocalizedStrings.de["notifications.workoutDone"] ?? "\(namePrefix)Workout erledigt! \(emoji)"
                let body  = LocalizedStrings.de["notifications.workoutDoneBody"] ?? "Super! Du hast heute ein Workout abgeschlossen 💪"
                NotificationManager.shared.scheduleNotification(title: title, body: body)
                
                // Check for streak milestone
                if thisWeek.count >= 5 {
                    NotificationManager.shared.notifyStreakMilestone(days: thisWeek.count)
                }
            }
            saveActiveChallenges()
        }
    }

    private func entryVolumeKg(from entry: TrainingEntry) -> Double {
        // 1) Bevorzugt totalWeight, falls vorhanden
        let mirror = Mirror(reflecting: entry)
        if let tw = mirror.children.first(where: { $0.label == "totalWeight" })?.value as? Double {
            return tw
        }
        // 2) Fallback: aus Sets berechnen
        let exMirror = mirror.children.first { $0.label == "exercises" }?.value
        if let exercises = exMirror as? [Any] {
            var sum: Double = 0
            for ex in exercises {
                let exM = Mirror(reflecting: ex)
                if let sets = exM.children.first(where: { $0.label == "sets" })?.value as? [Any] {
                    for s in sets {
                        let sM = Mirror(reflecting: s)
                        let wStr = (sM.children.first { $0.label == "weight" }?.value as? String) ?? "0"
                        let rStr = (sM.children.first { $0.label == "reps" }?.value as? String) ?? "0"
                        let weight = Double(wStr.replacingOccurrences(of: ",", with: ".").filter("0123456789.".contains)) ?? 0
                        let reps   = Double(rStr.filter("0123456789".contains)) ?? 0
                        sum += weight * reps
                    }
                }
            }
            return sum
        }
        return 0
    }

    func updateSteps(from healthKit: HealthKitManager) {
        // Tageswert für heute persistieren (für Wochen-Summen)
        let key = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        stepsLog[key] = healthKit.todaySteps
        saveStepsLog()

        let cal = Calendar.current

        func isWeekly(_ ch: Challenge) -> Bool {
            ch.goal >= 50_000 ||
            ch.title.localizedCaseInsensitiveContains("woche") ||
            ch.title.localizedCaseInsensitiveContains("week")
        }
        func last7Sum(reference: Date = Date()) -> Int {
            var sum = 0
            for i in 0..<7 {
                if let d = cal.date(byAdding: .day, value: -i, to: reference) {
                    let k = ISO8601DateFormatter.string(from: d, timeZone: .current, formatOptions: [.withFullDate])
                    sum += (stepsLog[k] ?? 0)
                }
            }
            return sum
        }

        for i in challenges.indices where challenges[i].type == .steps {
            let prev = challenges[i].progress
            if isWeekly(challenges[i]) {
                challenges[i].progress = last7Sum()
            } else {
                challenges[i].progress = healthKit.todaySteps
            }
            if challenges[i].progress >= challenges[i].goal && prev < challenges[i].goal {
                // More celebratory steps notification
                let emojis = ["🚶", "🏃", "⭐", "🎯", "🏆"]
                let emoji = emojis.randomElement()!
                let userName = UserDefaults.standard.string(forKey: "userName") ?? ""
                let namePrefix = userName.isEmpty ? "" : "\(userName), "
                
                let title = LocalizedStrings.de["notifications.stepsDone"] ?? "\(namePrefix)Schrittziel erreicht! \(emoji)"
                let body = LocalizedStrings.de["notifications.stepsDoneBody"] ?? "Toll! Du hast \(challenges[i].goal) Schritte geschafft!"
                NotificationManager.shared.scheduleNotification(title: title, body: body)
                
                // Notify challenge progress near completion
                NotificationManager.shared.notifyChallengeProgress(
                    challengeName: challenges[i].title,
                    progress: challenges[i].progress,
                    goal: challenges[i].goal
                )
            }
        }
        saveActiveChallenges()
    }

    func updateStreak(from trainingStore: TrainingStore) {
        let cal = Calendar.current
        let trainedDays = Set(trainingStore.history.map { cal.startOfDay(for: $0.date) })
        guard let lastDay = trainedDays.max() else {
            for i in challenges.indices where challenges[i].type == .streak { challenges[i].progress = 0 }
            saveActiveChallenges()
            return
        }
        var s = 0
        var cur = lastDay
        while trainedDays.contains(cur) {
            s += 1
            cur = cal.date(byAdding: .day, value: -1, to: cur)!
        }
        for i in challenges.indices where challenges[i].type == .streak { challenges[i].progress = s }
        saveActiveChallenges()
    }

    func updateWeeklySessions(from trainingStore: TrainingStore) {
        let cal = Calendar.current
        let thisWeek = trainingStore.history
            .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        let distinct = Set(thisWeek.map { cal.startOfDay(for: $0.date) }).count
        for i in challenges.indices where challenges[i].type == .weeklySessions { challenges[i].progress = distinct }
        saveActiveChallenges()
    }

    // MARK: - Weekly Volume (kg)
    func addLift(kg: Double, at date: Date = Date()) {
        guard kg > 0 else { return }
        liftLog.append(.init(date: date, kg: kg))
        saveLiftLog()
        updateWeeklyVolume()
    }

    func updateWeeklyVolume(reference: Date = Date(), from trainingStore: TrainingStore? = nil) {
        let cal = Calendar.current

        var weekFromEntries: Double = 0
        if let ts = trainingStore {
            let thisWeek = ts.history.filter { cal.isDate($0.date, equalTo: reference, toGranularity: .weekOfYear) }
            weekFromEntries = thisWeek.reduce(0.0) { $0 + entryVolumeKg(from: $1) }
        }

        let weekFromLiftLog = liftLog
            .filter { cal.isDate($0.date, equalTo: reference, toGranularity: .weekOfYear) }
            .reduce(0.0) { $0 + $1.kg }

        let total = Int((weekFromEntries + weekFromLiftLog).rounded())
        for i in challenges.indices where challenges[i].type == .weeklyVolume {
            challenges[i].progress = total
        }
        saveActiveChallenges()
    }
} // ⬅️ Ende ChallengeStore


// MARK: - Templates, Recalc & Swap
extension ChallengeStore {

    static func defaultTemplates(appSettings s: AppSettings) -> [Challenge] {
        [
            // Workouts
            Challenge(title: s.localized("challenge.workouts.title"), type: .workouts,
                      description: s.localized("challenge.workouts.desc"),
                      goal: 5, progress: 0, unit: s.localized("workouts.unit")),
            Challenge(title: "7 Workouts/Woche", type: .workouts,
                      description: "Jeden Tag ein Workout absolvieren.",
                      goal: 7, progress: 0, unit: s.localized("workouts.unit")),
            Challenge(title: "3 Workouts/Woche", type: .workouts,
                      description: "Solider Einstieg für Beständigkeit.",
                      goal: 3, progress: 0, unit: s.localized("workouts.unit")),
            Challenge(title: "10 Workouts in 14 Tagen", type: .workouts,
                      description: "Intensive Phase für einen Schub.",
                      goal: 10, progress: 0, unit: s.localized("workouts.unit")),

            // Steps
            Challenge(title: s.localized("challenge.steps.title"), type: .steps,
                      description: s.localized("challenge.steps.desc"),
                      goal: 10_000, progress: 0, unit: s.localized("steps.unit")),
            Challenge(title: "12.000 Schritte/Tag", type: .steps,
                      description: "Spürbar mehr Bewegung im Alltag.",
                      goal: 12_000, progress: 0, unit: s.localized("steps.unit")),
            Challenge(title: "15.000 Schritte/Tag", type: .steps,
                      description: "Ambitioniertes Schrittziel.",
                      goal: 15_000, progress: 0, unit: s.localized("steps.unit")),

            // Weekly Volume
            Challenge(title: "5.000 kg/Woche", type: .weeklyVolume,
                      description: "Gesamt bewegtes Gewicht pro Woche.",
                      goal: 5_000, progress: 0, unit: "kg"),
            Challenge(title: "10.000 kg/Woche", type: .weeklyVolume,
                      description: "Ambitioniertes Trainingsvolumen.",
                      goal: 10_000, progress: 0, unit: "kg"),

            // Streak
            Challenge(title: "3-Tage-Streak", type: .streak,
                      description: "Trainiere 3 Tage hintereinander.",
                      goal: 3, progress: 0, unit: "Tage"),
            Challenge(title: "5-Tage-Streak", type: .streak,
                      description: "Trainiere 5 Tage hintereinander.",
                      goal: 5, progress: 0, unit: "Tage"),

            // Weekly Sessions
            Challenge(title: "3 aktive Tage/Woche", type: .weeklySessions,
                      description: "An 3 verschiedenen Tagen trainieren.",
                      goal: 3, progress: 0, unit: "Tage"),
            Challenge(title: "5 aktive Tage/Woche", type: .weeklySessions,
                      description: "An 5 verschiedenen Tagen trainieren.",
                      goal: 5, progress: 0, unit: "Tage")
        ]
    }

    /// Fortschritt aus vorhandenen App-Daten neu berechnen
    func recalcProgress(for template: Challenge,
                        trainingStore: TrainingStore,
                        healthKit: HealthKitManager) -> Int {

        let cal = Calendar.current

        switch template.type {

        case .workouts:
            let thisWeek = trainingStore.history.filter {
                cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
            }
            return thisWeek.count

        case .weeklySessions:
            let days = trainingStore.history
                .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
                .map { cal.startOfDay(for: $0.date) }
            return Set(days).count

        case .streak:
            let trainedDays = Set(trainingStore.history.map { cal.startOfDay(for: $0.date) })
            var s = 0
            var cur = cal.startOfDay(for: Date())
            while trainedDays.contains(cur) {
                s += 1
                cur = cal.date(byAdding: .day, value: -1, to: cur)!
            }
            return s

        case .steps:
            let isWeekly =
                template.goal >= 50_000 ||
                template.title.localizedCaseInsensitiveContains("woche") ||
                template.title.localizedCaseInsensitiveContains("week")

            if isWeekly {
                var sum = 0
                for i in 0..<7 {
                    if let d = cal.date(byAdding: .day, value: -i, to: Date()) {
                        let k = ISO8601DateFormatter.string(from: d, timeZone: .current, formatOptions: [.withFullDate])
                        sum += (stepsLog[k] ?? 0)
                    }
                }
                return sum
            } else {
                return healthKit.todaySteps
            }

        case .weeklyVolume:
            let weekEntries = trainingStore.history
                .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
            let fromEntries = weekEntries.reduce(0.0) { $0 + entryVolumeKg(from: $1) }

            let fromLiftLog = liftLog
                .filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
                .reduce(0.0) { $0 + $1.kg }

            return Int((fromEntries + fromLiftLog).rounded())
        }
    }

    /// Swap: immer aus Daten neu berechnen
    func swapChallenge(currentId: UUID,
                       with template: Challenge,
                       trainingStore: TrainingStore,
                       healthKit: HealthKitManager) {
        guard let idx = challenges.firstIndex(where: { $0.id == currentId }) else { return }
        let old = challenges[idx]

        let computed = recalcProgress(for: template, trainingStore: trainingStore, healthKit: healthKit)
        let clamped = max(0, min(computed, template.goal))

        challenges[idx] = Challenge(
            id: old.id,
            title: template.title,
            type: template.type,
            description: template.description,
            goal: template.goal,
            progress: clamped,
            unit: template.unit
        )
        saveActiveChallenges()
    }
}

// MARK: - Challenges Dashboard mit Coachmark


// MARK: - Icon-Auswahl für ChallengeType (failsafe)
@inline(__always)
func safeIcon(for type: ChallengeType) -> String {
    switch type {
    case .workouts:       return "dumbbell.fill"
    case .steps:          return "figure.walk"
    case .weeklyVolume:
        if #available(iOS 17.0, *) { return "scalemass" }
        return "shippingbox" // Fallback vor iOS 17
    case .streak:         return "flame"
    case .weeklySessions: return "calendar"
    }
}
// MARK: - Anzeigename für ChallengeType
extension ChallengeType {
    var displayTitle: String {
        switch self {
        case .workouts:       return "Workouts"
        case .steps:          return "Schritte"
        case .weeklyVolume:   return "Trainingsvolumen"
        case .streak:         return "Streak"
        case .weeklySessions: return "Aktive Tage"
        }
    }
}
// MARK: - Mini-Hinweis: „halten & tauschen“
struct HoldPulseIndicator: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 64, height: 64)
                .blur(radius: 6)
                .scaleEffect(animate ? 1.25 : 0.8)
                .opacity(animate ? 0.0 : 1.0)

            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                .accessibilityHidden(true)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}
// MARK: - Challenge Card (Design-System) – mit kg/lb Anzeige
// MARK: - ChallengeCard (mit dynamischem kg/lb im Titel & Progress-Text)

// MARK: - ChallengeCard (voll lokalisiert + kg/lb dynamisch)
struct ChallengeCard: View {
    let challenge: Challenge
    var onLongPress: (() -> Void)? = nil
    var compact: Bool = false

    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t

    // Einheit aus Settings (global)
    @AppStorage("units.weight") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            // Icon + Ring
            ZStack {
                ProgressRing(
                    progress: progressRatio,
                    color: challenge.badge.color,
                    lineWidth: compact ? 4 : 6
                )
                .frame(width: compact ? 44 : 60, height: compact ? 44 : 60)

                Image(systemName: challenge.icon)
                    .font(.system(size: compact ? 20 : 24, weight: .semibold))
                    .foregroundStyle(challenge.badge.color)
            }

            // Texte + Progress
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                // 🔁 Titel IMMER lokalisiert (inkl. kg→lb bei Weekly Volume)
                Text(displayTitle)
                    .font(compact ? .subheadline.weight(.semibold) : .headline)
                    .lineLimit(1)

                // 🔁 Beschreibung IMMER lokalisiert
                Text(displayDesc)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 1 : 2)

                ProgressView(value: Double(challenge.progress), total: Double(max(challenge.goal, 1)))
                    .progressViewStyle(.linear)
                    .scaleEffect(x: 1, y: compact ? 0.8 : 1, anchor: .center)

                // 🔁 Fortschrittstext lokalisiert (Einheit abhängig vom Typ)
                Text(progressText)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: compact ? 4 : 8)

            if challenge.badge != .none {
                Image(systemName: badgeIcon)
                    .font(compact ? .callout : .title3)
                    .foregroundStyle(challenge.badge.color)
            }
        }
        .padding(compact ? 10 : 14)
        .appElevatedCard()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress?() }
        )
    }

    // MARK: Anzeige-/Hilfswerte
    private var isWeightVolume: Bool { challenge.type == .weeklyVolume }

    private var displayTitle: String {
        localizedTitle(for: challenge, convertWeightIfNeeded: true)
    }

    private var displayDesc: String {
        localizedDesc(for: challenge)
    }

    private var progressText: String {
        if isWeightVolume {
            let p = Int(weightUnit.fromKilograms(Double(challenge.progress)).rounded())
            let g = Int(weightUnit.fromKilograms(Double(challenge.goal)).rounded())
            return "\(formatInt(min(p, g)))/\(formatInt(g)) \(weightUnit.symbol)"
        } else {
            return "\(min(challenge.progress, challenge.goal))/\(challenge.goal) \(unitForType(challenge.type))"
        }
    }

    private var progressRatio: Double {
        Double(challenge.progress) / Double(max(challenge.goal, 1))
    }

    private var badgeIcon: String {
        switch challenge.badge {
        case .gold: "trophy.fill"
        case .silver: "medal.fill"
        case .bronze: "star.fill"
        default: "circle"
        }
    }

    // MARK: Lokalisierungs-Bridge
    private func loc(_ key: String) -> String { appSettings.localized(key) }

    private func unitForType(_ type: ChallengeType) -> String {
        switch type {
        case .workouts:       return loc("workouts.unit")
        case .steps:          return loc("steps.unit")
        case .weeklyVolume:   return weightUnit.symbol
        case .streak, .weeklySessions: return loc("days.unit")
        }
    }

    /// Liefert IMMER den zur aktuellen Sprache passenden Titel
    private func localizedTitle(for c: Challenge, convertWeightIfNeeded: Bool = false) -> String {
        let t: String
        switch c.type {
        case .workouts:
            switch c.goal {
            case 3:  t = loc("tpl.workouts.3.title")
            case 5:  t = loc("tpl.workouts.5.title")
            case 7:  t = loc("tpl.workouts.7.title")
            case 10: t = loc("tpl.workouts.10in14.title")
            default: t = c.title
            }
        case .steps:
            switch c.goal {
            case 10_000: t = loc("tpl.steps.10k.title")
            case 12_000: t = loc("tpl.steps.12k.title")
            case 15_000: t = loc("tpl.steps.15k.title")
            default:     t = c.title
            }
        case .weeklyVolume:
            switch c.goal {
            case 5_000:  t = loc("tpl.volume.5k.title")
            case 10_000: t = loc("tpl.volume.10k.title")
            default:     t = c.title
            }
        case .streak:
            switch c.goal {
            case 3:  t = loc("tpl.streak.3.title")
            case 5:  t = loc("tpl.streak.5.title")
            default: t = c.title
            }
        case .weeklySessions:
            switch c.goal {
            case 3:  t = loc("tpl.days.3.title")
            case 5:  t = loc("tpl.days.5.title")
            default: t = c.title
            }
        }

        guard convertWeightIfNeeded && c.type == .weeklyVolume else { return t }
        // Zahl & Einheit im Titel (z. B. "5.000 kg/Woche") dynamisch anpassen
        let converted = Int(weightUnit.fromKilograms(Double(c.goal)).rounded())
        let num = formatInt(converted)
        return replaceKgInTitle(t, withNumberString: num, unitSymbol: weightUnit.symbol)
    }

    private func localizedDesc(for c: Challenge) -> String {
        switch c.type {
        case .workouts:
            switch c.goal {
            case 3:  return loc("tpl.workouts.3.desc")
            case 5:  return loc("tpl.workouts.5.desc")
            case 7:  return loc("tpl.workouts.7.desc")
            case 10: return loc("tpl.workouts.10in14.desc")
            default: return c.description
            }
        case .steps:
            switch c.goal {
            case 10_000: return loc("tpl.steps.10k.desc")
            case 12_000: return loc("tpl.steps.12k.desc")
            case 15_000: return loc("tpl.steps.15k.desc")
            default:     return c.description
            }
        case .weeklyVolume:
            switch c.goal {
            case 5_000:  return loc("tpl.volume.5k.desc")
            case 10_000: return loc("tpl.volume.10k.desc")
            default:     return c.description
            }
        case .streak:
            switch c.goal {
            case 3:  return loc("tpl.streak.3.desc")
            case 5:  return loc("tpl.streak.5.desc")
            default: return c.description
            }
        case .weeklySessions:
            switch c.goal {
            case 3:  return loc("tpl.days.3.desc")
            case 5:  return loc("tpl.days.5.desc")
            default: return c.description
            }
        }
    }

    // MARK: Utils
    private func formatInt(_ v: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    /// "5.000 kg/Woche" → "11,023 lb/week" (Suffix kommt aus dem lokalisierten Titel)
    private func replaceKgInTitle(_ title: String, withNumberString n: String, unitSymbol: String) -> String {
        if let r = title.range(of: "kg") {
            let suffix = title[r.upperBound...] // z. B. "/Woche" oder "/week"
            return "\(n) \(unitSymbol)\(suffix)"
        } else {
            return "\(n) \(unitSymbol) " + title
        }
    }
}





// MARK: - Coachmark Bubble (neutral & kompakt)
struct CoachmarkBubble: View {
    let text: String
    var onDismiss: () -> Void
    @Environment(\.designTokens) private var t

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.point.up.left.fill").imageScale(.large)
            Text(text).font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").imageScale(.large)
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(t.palette.outline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}



// MARK: - Week Card (neutral, DS)

// MARK: - Training Unit Card (horizontal Carousel)


    // gleich wie oben
    @inline(__always)
    private func unitGradientColors(for title: String, scheme: ColorScheme) -> [Color] {
        let neutralStart = scheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)
        let neutralEnd   = scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03)
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch t {
        case "shred & sculpt": return [Color.red.opacity(0.7), Color.orange.opacity(0.5)]
        case "full body blast": return [Color.blue.opacity(0.6), Color.purple.opacity(0.5)]
        case "core mastery","core crusher","bauch fokus","core focus": return [Color.gray.opacity(0.30), Color.gray.opacity(0.15)]
        case "hiit hero": return [Color.pink.opacity(0.7), Color.purple.opacity(0.5)]
        case "flex & flow","stretch & mobility","mobility flow","beweglichkeit","stretching": return [Color.cyan.opacity(0.55), Color.teal.opacity(0.45)]
        case "meditation","mindful minutes","meditation basics","achtsamkeit": return [Color.indigo.opacity(0.55), Color.blue.opacity(0.35)]
        default: return [neutralStart, neutralEnd]
        }
    }





// MARK: - Swap-Sheet: ChallengeSwapSheet (voll lokalisiert + kg/lb dynamisch)
struct ChallengeSwapSheet: View {
    let current: Challenge
    let templates: [Challenge]
    let onSelect: (_ template: Challenge, _ keepProgress: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    @Environment(\.colorScheme)  private var scheme
    @EnvironmentObject var appSettings: AppSettings

    @State private var keepProgress = true
    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var onlyCurrentType = false

    // Einheit aus Settings
    @AppStorage("units.weight") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("challenge.swap.title")).font(.title3.weight(.semibold))
                    Text("\(loc("current")): \(currentHeaderTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.thinMaterial)

            // Search + Toggles
            VStack(spacing: 10) {
                searchBar
                Toggle(loc("keep.progress"), isOn: $keepProgress).tint(t.palette.primary)
                Toggle(loc("filter.currentTypeOnly"), isOn: $onlyCurrentType).tint(t.palette.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Sections
            ScrollView {
                let sections = makeSections(query: query, onlyCurrentType: onlyCurrentType)
                LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                    if sections.isEmpty {
                        EmptyState(
                            title: loc("templates.empty.title"),
                            subtitle: loc("templates.empty.subtitle")
                        )
                        .padding(.top, 24)
                    } else {
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.items, id: \.id) { tpl in
                                    TemplateRow(
                                        template: tpl,
                                        isSelected: selectedID == tpl.id
                                    )
                                    .environmentObject(appSettings)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: scheme == .dark
                                                    ? [Color.white.opacity(0.10), Color.white.opacity(0.06)]
                                                    : [Color(UIColor.secondarySystemBackground),
                                                       Color(UIColor.systemBackground)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(scheme == .dark
                                                    ? Color.white.opacity(0.12)
                                                    : Color.black.opacity(0.06),
                                                    lineWidth: 1)
                                    )
                                    .shadow(color: scheme == .dark
                                            ? .black.opacity(0.40)
                                            : .black.opacity(0.08),
                                            radius: 10, x: 0, y: 5)
                                    .onTapGesture {
                                        selectedID = tpl.id
                                        onSelect(tpl, keepProgress)
                                        dismiss()
                                    }
                                }
                                .padding(.bottom, 6)
                            } header: {
                                SectionHeader(
                                    title: typeTitle(section.id),
                                    icon: safeIcon(for: section.id),
                                    count: section.items.count,
                                    highlighted: section.id == current.type
                                )
                                .background(
                                    (scheme == .dark
                                     ? Color.white.opacity(0.04)
                                     : Color(UIColor.systemGroupedBackground))
                                    .ignoresSafeArea()
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Header-Titel (lokalisiert + ggf. kg/lb)
    private var currentHeaderTitle: String {
        localizedTitle(for: current, convertWeightIfNeeded: true)
    }

    // MARK: - Suche (lokalisierter Placeholder)
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(loc("templates.search.placeholder"), text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .dark ? Color.white.opacity(0.08) : Color(UIColor.secondarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Datenaufbereitung (lokalisierte Suche + Dedupe + Sort)
    private func makeSections(query: String, onlyCurrentType: Bool) -> [TemplateSection] {
        let base = templates.filter {
            // Suche über *lokalisierte* Titel/Beschreibungen
            query.isEmpty
            || localizedTitle(for: $0).localizedCaseInsensitiveContains(query)
            || localizedDesc(for: $0).localizedCaseInsensitiveContains(query)
        }

        let filtered = onlyCurrentType ? base.filter { $0.type == current.type } : base

        // 🔑 Duplikate rauswerfen (gleicher Typ + gleiches Ziel)
        let unique = filtered.uniqued { DedupKey(type: $0.type, goal: $0.goal) }

        // Gruppieren + sortieren
        let byType = Dictionary(grouping: unique, by: { $0.type })
        let order: [ChallengeType] = [current.type] + ChallengeType.allCases.filter { $0 != current.type }

        var result: [TemplateSection] = []
        for t in order {
            guard let list = byType[t] else { continue }
            let sorted = list.sorted {
                if $0.goal == $1.goal {
                    return localizedTitle(for: $0)
                        .localizedStandardCompare(localizedTitle(for: $1)) == .orderedAscending
                } else {
                    return $0.goal < $1.goal
                }
            }
            result.append(.init(id: t, title: typeTitle(t), icon: safeIcon(for: t), items: sorted))
        }
        return result
    }

    // MARK: - Lokalisierungs-Helpers
    private func loc(_ key: String) -> String { appSettings.localized(key) }

    private func typeTitle(_ type: ChallengeType) -> String {
        switch type {
        case .workouts:       return loc("challenge.type.workouts")
        case .steps:          return loc("challenge.type.steps")
        case .weeklyVolume:   return loc("challenge.type.weeklyVolume")
        case .streak:         return loc("challenge.type.streak")
        case .weeklySessions: return loc("challenge.type.weeklySessions")
        }
    }

    private func unitForType(_ type: ChallengeType) -> String {
        switch type {
        case .workouts:       return loc("workouts.unit")
        case .steps:          return loc("steps.unit")
        case .weeklyVolume:   return weightUnit.symbol   // Anzeige-Einheit dynamisch
        case .streak, .weeklySessions: return loc("days.unit")
        }
    }

    /// Liefert IMMER den zur aktuellen Sprache passenden Titel
    private func localizedTitle(for c: Challenge, convertWeightIfNeeded: Bool = false) -> String {
        let t: String
        switch c.type {
        case .workouts:
            switch c.goal {
            case 3:  t = loc("tpl.workouts.3.title")
            case 5:  t = loc("tpl.workouts.5.title")
            case 7:  t = loc("tpl.workouts.7.title")
            case 10: t = loc("tpl.workouts.10in14.title")
            default: t = c.title
            }
        case .steps:
            switch c.goal {
            case 10_000: t = loc("tpl.steps.10k.title")
            case 12_000: t = loc("tpl.steps.12k.title")
            case 15_000: t = loc("tpl.steps.15k.title")
            default:     t = c.title
            }
        case .weeklyVolume:
            switch c.goal {
            case 5_000:  t = loc("tpl.volume.5k.title")
            case 10_000: t = loc("tpl.volume.10k.title")
            default:     t = c.title
            }
        case .streak:
            switch c.goal {
            case 3:  t = loc("tpl.streak.3.title")
            case 5:  t = loc("tpl.streak.5.title")
            default: t = c.title
            }
        case .weeklySessions:
            switch c.goal {
            case 3:  t = loc("tpl.days.3.title")
            case 5:  t = loc("tpl.days.5.title")
            default: t = c.title
            }
        }

        guard convertWeightIfNeeded && c.type == .weeklyVolume else { return t }
        // Zahl & Einheit im Titel (z. B. "5.000 kg/Woche") dynamisch anpassen
        let converted = Int(weightUnit.fromKilograms(Double(c.goal)).rounded())
        let num = formatInt(converted)
        return replaceKgInTitle(t, withNumberString: num, unitSymbol: weightUnit.symbol)
    }

    private func localizedDesc(for c: Challenge) -> String {
        switch c.type {
        case .workouts:
            switch c.goal {
            case 3:  return loc("tpl.workouts.3.desc")
            case 5:  return loc("tpl.workouts.5.desc")
            case 7:  return loc("tpl.workouts.7.desc")
            case 10: return loc("tpl.workouts.10in14.desc")
            default: return c.description
            }
        case .steps:
            switch c.goal {
            case 10_000: return loc("tpl.steps.10k.desc")
            case 12_000: return loc("tpl.steps.12k.desc")
            case 15_000: return loc("tpl.steps.15k.desc")
            default:     return c.description
            }
        case .weeklyVolume:
            switch c.goal {
            case 5_000:  return loc("tpl.volume.5k.desc")
            case 10_000: return loc("tpl.volume.10k.desc")
            default:     return c.description
            }
        case .streak:
            switch c.goal {
            case 3:  return loc("tpl.streak.3.desc")
            case 5:  return loc("tpl.streak.5.desc")
            default: return c.description
            }
        case .weeklySessions:
            switch c.goal {
            case 3:  return loc("tpl.days.3.desc")
            case 5:  return loc("tpl.days.5.desc")
            default: return c.description
            }
        }
    }

    // MARK: - Utils
    private func formatInt(_ v: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
    private func replaceKgInTitle(_ title: String, withNumberString n: String, unitSymbol: String) -> String {
        if let r = title.range(of: "kg") {
            let suffix = title[r.upperBound...]
            return "\(n) \(unitSymbol)\(suffix)"
        } else {
            return "\(n) \(unitSymbol) " + title
        }
    }
}

// MARK: - Row (Titel & rechte Zahl dynamisch, voll lokalisiert)
private struct TemplateRow: View {
    let template: Challenge
    let isSelected: Bool
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appSettings: AppSettings

    @AppStorage("units.weight") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        let chipFill = Color(UIColor.tertiarySystemFill)

        HStack(alignment: .top, spacing: 12) {
            ZstackIcon

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(displayTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    Text(goalRightText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(displayDesc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .imageScale(.large)
                    .accessibilityLabel("Ausgewählt")
            }
        }
        .padding(12)
    }

    private var ZstackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.tertiarySystemFill))
            Image(systemName: template.icon)
                .font(.title3)
        }
        .frame(width: 48, height: 48)
    }

    // Anzeige-/Hilfswerte
    private var displayTitle: String {
        localizedTitle(for: template, convertWeightIfNeeded: true)
    }
    private var displayDesc: String {
        localizedDesc(for: template)
    }
    private var goalRightText: String {
        if template.type == .weeklyVolume {
            let g = Int(weightUnit.fromKilograms(Double(template.goal)).rounded())
            return "\(formatInt(g)) \(weightUnit.symbol)"
        } else {
            return "\(template.goal) \(unitForType(template.type))"
        }
    }

    // MARK: Lokalisierungs-Bridge (duplizierte Helper aus dem Sheet)
    private func loc(_ key: String) -> String { appSettings.localized(key) }

    private func unitForType(_ type: ChallengeType) -> String {
        switch type {
        case .workouts:       return loc("workouts.unit")
        case .steps:          return loc("steps.unit")
        case .weeklyVolume:   return weightUnit.symbol
        case .streak, .weeklySessions: return loc("days.unit")
        }
    }

    private func localizedTitle(for c: Challenge, convertWeightIfNeeded: Bool = false) -> String {
        let t: String
        switch c.type {
        case .workouts:
            switch c.goal {
            case 3:  t = loc("tpl.workouts.3.title")
            case 5:  t = loc("tpl.workouts.5.title")
            case 7:  t = loc("tpl.workouts.7.title")
            case 10: t = loc("tpl.workouts.10in14.title")
            default: t = c.title
            }
        case .steps:
            switch c.goal {
            case 10_000: t = loc("tpl.steps.10k.title")
            case 12_000: t = loc("tpl.steps.12k.title")
            case 15_000: t = loc("tpl.steps.15k.title")
            default:     t = c.title
            }
        case .weeklyVolume:
            switch c.goal {
            case 5_000:  t = loc("tpl.volume.5k.title")
            case 10_000: t = loc("tpl.volume.10k.title")
            default:     t = c.title
            }
        case .streak:
            switch c.goal {
            case 3:  t = loc("tpl.streak.3.title")
            case 5:  t = loc("tpl.streak.5.title")
            default: t = c.title
            }
        case .weeklySessions:
            switch c.goal {
            case 3:  t = loc("tpl.days.3.title")
            case 5:  t = loc("tpl.days.5.title")
            default: t = c.title
            }
        }

        guard convertWeightIfNeeded && c.type == .weeklyVolume else { return t }
        let converted = Int(weightUnit.fromKilograms(Double(c.goal)).rounded())
        let num = formatInt(converted)
        return replaceKgInTitle(t, withNumberString: num, unitSymbol: weightUnit.symbol)
    }

    private func localizedDesc(for c: Challenge) -> String {
        switch c.type {
        case .workouts:
            switch c.goal {
            case 3:  return loc("tpl.workouts.3.desc")
            case 5:  return loc("tpl.workouts.5.desc")
            case 7:  return loc("tpl.workouts.7.desc")
            case 10: return loc("tpl.workouts.10in14.desc")
            default: return c.description
            }
        case .steps:
            switch c.goal {
            case 10_000: return loc("tpl.steps.10k.desc")
            case 12_000: return loc("tpl.steps.12k.desc")
            case 15_000: return loc("tpl.steps.15k.desc")
            default:     return c.description
            }
        case .weeklyVolume:
            switch c.goal {
            case 5_000:  return loc("tpl.volume.5k.desc")
            case 10_000: return loc("tpl.volume.10k.desc")
            default:     return c.description
            }
        case .streak:
            switch c.goal {
            case 3:  return loc("tpl.streak.3.desc")
            case 5:  return loc("tpl.streak.5.desc")
            default: return c.description
            }
        case .weeklySessions:
            switch c.goal {
            case 3:  return loc("tpl.days.3.desc")
            case 5:  return loc("tpl.days.5.desc")
            default: return c.description
            }
        }
    }

    // Utils
    private func formatInt(_ v: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
    private func replaceKgInTitle(_ title: String, withNumberString n: String, unitSymbol: String) -> String {
        if let r = title.range(of: "kg") {
            let suffix = title[r.upperBound...]
            return "\(n) \(unitSymbol)\(suffix)"
        } else {
            return "\(n) \(unitSymbol) " + title
        }
    }
}

// MARK: - Uniqued by key (behält die ERSTE Instanz)
// Dedup-Key, damit (type, goal) sicher Hashable ist – behält die ERSTE Instanz
private struct DedupKey: Hashable {
    let type: ChallengeType
    let goal: Int
}

// Wenn noch nicht vorhanden:
extension Sequence {
    func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return self.filter { seen.insert(key($0)).inserted }
    }
}

// MARK: - Sheet-Helfer
private struct TemplateSection: Identifiable {
    let id: ChallengeType
    let title: String
    let icon: String
    let items: [Challenge]
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    let count: Int
    let highlighted: Bool
    @Environment(\.designTokens) private var t

    private var fg: Color { highlighted ? .accentColor : .secondary }
    private var bgHighlight: Color { highlighted ? Color.accentColor.opacity(0.10) : .clear }

    var body: some View {
        ZStack {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(bgHighlight).allowsHitTesting(false)
        }
        .overlay(
            HStack(spacing: 12) {
                Image(systemName: icon).imageScale(.medium)
                Text(title).font(.callout.weight(.semibold))
                Spacer()
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(t.palette.secondary.opacity(0.15)))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        )
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
    }
}

private struct EmptyState: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").imageScale(.large)
            Text(title).font(.headline)
            Text(subtitle)
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}









// MARK: - Plan (gleiche Konstanten wie Timer)


// MARK: - Minimaler Exercise-Row
/// Zeile für Wochen-Workouts: zeigt IMMER „35s × <rounds> Rdn“ + Runden-Dots
// MARK: - Minimaler Exercise-Row (mit How-to Sheet)



// MARK: - Kleine UI-Bausteine




// Week-List mini card


// MARK: - Units-Merge (neue Defaults ergänzen, bestehendes behalten)
private func unitKey(_ u: TrainingUnit) -> String {
    // stabiler Schlüssel aus deinen Localization-Keys
    "\(u.titleKey)|\(u.subtitleKey)|\(u.durationKey)|\(u.levelKey)"
}

private func mergeUnitsWithDefaults(_ stored: [TrainingUnit], defaults: [TrainingUnit]) -> [TrainingUnit] {
    // Map per Key aus vorhandenen (persistierten) Einheiten
    var byKey = [String: TrainingUnit](uniqueKeysWithValues: stored.map { (unitKey($0), $0) })

    // Neue Defaults ergänzen, ohne vorhandene zu überschreiben
    for def in defaults {
        let key = unitKey(def)
        if byKey[key] == nil {
            byKey[key] = def
        } else {
            // Optional: bestimmte Felder aus Defaults übernehmen (z.B. neues Icon)
            // byKey[key]?.icon = def.icon
        }
    }

    // Sinnvolle Sortierung (z. B. anhand titleKey)
    return Array(byKey.values).sorted { $0.titleKey < $1.titleKey }
}


struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.7), value: progress)
        }
    }
}
// MARK: - Default Units
// MARK: - Default Units
extension ChallengeStore {
    static func defaultUnits() -> [TrainingUnit] {

        // Cooldown-Varianten (simpel halten)
        let cdA: [Exercise] = [
            Exercise(name: "Cobra Stretch", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")]),
            Exercise(name: "Child’s Pose", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")])
        ]
        let cdB: [Exercise] = [
            Exercise(name: "Katzenbuckel/Pferderücken", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")]),
            Exercise(name: "Spinal Twist (liegend)", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s pro Seite")])
        ]

        return [
            // ✅ Einheit 1 (ohne Equipment) – nur Basics
            TrainingUnit(
                titleKey: "training.shred.title",
                subtitleKey: "training.shred.subtitle",
                durationKey: "training.shred.duration",
                levelKey: "training.shred.level",
                icon: "flame",
                weeks: [
                    Week(
                        number: 1,
                        warmUp: [
                            Exercise(name: "Jumping Jacks", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")]),
                            Exercise(name: "Arm Circles", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")])
                        ],
                        exercises: [
                            Exercise(name: "Kniebeugen", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                            Exercise(name: "Liegestütze", sets: [ExerciseSet(weight: "Bodyweight", reps: "12–15")]),
                            Exercise(name: "Ausfallschritte", sets: [ExerciseSet(weight: "Bodyweight", reps: "12 pro Seite")])
                        ],
                        coolDown: cdA
                    ),
                    Week(
                        number: 2,
                        warmUp: [
                            Exercise(name: "High Knees", sets: [ExerciseSet(weight: "Bodyweight", reps: "40s")]),
                            
                        ],
                        exercises: [
                            Exercise(name: "Hip Bridges", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")]),
                            Exercise(name: "Liegestütze", sets: [ExerciseSet(weight: "Bodyweight", reps: "10–12")]),
                            Exercise(name: "Mountain Climbers", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")])
                        ],
                        coolDown: cdB
                    ),
                    Week(
                        number: 3,
                        warmUp: [
                            Exercise(name: "Butt Kicks", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s")]),
                           
                        ],
                        exercises: [
                            Exercise(name: "Hip Bridges", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                            Exercise(name: "Superman Pulls", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                            Exercise(name: "Russian Twists", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")])
                        ],
                        coolDown: cdA
                    ),
                    Week(
                        number: 4,
                        warmUp: [
                            Exercise(name: "Burpees", sets: [ExerciseSet(weight: "Bodyweight", reps: "10")]),
                            Exercise(name: "Arm Circles rückwärts", sets: [ExerciseSet(weight: "Bodyweight", reps: "40s")])
                        ],
                        exercises: [
                            Exercise(name: "Ausfallschritte", sets: [ExerciseSet(weight: "Bodyweight", reps: "10 pro Bein")]),
                            Exercise(name: "Liegestütze", sets: [ExerciseSet(weight: "Bodyweight", reps: "8–12")]),
                            Exercise(name: "Plank mit Schulter-Taps", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")])
                        ],
                        coolDown: cdB
                    ),
                    Week(
                        number: 5,
                        warmUp: [
                            Exercise(name: "Jumping Jacks", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")]),
                            Exercise(name: "Hip Opener", sets: [ExerciseSet(weight: "Bodyweight", reps: "40s")])
                        ],
                        exercises: [
                            Exercise(name: "Burpees", sets: [ExerciseSet(weight: "Bodyweight", reps: "12")]),
                            Exercise(name: "Liegestütze", sets: [ExerciseSet(weight: "Bodyweight", reps: "8–10")]),
                            Exercise(name: "Bicycle Crunches", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")])
                        ],
                        coolDown: cdA
                    ),
                    Week(
                        number: 6,
                        warmUp: [
                            Exercise(name: "Burpees", sets: [ExerciseSet(weight: "Bodyweight", reps: "12")]),
                            Exercise(name: "Side Lunges", sets: [ExerciseSet(weight: "Bodyweight", reps: "40s")])
                        ],
                        exercises: [
                            Exercise(name: "Kniebeugen", sets: [ExerciseSet(weight: "Bodyweight", reps: "12")]),
                            Exercise(name: "Superman Hold", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")]),
                            Exercise(name: "Plank", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")])
                        ],
                        coolDown: cdB
                    )
                ]
            ),

            // ✅ Einheit 2 (ohne Equipment) – nur Basics
            TrainingUnit(
                titleKey: "training.fullbody.title",
                subtitleKey: "training.fullbody.subtitle",
                durationKey: "training.fullbody.duration",
                levelKey: "training.fullbody.level",
                icon: "figure.strengthtraining.traditional",
                weeks: [
                    Week(
                        number: 1,
                        warmUp: [
                            Exercise(name: "Jumping Jacks", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")]),
                            Exercise(name: "Hip Opener", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")])
                        ],
                        exercises: [
                            Exercise(name: "Liegestütze", sets: [ExerciseSet(weight: "Bodyweight", reps: "12")]),
                            Exercise(name: "Superman Pulls", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                            Exercise(name: "Plank", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")])
                        ],
                        coolDown: cdA
                    ),
                    Week(
                        number: 2,
                        warmUp: [
                            Exercise(name: "High Knees", sets: [ExerciseSet(weight: "Bodyweight", reps: "75s")]),
                            Exercise(name: "Jumping Jacks", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")]),
                        ],
                        exercises: [
                            Exercise(name: "Liegestütze", sets: [ExerciseSet(weight: "Bodyweight", reps: "8–12")]),
                            Exercise(name: "Ausfallschritte", sets: [ExerciseSet(weight: "Bodyweight", reps: "12 pro Seite")]),
                            Exercise(name: "Side Plank", sets: [ExerciseSet(weight: "Bodyweight", reps: "20s pro Seite")])
                        ],
                        coolDown: cdB
                    ),
                    Week(
                        number: 3,
                        warmUp: [
                            Exercise(name: "Burpees", sets: [ExerciseSet(weight: "Bodyweight", reps: "8")]),
                          
                        ],
                        exercises: [
                            Exercise(name: "Hip Bridges", sets: [ExerciseSet(weight: "Bodyweight", reps: "18")]),
                            Exercise(name: "Superman Hold", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")]),
                            Exercise(name: "Reverse Crunches", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")])
                        ],
                        coolDown: cdA
                    ),
                    Week(
                        number: 4,
                        warmUp: [
                            Exercise(name: "Jumping Jacks", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")]),
                            Exercise(name: "Hip Opener", sets: [ExerciseSet(weight: "Bodyweight", reps: "40s")])
                        ],
                        exercises: [
                            Exercise(name: "Kniebeugen", sets: [ExerciseSet(weight: "Bodyweight", reps: "18")]),
                            Exercise(name: "Plank mit Schulter-Taps", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")]),
                            Exercise(name: "Russian Twists", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")])
                        ],
                        coolDown: cdB
                    ),
                    Week(
                        number: 5,
                        warmUp: [
                            Exercise(name: "High Knees", sets: [ExerciseSet(weight: "Bodyweight", reps: "90s")]),
                            Exercise(name: "Arm Circles", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")])
                        ],
                        exercises: [
                            Exercise(name: "Liegestütze", sets: [ExerciseSet(weight: "Bodyweight", reps: "10–12")]),
                            Exercise(name: "Superman Hold", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")]),
                            Exercise(name: "Plank mit Beinheben", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")])
                        ],
                        coolDown: cdA
                    ),
                    Week(
                        number: 6,
                        warmUp: [
                            Exercise(name: "Burpees", sets: [ExerciseSet(weight: "Bodyweight", reps: "12")]),
                            Exercise(name: "Hip Opener", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")])
                        ],
                        exercises: [
                            Exercise(name: "Hip Bridges", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                            Exercise(name: "Superman Pulls", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                            Exercise(name: "Plank", sets: [ExerciseSet(weight: "Bodyweight", reps: "40s")])
                        ],
                        coolDown: cdB
                    )
                ]
            ),

            // 🆕 STRETCHING / MOBILITY (unverändert)
            TrainingUnit(
                titleKey: "training.stretch.title",
                subtitleKey: "training.stretch.subtitle",
                durationKey: "training.stretch.duration",
                levelKey: "training.stretch.level",
                icon: "figure.cooldown",
                weeks: [
                    Week(
                        number: 1,
                        warmUp: [
                            Exercise(name: "Cat-Cow", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s")]),
                            Exercise(name: "Neck Rolls", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")])
                        ],
                        exercises: [
                            Exercise(name: "Hamstring Stretch", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s pro Seite")]),
                            Exercise(name: "Hip Flexor Stretch", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s pro Seite")]),
                            Exercise(name: "Hip Bridges", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                        ],
                        coolDown: [
                            Exercise(name: "Child’s Pose", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")]),
                          
                        ]
                    ),
                    Week(
                        number: 2,
                        warmUp: [
                            Exercise(name: "Cat-Cow", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s")]),
                        ],
                        exercises: [
                            Exercise(name: "Glute Stretch", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s pro Seite")]),
                            Exercise(name: "Shoulder Stretch", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s")]),
                            Exercise(name: "Lunging Straight Leg Calf Stretching ", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s pro Seite")])

                        ],
                        coolDown: [
                            Exercise(name: "Half Standing Forward Fold", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")])
                        ]
                    ),
                    Week(
                        number: 3,
                        warmUp: [
                            Exercise(name: "Cat-Cow", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")])

                        ],
                        exercises: [
                            Exercise(name: "Hip Flexor Stretch", sets: [ExerciseSet(weight: "Bodyweight", reps: "45–60s pro Seite")]),

                            Exercise(name: "Pectoral Doorway Stretch", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s pro Seite")]),
                            Exercise(name: "Lunging Straight Leg Calf Stretching ", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")])
                        ],
                        coolDown: [
                            Exercise(name: "Child’s Pose", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")])

                        ]
                    ),
                    Week(
                        number: 4,
                        warmUp: [
                            Exercise(name: "Arm Circles", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s")])
                        ],
                        exercises: [
                            Exercise(name: "Lateral Hip Opener", sets: [ExerciseSet(weight: "Bodyweight", reps: "60s pro Seite")]),
                            Exercise(name: "Cat-Cow", sets: [ExerciseSet(weight: "Bodyweight", reps: "45–60s")]),

                            Exercise(name: "Quad Stretch", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s pro Seite")])
                        ],
                        coolDown: [
                            Exercise(name: "Spinal Twist (liegend)", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s pro Seite")])

                        ]
                    )
                ]
            ),

            // 🆕 CORE / BAUCH-FOKUS (ohne Equipment) – nur Basics
            TrainingUnit(
                titleKey: "training.core.title",
                subtitleKey: "training.core.subtitle",
                durationKey: "training.core.duration",
                levelKey: "training.core.level",
                icon: "figure.core.training",
                weeks: [
                    Week(
                        number: 1,
                        warmUp: [
                            Exercise(name: "Dead Bug (aktivieren)", sets: [ExerciseSet(weight: "Bodyweight", reps: "10 pro Seite")]),
                            Exercise(name: "Hip Bridges", sets: [ExerciseSet(weight: "Bodyweight", reps: "12")])
                        ],
                        exercises: [
                            Exercise(name: "Plank", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")]),
                            Exercise(name: "Bicycle Crunches", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")]),
                            Exercise(name: "Side Plank", sets: [ExerciseSet(weight: "Bodyweight", reps: "20s pro Seite")])
                        ],
                        coolDown: cdA
                    ),
                    Week(
                        number: 2,
                        warmUp: [
                            Exercise(name: "Hollow Rock (leicht)", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")])
                        ],
                        exercises: [
                            Exercise(name: "Reverse Crunches", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                            Exercise(name: "Russian Twists", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")]),
                            Exercise(name: "Crunches", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")])
                        ],
                        coolDown: cdB
                    ),
                    Week(
                        number: 3,
                        warmUp: [
                            Exercise(name: "Bird Dog", sets: [ExerciseSet(weight: "Bodyweight", reps: "10 pro Seite")])
                        ],
                        exercises: [
                            Exercise(name: "Plank", sets: [ExerciseSet(weight: "Bodyweight", reps: "30s")]),
                            Exercise(name: "Toe Touches", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")]),
                            Exercise(name: "Side Plank", sets: [ExerciseSet(weight: "Bodyweight", reps: "12 pro Seite")])
                        ],
                        coolDown: cdA
                    ),
                    Week(
                        number: 4,
                        warmUp: [
                            Exercise(name: "Glute Bridge March", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")])
                        ],
                        exercises: [
                            Exercise(name: "Crunches", sets: [ExerciseSet(weight: "Bodyweight", reps: "20")]),
                            Exercise(name: "Reverse Crunches", sets: [ExerciseSet(weight: "Bodyweight", reps: "15")]),
                            Exercise(name: "Plank (fortgeschritten)", sets: [ExerciseSet(weight: "Bodyweight", reps: "45s")])
                        ],
                        coolDown: cdB
                    )
                ]
            )
        ]
    }
}

