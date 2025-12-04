import Foundation
import HealthKit
import WidgetKit

@MainActor
final class HealthKitManager: ObservableObject {

    private let healthStore = HKHealthStore()

    // Published Werte für UI
    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var latestBodyFatPercent: Double?      // z.B. 18.4 (%)
    @Published private(set) var latestRestingHeartRate: Double?     // z.B. 55 (bpm)

    // App-Status
    var dailyGoal: Int = 8_000

    // Referenz, um Observer ggf. zu stoppen
    private var stepsObserverQuery: HKObserverQuery?

    // MARK: - Authorization (nur Lesen)
    /// Fragt (optional forciert) Lese-Rechte an und startet danach Background-Delivery + Initial-Refresh.
    func requestReadAuthorizationIfNeeded(readTypes: [HKObjectType], forcePrompt: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        if forcePrompt {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: Set(readTypes))
            } catch {
                // print("[HK] auth error:", error.localizedDescription)
            }
        }

        await startBackgroundDelivery()
        refreshAll()
    }

    // MARK: - Background Delivery + Observer (Schritte)
    func startBackgroundDelivery() async {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        // ⚠️ Handler-Signatur: (_, completionHandler, error)
        let observer = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, _ in
            self?.refreshToday {
                // ✅ completion genau einmal aufrufen
                completionHandler()
            }
        }

        healthStore.execute(observer)
        stepsObserverQuery = observer

        do {
            try await healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly)
        } catch {
            // print("[HK] enableBackgroundDelivery error:", error.localizedDescription)
        }
    }

    // MARK: - Public Refresh API
    func refreshAll() {
        refreshToday()
        refreshVitals()
    }

    func refreshToday(completion: (() -> Void)? = nil) {
        fetchTodaySteps { [weak self] steps in
            // Ziel bestimmen (Fallback 8000)
            let goalUF = UserDefaults.standard.integer(forKey: "stepsGoal")
            let goal = (self?.dailyGoal ?? goalUF)
            let safeGoal = goal > 0 ? goal : 8_000

            // ⬇️ WICHTIG: in App-Group speichern + Widgets reloaden
            StepsShared.updateToday(steps: steps, goal: safeGoal)

            #if DEBUG
            StepsShared.debugDump(prefix: "APP wrote steps")
            #endif

            Task { @MainActor in
                self?.todaySteps = steps
                completion?()
            }
        }
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

        // Ruhepuls (bpm)
        if let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            fetchMostRecentQuantitySample(for: type) { [weak self] q in
                Task { @MainActor in
                    self?.latestRestingHeartRate = q?.doubleValue(for: bpmUnit)
                }
            }
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

    // MARK: - Cleanup
    func stop() {
        if let q = stepsObserverQuery { healthStore.stop(q) }
        stepsObserverQuery = nil
    }
}
