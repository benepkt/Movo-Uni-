import Foundation
import HealthKit
import WidgetKit
import UserNotifications

// MARK: - HealthKitManager

@MainActor
final class HealthKitManager: ObservableObject {

    private let healthStore = HKHealthStore()

    // Published Werte für UI
    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var todayCalories: Int = 0  // Active energy burned today
    @Published private(set) var latestBodyFatPercent: Double?      // z.B. 18.4 (%)
    @Published private(set) var latestWeight: Double?              // kg
    @Published private(set) var latestRestingHeartRate: Double?    // z.B. 55 (bpm)
    @Published private(set) var latestVO2Max: Double?              // ml/kg/min
    @Published private(set) var latestRespiratoryRate: Double?     // count/min
    @Published private(set) var latestOxygenSaturation: Double?    // % (0.95 -> 95%)
    @Published private(set) var latestWristTemperature: Double?    // degC
    @Published private(set) var latestLeanBodyMass: Double?        // kg
    @Published private(set) var latestBMI: Double?                 // count
    @Published private(set) var latestHRV: Double?                 // ms (SDNN)

    // Live-Herzfrequenz (für dein Training)
    @Published private(set) var currentHeartRate: Double?          // bpm
    @Published private(set) var isHeartRateMonitoringActive: Bool = false

    // App-Status
    var dailyGoal: Int = 8_000

    // Referenzen für Queries
    private var stepsObserverQuery: HKObserverQuery?
    private var heartRateQuery: HKAnchoredObjectQuery?

    // Neu: Observer für Workouts & Gewicht
    private var workoutsObserverQuery: HKObserverQuery?
    private var bodyMassObserverQuery: HKObserverQuery?

    // 🔁 Stale-Handling für Herzfrequenz
    private var heartRateStaleTimer: Timer?
    private var lastHeartRateSampleDate: Date?
    private let heartRateValidity: TimeInterval = 60 // 1 Minute

    // 🔁 Keys für letzte benachrichtigte Daten
    private let lastNotifiedWorkoutEndDateKey = "hk.lastNotifiedWorkoutEndDate"
    private let lastNotifiedWeightDateKey     = "hk.lastNotifiedWeightDate"

    // 🚦 First-run/Initial-Sync Schutz
    private let firstLaunchDateKey            = "hk.firstLaunchDate"
    private let initialWorkoutSyncDoneKey     = "hk.initialWorkoutSyncDone"
    private let initialWeightSyncDoneKey      = "hk.initialWeightSyncDone"

    private var firstLaunchDate: Date {
        if let d = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date { return d }
        let now = Date()
        UserDefaults.standard.set(now, forKey: firstLaunchDateKey)
        return now
    }

    private func markInitialSyncDone(for key: String) {
        UserDefaults.standard.set(true, forKey: key)
    }

    private func isInitialSyncDone(for key: String) -> Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    // MARK: - Authorization (nur Lesen)
    /// Fragt (optional forciert) Lese-Rechte an und startet danach Background-Delivery + Initial-Refresh.
    func requestReadAuthorizationIfNeeded(readTypes: [HKObjectType], shareTypes: [HKObjectType] = [], forcePrompt: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Stelle sicher, dass firstLaunchDate existiert
        _ = firstLaunchDate

        if forcePrompt {
            do {
                let toShare = Set(shareTypes.compactMap { $0 as? HKSampleType })
                try await healthStore.requestAuthorization(toShare: toShare, read: Set(readTypes))
            } catch {
                // print("[HK] auth error:", error.localizedDescription)
            }
        }

        // Schritte, Workouts & Gewicht im Hintergrund beobachten
        await startBackgroundDelivery()   // Steps
        await startWorkoutObserver()      // Workouts (inkl. Wasser-Reminder)
        await startWeightObserver()       // Gewicht

        // initiale Werte holen
        refreshAll()
    }
    
    // MARK: - Central Authorization
    func requestPermissions() async {
        let allTypes: [HKObjectType?] = [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .height),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .vo2Max),
            HKObjectType.quantityType(forIdentifier: .respiratoryRate),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.workoutType()
        ]

        var readTypes = allTypes.compactMap { $0 }
        
        // Define Writeable Types (Share)
        // CRITICAL: Do NOT include Read-Only types like RestingHeartRate, VO2Max, WalkingSpeed here, or app will crash.
        let shareableTypes: [HKObjectType?] = [
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
            HKObjectType.quantityType(forIdentifier: .height),
            HKObjectType.quantityType(forIdentifier: .leanBodyMass),
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
            // ActiveEnergyBurned and StepCount can technically be written, usually fine to include if we want to write manual entries.
        ]
        var shareTypes = shareableTypes.compactMap { $0 }
        
        if #available(iOS 16.0, *) {
            if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                readTypes.append(wristTemp)
                // Wrist Temp is typically Read-Only from Watch
            }
        }

        // Request Read & Write (Share) for permissions
        await requestReadAuthorizationIfNeeded(
            readTypes: readTypes,
            shareTypes: shareTypes,
            forcePrompt: true 
        )
    }
    
    // MARK: - Profile Import Helper
    /// Fetches latest available metrics for Profile import safely
    func fetchLatestProfileMetrics() async -> (weight: Double?, height: Double?, bodyFat: Double?, restingHR: Double?) {
        guard await requestAuthForProfileImport() else { return (nil, nil, nil, nil) }
        
        async let w = fetchSingleQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        async let h = fetchSingleQuantity(.height, unit: .meterUnit(with: .centi))
        async let bf = fetchSingleQuantity(.bodyFatPercentage, unit: HKUnit.percent())
        async let rhr = fetchSingleQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: HKUnit.minute()))
        
        // Await all
        let (weight, height, bodyFat, restingHeart) = await (w, h, bf, rhr)
        
        // Convert bodyFat to 0-100 scale if needed, logic above used 0-1 -> 0-100
        let bfPercent = bodyFat != nil ? bodyFat! * 100 : nil
        
        return (weight, height, bfPercent, restingHeart)
    }
    
    private func requestAuthForProfileImport() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let types: [HKObjectType?] = [
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .height),
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        ]
        let safeTypes = Set(types.compactMap { $0 })
        do {
            try await healthStore.requestAuthorization(toShare: [], read: safeTypes)
            return true
        } catch {
            print("[HK] Profile Auth failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func fetchSingleQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(q)
        }
    }

    // MARK: - Background Delivery + Observer (Schritte)

    /// Steps + Widget-Update
    func startBackgroundDelivery() async {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        // Observer, wird von iOS im Hintergrund getriggert
        let observer = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in

            if let error = error {
                print("[HK] Observer error:", error.localizedDescription)
                completionHandler()
                return
            }

            // ⬇️ Steps + Widgets aktualisieren
            self?.refreshToday {
                completionHandler()   // ⚠️ wichtig: genau einmal aufrufen
            }
        }

        healthStore.execute(observer)
        stepsObserverQuery = observer

        do {
            // .immediate = so "live" wie iOS es erlaubt
            try await healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate)
            print("[HK] Background delivery for steps enabled (.immediate)")
        } catch {
            print("[HK] enableBackgroundDelivery error:", error.localizedDescription)
        }
    }

    
    // MARK: - Background: Workouts → Notifs

    func startWorkoutObserver() async {
        let type = HKObjectType.workoutType()

        let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
            guard let self = self else { completion(); return }

            if let error = error {
                print("[HK] workout observer error:", error.localizedDescription)
                completion()
                return
            }

            self.fetchLatestWorkoutForNotification {
                completion()
            }
        }

        healthStore.execute(observer)
        workoutsObserverQuery = observer

        do {
            try await healthStore.enableBackgroundDelivery(for: type, frequency: .immediate)
            print("[HK] Background delivery for workouts enabled (.immediate)")
        } catch {
            print("[HK] enableBackgroundDelivery workouts error:", error.localizedDescription)
        }
    }

    private func fetchLatestWorkoutForNotification(completion: @escaping () -> Void) {
        let type = HKObjectType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: type,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sort]) { [weak self] _, samples, error in
            defer { completion() }
            guard let self = self else { return }
            
            if let error = error {
                print("[HK] Workout query error:", error.localizedDescription)
                return
            }
            
            guard let workout = samples?.first as? HKWorkout else { return }

            // 1) Unterdrücke initialen Erstlauf: setze Base-Line, aber sende keine Notification
            if !self.isInitialSyncDone(for: self.initialWorkoutSyncDoneKey) {
                self.markInitialSyncDone(for: self.initialWorkoutSyncDoneKey)
                UserDefaults.standard.set(workout.endDate, forKey: self.lastNotifiedWorkoutEndDateKey)
                print("[HK] Initial workout sync baseline set at", workout.endDate)
                return
            }

            // 2) Zweite Schutzlinie: ignoriere alles vor firstLaunchDate
            guard workout.endDate >= self.firstLaunchDate else {
                print("[HK] Workout before firstLaunchDate → ignore")
                return
            }

            // 3) Normaler Duplikat‑Schutz
            let lastDate = UserDefaults.standard.object(forKey: self.lastNotifiedWorkoutEndDateKey) as? Date ?? .distantPast
            guard workout.endDate > lastDate else {
                print("[HK] Workout already notified")
                return
            }

            // 4) Merken + benachrichtigen
            UserDefaults.standard.set(workout.endDate, forKey: self.lastNotifiedWorkoutEndDateKey)
            print("[HK] 🏃 New workout detected")
        }

        healthStore.execute(query)
    }

    // MARK: - Background: Gewicht → Notifs

    func startWeightObserver() async {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }

        let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
            guard let self = self else { completion(); return }

            if let error = error {
                print("[HK] bodyMass observer error:", error.localizedDescription)
                completion()
                return
            }

            self.fetchLatestWeightForNotification {
                completion()
            }
        }

        healthStore.execute(observer)
        bodyMassObserverQuery = observer

        do {
            try await healthStore.enableBackgroundDelivery(for: type, frequency: .immediate)
            print("[HK] Background delivery for bodyMass enabled (.immediate)")
        } catch {
            print("[HK] enableBackgroundDelivery bodyMass error:", error.localizedDescription)
        }
    }

    private func fetchLatestWeightForNotification(completion: @escaping () -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion()
            return
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: type,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sort]) { [weak self] _, samples, error in
            defer { completion() }
            guard let self = self else { return }
            
            if let error = error {
                print("[HK] Weight query error:", error.localizedDescription)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else { return }

            // 1) Unterdrücke initialen Erstlauf: Base-Line setzen, keine Notification
            if !self.isInitialSyncDone(for: self.initialWeightSyncDoneKey) {
                self.markInitialSyncDone(for: self.initialWeightSyncDoneKey)
                UserDefaults.standard.set(sample.endDate, forKey: self.lastNotifiedWeightDateKey)
                print("[HK] Initial weight sync baseline set at", sample.endDate)
                return
            }

            // 2) Alles vor firstLaunchDate ignorieren
            guard sample.endDate >= self.firstLaunchDate else {
                print("[HK] Weight before firstLaunchDate → ignore")
                return
            }

            // 3) Duplikat‑Schutz
            let lastDate = UserDefaults.standard.object(forKey: self.lastNotifiedWeightDateKey) as? Date ?? .distantPast
            guard sample.endDate > lastDate else {
                print("[HK] Weight already notified")
                return
            }

            // 4) Merken + benachrichtigen
            UserDefaults.standard.set(sample.endDate, forKey: self.lastNotifiedWeightDateKey)
            let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            print("[HK] ⚖️ New weight detected: \(kg)kg")
            NotificationManager1.shared.recordWeightUpdate(valueKg: kg)
        }

        healthStore.execute(query)
    }

    // MARK: - Public Refresh API

    func refreshAll() {
        refreshToday()
        refreshCalories()
        refreshVitals()
    }

    func refreshToday(completion: (() -> Void)? = nil) {
        fetchTodaySteps { [weak self] steps in
            self?.fetchTodayHourlySteps { hourly in
                // Ziel bestimmen (Fallback 8000)
                let goalUF = UserDefaults.standard.integer(forKey: "stepsGoal")
                let goal = (self?.dailyGoal ?? goalUF)
                let safeGoal = goal > 0 ? goal : 8_000

                // ⬇️ In App-Group speichern + Widgets reloaden
                StepsShared.updateToday(steps: steps, goal: safeGoal, hourlyHistory: hourly)

                #if DEBUG
                StepsShared.debugDump(prefix: "APP wrote steps")
                #endif

                Task { @MainActor in
                    self?.todaySteps = steps
                    completion?()
                }
            }
        }
    }

    func refreshCalories() {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: caloriesType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { [weak self] _, result, _ in
            let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            Task { @MainActor in
                self?.todayCalories = Int(calories)
            }
        }
        healthStore.execute(query)
    }

    func refreshVitals() {
        // Körperfett (%)
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            fetchMostRecentQuantitySample(for: type) { [weak self] q in
                Task { @MainActor in
                    // HealthKit speichert Körperfett als Anteil (0…1). Für % ×100.
                    self?.latestBodyFatPercent = q.map { $0.doubleValue(for: HKUnit.percent()) * 100.0 }
                }
            }
        }
        
        // Gewicht (kg)
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            fetchMostRecentQuantitySample(for: type) { [weak self] q in
                Task { @MainActor in
                    self?.latestWeight = q?.doubleValue(for: .gramUnit(with: .kilo))
                }
            }
        }

        // Ruhepuls (bpm)
        if let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            fetchMostRecentQuantitySample(for: type) { [weak self] q in
                Task { @MainActor in
                    self?.latestRestingHeartRate = q?.doubleValue(for: bpmUnit)
                }
            }
        }

        // VO2 Max (ml/kg/min)
        if let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
             let ml = HKUnit.literUnit(with: .milli)
             let kg = HKUnit.gramUnit(with: .kilo)
             let min = HKUnit.minute()
             let unit = ml.unitDivided(by: kg.unitMultiplied(by: min))
             fetchMostRecentQuantitySample(for: type) { [weak self] q in
                 Task { @MainActor in
                     self?.latestVO2Max = q?.doubleValue(for: unit)
                 }
             }
        }

        // Atemfrequenz (Respiratory Rate) - count/min
        if let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
             let unit = HKUnit.count().unitDivided(by: .minute())
             fetchMostRecentQuantitySample(for: type) { [weak self] q in
                 Task { @MainActor in
                     self?.latestRespiratoryRate = q?.doubleValue(for: unit)
                 }
             }
        }

        // Blutsauerstoff (Oxygen Saturation) - %
        if let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
             fetchMostRecentQuantitySample(for: type) { [weak self] q in
                 Task { @MainActor in
                     self?.latestOxygenSaturation = q.map { $0.doubleValue(for: HKUnit.percent()) * 100.0 }
                 }
             }
        }
        
        // Handgelenkstemperatur (Apple Watch Series 8+)
        // Uses appleWalkingSteadiness as placeholder? No, distinct type: appleSleepingWristTemperature (HKQuantityTypeIdentifierAppleSleepingWristTemperature) but that is relative degC.
        // Wait, 'appleSleepingWristTemperature' is relative change.
        // There is 'bodyTemperature' (generic). Let's use generic first, defaulting to nil.
        // Note: Wrist Temp is usually delta.
        if #available(iOS 16.0, *) {
             if let type = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                 let unit = HKUnit.degreeCelsius()
                 fetchMostRecentQuantitySample(for: type) { [weak self] q in
                     Task { @MainActor in
                         self?.latestWristTemperature = q?.doubleValue(for: unit)
                     }
                 }
             }
        }
        // Lean Body Mass (kg)
        if let type = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) {
            fetchMostRecentQuantitySample(for: type) { [weak self] q in
                Task { @MainActor in
                    self?.latestLeanBodyMass = q?.doubleValue(for: .gramUnit(with: .kilo))
                }
            }
        }
        
        // Body Mass Index (count)
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) {
            fetchMostRecentQuantitySample(for: type) { [weak self] q in
                Task { @MainActor in
                    self?.latestBMI = q?.doubleValue(for: .count())
                }
            }
        }
        
        // HRV (ms)
        if let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
             let ms = HKUnit.secondUnit(with: .milli)
             fetchMostRecentQuantitySample(for: type) { [weak self] q in
                 Task { @MainActor in
                     self?.latestHRV = q?.doubleValue(for: ms)
                 }
             }
        }
    }

    func detectLatestWeightChangeForHome() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        fetchMostRecentQuantitySample(for: type) { sample in
            guard let sample else { return }
            let kg = sample.doubleValue(for: .gramUnit(with: .kilo))
            let rounded = (kg * 10).rounded() / 10
            let defaults = UserDefaults.standard
            let lastValueKey = "movo.home.lastSeenHealthWeight.kg"
            let lastDateKey = "movo.home.lastSeenHealthWeight.date"
            let previousValue = defaults.object(forKey: lastValueKey) as? Double
            let previousDate = defaults.object(forKey: lastDateKey) as? Date

            defaults.set(rounded, forKey: lastValueKey)
            defaults.set(Date(), forKey: lastDateKey)

            guard let previousValue,
                  abs(previousValue - rounded) >= 0.05 else { return }

            if let previousDate,
               Date().timeIntervalSince(previousDate) < 2 {
                return
            }

            NotificationManager1.shared.recordWeightUpdate(valueKg: rounded)
        }
    }

    // MARK: - Queries

    /// Heutige Schritte (Mitternacht → jetzt)
    private func fetchTodaySteps(completion: @escaping (Int) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0); return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate  = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            completion(Int(steps))
        }
        healthStore.execute(query)
    }

    func fetchTodayHourlySteps(completion: @escaping ([Double]) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion([])
            return
        }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        
        var interval = DateComponents()
        interval.hour = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil, 
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results = results else {
                completion([])
                return
            }

            var hourCounts: [Double] = Array(repeating: 0, count: 24)
            
            results.enumerateStatistics(from: startOfDay, to: Date()) { statistics, _ in
                let hour = cal.component(.hour, from: statistics.startDate)
                if let sum = statistics.sumQuantity() {
                    let steps = sum.doubleValue(for: .count())
                    if hour >= 0 && hour < 24 {
                        hourCounts[hour] = steps
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(hourCounts)
            }
        }
        healthStore.execute(query)
    }


    // MARK: - Steps History
    struct StepsEntry: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    func fetchStepsHistory(days: Int, completion: @escaping ([StepsEntry]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion([])
            return
        }

        let cal = Calendar.current
        let now = Date()
        guard let startDate = cal.date(byAdding: .day, value: -days, to: now) else {
            completion([])
            return
        }

        var dayComponents = DateComponents()
        dayComponents.day = 1

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: cal.startOfDay(for: startDate),
            intervalComponents: dayComponents
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results = results else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var entries: [StepsEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                entries.append(StepsEntry(
                    date: statistics.startDate,
                    count: Int(steps)
                ))
            }

            DispatchQueue.main.async {
                completion(entries)
            }
        }

        healthStore.execute(query)
    }

    /// Neueste Quantity-Sample (z. B. Körperfett, Ruhepuls)
    private func fetchMostRecentQuantitySample(for type: HKQuantityType,
                                               completion: @escaping (HKQuantity?) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: type,
                              predicate: nil,
                              limit: 1,
                              sortDescriptors: [sort]) { _, samples, _ in
            let quantity = (samples?.first as? HKQuantitySample)?.quantity
            completion(quantity)
        }
        healthStore.execute(q)
    }

    // MARK: - Weight History

    struct WeightEntry: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    func fetchWeightHistory(days: Int, completion: @escaping ([WeightEntry]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion([])
            return
        }

        let cal = Calendar.current
        let now = Date()
        guard let startDate = cal.date(byAdding: .day, value: -days, to: now) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        let query = HKSampleQuery(sampleType: type,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else {
                completion([])
                return
            }

            let entries = Self.deduplicatedDailyWeightEntries(from: samples, calendar: cal)

            DispatchQueue.main.async {
                completion(entries)
            }
        }
        healthStore.execute(query)
    }

    private static func deduplicatedDailyWeightEntries(from samples: [HKQuantitySample],
                                                       calendar: Calendar) -> [WeightEntry] {
        let latestSampleByDay = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.endDate)
        }
        .compactMapValues { daySamples in
            daySamples.max { lhs, rhs in lhs.endDate < rhs.endDate }
        }

        return latestSampleByDay
            .values
            .sorted { $0.endDate < $1.endDate }
            .map { sample in
                WeightEntry(
                    date: sample.endDate,
                    value: sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                )
            }
    }

    // MARK: - Calories (Active Energy) History

    struct CaloriesEntry: Identifiable {
        let id = UUID()
        let date: Date
        let calories: Int
    }

    func fetchCaloriesHistory(days: Int, completion: @escaping ([CaloriesEntry]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion([])
            return
        }

        let cal = Calendar.current
        let now = Date()
        guard let startDate = cal.date(byAdding: .day, value: -days, to: now) else {
            completion([])
            return
        }

        // Group by day
        var dayComponents = DateComponents()
        dayComponents.day = 1

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: cal.startOfDay(for: startDate),
            intervalComponents: dayComponents
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results = results else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var entries: [CaloriesEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                let calories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                entries.append(CaloriesEntry(
                    date: statistics.startDate,
                    calories: Int(calories)
                ))
            }

            DispatchQueue.main.async {
                completion(entries)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Generic Quantity History
    
    func fetchQuantityHistory(for identifier: HKQuantityTypeIdentifier, days: Int, unit: HKUnit, completion: @escaping ([(date: Date, value: Double)]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion([]); return
        }
        
        let cal = Calendar.current
        let now = Date()
        guard let startDate = cal.date(byAdding: .day, value: -days, to: now) else {
            completion([]); return
        }
        
        // Predicate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: type,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let entries = samples.map { sample in
                (date: sample.endDate, value: sample.quantity.doubleValue(for: unit))
            }
            
            DispatchQueue.main.async { completion(entries) }
        }
        
        healthStore.execute(query)
    }

    // MARK: - HRV History (Daily)
    func fetchHRVHistory(days: Int, completion: @escaping ([(date: Date, value: Double)]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion([]); return
        }
        
        let cal = Calendar.current
        let now = Date()
        guard let startDate = cal.date(byAdding: .day, value: -days, to: now) else {
            completion([]); return
        }
        
        // Group by day (discreteAverage)
        var interval = DateComponents()
        interval.day = 1
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: cal.startOfDay(for: startDate),
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, _ in
            guard let results = results else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            var entries: [(Date, Double)] = []
            results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                let ms = HKUnit.secondUnit(with: .milli)
                if let avg = statistics.averageQuantity()?.doubleValue(for: ms) {
                    entries.append((date: statistics.startDate, value: avg))
                }
            }
            
            DispatchQueue.main.async {
                completion(entries)
            }
        }
        
        healthStore.execute(query)
    }
    
    
    @MainActor
    func ingestWatchHeartRate(_ bpm: Double) {
        // so bleibt dein UI (heartRateChip) kompatibel
        isHeartRateMonitoringActive = true
        currentHeartRate = bpm
        lastHeartRateSampleDate = Date()
        restartHeartRateStaleTimer()
    }

    // MARK: - Sleep History

    struct SleepEntry: Identifiable {
        let id = UUID()
        let date: Date
        let hours: Double
    }

    func fetchSleepHistory(days: Int, completion: @escaping ([SleepEntry]) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }

        let cal = Calendar.current
        let now = Date()
        guard let startDate = cal.date(byAdding: .day, value: -days, to: now) else {
            completion([])
            return
        }

        // Hole alle Samples im Fenster, wir clippen später die Dauer
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            // Nur echte Schlafphasen zählen (nicht „inBed“)
            func isAsleep(_ value: Int) -> Bool {
                if #available(iOS 16.0, *) {
                    return value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    || value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                } else {
                    return value == HKCategoryValueSleepAnalysis.asleep.rawValue
                }
            }

            // Group by day (nach Enddatum), Dauer auf [startDate, now] clippen
            var sleepByDay: [Date: TimeInterval] = [:]

            for sample in samples where isAsleep(sample.value) {
                let clippedStart = max(sample.startDate, startDate)
                let clippedEnd   = min(sample.endDate, now)
                guard clippedEnd > clippedStart else { continue }

                let day = cal.startOfDay(for: sample.endDate)
                let duration = clippedEnd.timeIntervalSince(clippedStart)
                sleepByDay[day, default: 0] += duration
            }

            let entries = sleepByDay.map { (date, duration) in
                SleepEntry(
                    date: date,
                    hours: duration / 3600.0
                )
            }.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                completion(entries)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Saving Data (Write)
    
    func saveHealthSample(type: HKQuantityType, value: Double, unit: HKUnit, date: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    // MARK: - Workouts History (manuelles Laden)

    func fetchWorkouts(limit: Int = 50, completion: @escaping ([HKWorkout]) -> Void) {
        let type = HKObjectType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: type,
                                  predicate: nil,
                                  limit: limit,
                                  sortDescriptors: [sort]) { _, samples, _ in
            guard let workouts = samples as? [HKWorkout] else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            DispatchQueue.main.async {
                completion(workouts)
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Heart Rate Streaming  (Apple Watch optional filtern)

    private var filterHeartRateToAppleWatch: Bool = true

    /// Startet Live-Streaming der Herzfrequenz. Optional nur Samples von der Apple Watch.
    func startHeartRateStreaming(filterToAppleWatch: Bool = true) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        isHeartRateMonitoringActive = true
        filterHeartRateToAppleWatch = filterToAppleWatch

        // Reset Stale-State
        heartRateStaleTimer?.invalidate()
        heartRateStaleTimer = nil
        lastHeartRateSampleDate = nil
        currentHeartRate = nil

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleHeartRateSamples(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleHeartRateSamples(samples)
            }
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    func stopHeartRateStreaming() {
        if let q = heartRateQuery {
            healthStore.stop(q)
        }
        heartRateQuery = nil

        heartRateStaleTimer?.invalidate()
        heartRateStaleTimer = nil
        lastHeartRateSampleDate = nil

        currentHeartRate = nil
        isHeartRateMonitoringActive = false
    }

    /// Verarbeitet neue Herzfrequenz-Samples.
    /// Optional nur Apple‑Watch‑Samples, und nur wenn das letzte Sample höchstens 60s alt ist.
    @MainActor
    private func handleHeartRateSamples(_ samples: [HKSample]?) {
        guard var quantitySamples = samples as? [HKQuantitySample],
              !quantitySamples.isEmpty else { return }

        if filterHeartRateToAppleWatch {
            quantitySamples = quantitySamples.filter { isFromAppleWatch($0) }
        }

        guard let last = quantitySamples.last else { return }

        let sampleDate = last.endDate
        let now = Date()
        let age = now.timeIntervalSince(sampleDate)

        guard age <= heartRateValidity else {
            lastHeartRateSampleDate = sampleDate
            currentHeartRate = nil
            return
        }

        let bpm = last.quantity.doubleValue(
            for: HKUnit.count().unitDivided(by: .minute())
        )

        lastHeartRateSampleDate = sampleDate
        currentHeartRate = bpm

        restartHeartRateStaleTimer()
    }

    /// Heuristik: Ist das Sample eindeutig von einer Apple Watch?
    private func isFromAppleWatch(_ sample: HKQuantitySample) -> Bool {
        // 1) Device-Hinweise
        if let device = sample.device {
            if let model = device.model, model.localizedCaseInsensitiveContains("watch") { return true }
            if let name = device.name, name.localizedCaseInsensitiveContains("apple watch") { return true }
            if let manufacturer = device.manufacturer,
               manufacturer.localizedCaseInsensitiveContains("apple"),
               (device.model?.localizedCaseInsensitiveContains("watch") ?? false) {
                return true
            }
        }
        // 2) SourceRevision (neuere iOS)
        if #available(iOS 11.0, *) {
            let src = sample.sourceRevision
            if src.source.name.localizedCaseInsensitiveContains("apple watch") { return true }
            if let productType = src.productType,
               productType.localizedCaseInsensitiveContains("watch") {
                return true
            }
        }
        // Fallback: unklar → nicht als Watch behandeln
        return false
    }

    /// Timer setzt `currentHeartRate` auf nil, wenn 60s lang kein neuer Wert kam.
    private func restartHeartRateStaleTimer() {
        heartRateStaleTimer?.invalidate()

        heartRateStaleTimer = Timer.scheduledTimer(withTimeInterval: heartRateValidity,
                                                   repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let last = self.lastHeartRateSampleDate,
                   Date().timeIntervalSince(last) >= self.heartRateValidity {
                    self.currentHeartRate = nil
                }
            }
        }
    }

    // MARK: - Resting Heart Rate History
    struct HREntry: Identifiable {
        let id = UUID()
        let date: Date
        let bpm: Double
    }

    func fetchRestingHRHistory(days: Int, completion: @escaping ([HREntry]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion([])
            return
        }

        let cal = Calendar.current
        let now = Date()
        guard let startDate = cal.date(byAdding: .day, value: -days, to: now) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        let query = HKSampleQuery(sampleType: type,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let entries = samples.map { sample in
                HREntry(
                    date: sample.endDate,
                    bpm: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                )
            }

            DispatchQueue.main.async {
                completion(entries)
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Workout Session (Auto-Launch Watch App)
    
    private var workoutSession: HKWorkoutSession?
    
    /// Intentionally disabled: Movo must not create Apple Fitness/Health workouts.
    func startWorkoutSession() async {
        workoutSession = nil
    }
    
    /// Intentionally disabled with startWorkoutSession().
    func stopWorkoutSession() async {
        workoutSession = nil
    }

    // MARK: - Cleanup

    func stop() {
        if let q = stepsObserverQuery { healthStore.stop(q) }
        if let q = workoutsObserverQuery { healthStore.stop(q) }
        if let q = bodyMassObserverQuery { healthStore.stop(q) }
        stepsObserverQuery = nil
        workoutsObserverQuery = nil
        bodyMassObserverQuery = nil

        stopHeartRateStreaming()
    }
}

// MARK: - Notification Management
import Foundation
import UserNotifications
import HealthKit

final class NotificationManager1 {
    static let shared = NotificationManager1()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Master toggle (global)
    private static let masterKey = "movo.notificationsEnabled"

    func setMasterEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.masterKey)
        if !enabled {
            cancelAllNotifications()
        }
    }

    private var masterEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.masterKey) == nil { return true } // default an
        return UserDefaults.standard.bool(forKey: Self.masterKey)
    }

    // MARK: - Per-feature toggles (Settings)
    private enum Pref {
        static let training = "notif.training.enabled"
        static let morning  = "notif.morning.enabled"
        static let water    = "notif.water.enabled"

        static let workoutSummary        = "notif.workoutSummary.enabled"
        static let postWorkoutHydration  = "notif.postWorkoutHydration.enabled"

        static let weightMilestones = "notif.weightMilestones.enabled"
        static let streakMilestones = "notif.streakMilestones.enabled"
        static let personalRecord   = "notif.personalRecord.enabled"

        static let challengeProgress = "notif.challengeProgress.enabled"
        static let restDay           = "notif.restDay.enabled"
        static let comeback          = "notif.comeback.enabled"
        static let weeklySummary     = "notif.weeklySummary.enabled"
    }

    private func isEnabled(_ key: String, default defaultValue: Bool = true) -> Bool {
        // Wenn der Key noch nie gesetzt wurde -> defaultValue
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func allowed(_ key: String, default defaultValue: Bool = true) -> Bool {
        masterEnabled && isEnabled(key, default: defaultValue)
    }

    // Simple DE/EN helper with optional personalization
    private func L(_ de: String, _ en: String, userName: String = "") -> String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        let text = code.starts(with: "de") ? de : en

        if !userName.isEmpty {
            return text.replacingOccurrences(of: "{name}", with: userName)
        } else {
            return text.replacingOccurrences(of: "{name}, ", with: "")
                .replacingOccurrences(of: "{name} ", with: "")
                .replacingOccurrences(of: "{name}", with: "")
        }
    }

    private func getUserName() -> String {
        UserDefaults.standard.string(forKey: "userName") ?? ""
    }

    // MARK: - Permission
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("🔔 Notification permission:", granted)
        } catch {
            print("❌ Notification auth error:", error)
        }
    }

    // MARK: - WATER REMINDER (Post-Workout)
    func scheduleWaterReminder(delayMinutes: Int = 5) {
        center.removePendingNotificationRequests(withIdentifiers: ["movo.waterReminder"])
    }

    // MARK: - WORKOUT SUMMARY (Apple-Health-Workouts)
    func notifyHealthWorkoutFinished(_ workout: HKWorkout) {
        cancelNotification(withIdentifier: "movo.workout.\(workout.uuid.uuidString)")
    }

    // MARK: - WEIGHT CHANGE
    func notifyNewWeight(valueKg: Double) {
        recordWeightUpdate(valueKg: valueKg)
    }

    func recordWeightUpdate(valueKg: Double) {
        let kg = (valueKg * 10).rounded() / 10
        UserDefaults.standard.set(kg, forKey: "movo.latestWeightUpdate.kg")
        UserDefaults.standard.set(Date(), forKey: "movo.latestWeightUpdate.date")
        UserDefaults.standard.set(false, forKey: "movo.latestWeightUpdate.seen")
    }

    // MARK: - DAILY SCHEDULED REMINDERS (SettingsView expects these)

    func scheduleDailyTrainingReminder(hour: Int, minute: Int) {
        let id = "movo.dailyTrainingReminder"
        cancelNotification(withIdentifier: id)
    }

    func scheduleMorningMotivation(hour: Int, minute: Int) {
        let id = "movo.morningMotivation"
        cancelNotification(withIdentifier: id)
    }

    func scheduleGeneralWaterReminder(hour: Int, minute: Int) {
        guard allowed(Pref.water, default: false) else { return }

        // dynamic identifier matches SettingsView storage/cancel logic
        let id = "movo.generalWater.\(hour).\(minute)"

        let content = UNMutableNotificationContent()
        let name = getUserName()
        content.title = "💧 " + L("{name}Zeit zum Trinken!", "{name}Time to hydrate!", userName: name)
        content.body  = L("Erinnere dich an ein Glas Wasser – bleib frisch.",
                          "Grab a glass of water – stay fresh.")
        content.sound = .default

        let comps = DateComponents(calendar: Calendar.current, hour: hour, minute: minute, second: 0)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - NEW: Pause finished notification (moved from stray file)
    func sendPauseFinishedNow() {
        guard masterEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = L("⏱️ Pause beendet", "⏱️ Rest complete")
        content.body  = L("Pause beendet – weiter geht's!", "Rest complete – let's go!")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "movo.pause.finished.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Cancel helpers

    func cancelNotification(withIdentifier id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

// MARK: - Small helper for WorkoutType name
private extension HKWorkoutActivityType {
    var nameFallback: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining: return "Strength"
        case .yoga: return "Yoga"
        default: return "Workout"
        }
    }
}
