import Foundation
import WatchConnectivity
import Combine

#if os(watchOS)
import HealthKit
#endif

@MainActor
final class WatchConnectivity: NSObject, ObservableObject {
    static let shared = WatchConnectivity()

    // UI State
    @Published var activeWorkout = ActiveWorkoutPayload(isActive: false)
    @Published var lastStatus: String = "—"
    @Published var pendingCount: Int = 0
    @Published var companionInstalled: Bool = false
    @Published var reachable: Bool = false

    // Heart Rate (Watch -> iPhone)
    @Published var watchHeartRateBPM: Double = 0

    private let activeWorkoutKey = "activeWorkoutPayloadJSON"

    private var cancellables = Set<AnyCancellable>()
    private var hrStreamingStarted = false

    #if os(watchOS)
    private let healthStore = HKHealthStore()
    private var hkSession: HKWorkoutSession?
    private var hkBuilder: HKLiveWorkoutBuilder?
    #endif

    private override init() {
        super.init()
    }

    // MARK: - Activate

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        refreshFlags()

        // ✅ IMMER starten
        startObservingActiveWorkoutForHR()

        // ✅ falls schon context da ist
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty {
            handleApplicationContext(ctx)
        }
    }

    func refreshFlags() {
        let s = WCSession.default
        companionInstalled = s.isCompanionAppInstalled
        reachable = s.isReachable
    }

    // MARK: - iPhone -> Watch

    // MARK: - iPhone -> Watch
    func handleApplicationContext(_ ctx: [String: Any]) {
        guard (ctx["type"] as? String) == "activeWorkoutState" else { return }
        guard let json = ctx[activeWorkoutKey] as? String,
              let data = json.data(using: .utf8) else { return }

        do {
            let payload = try JSONDecoder().decode(ActiveWorkoutPayload.self, from: data)
            self.activeWorkout = payload
            self.lastStatus = payload.isActive ? "📲 Training aktiv" : "⏳ Warten"

            // HR Start/Stop optional:
            Task { @MainActor in
                if payload.isActive {
                    await self.startWatchHeartRateWorkoutIfNeeded()
                } else {
                    await self.stopWatchHeartRateWorkoutIfNeeded()
                }
            }

        } catch {
            print("❌ decode ActiveWorkoutPayload failed:", error.localizedDescription)
        }
    }


    // MARK: - Watch -> iPhone (Events)

    func logSet(workoutId: String,
                workoutExerciseId: String,
                reps: Int,
                weight: Double) {

        refreshFlags()

        let payload: [String: Any] = [
            "type": "set_logged",
            "workoutId": workoutId,
            "workoutExerciseId": workoutExerciseId,
            "reps": reps,
            "weight": weight,
            "timestamp": Date().timeIntervalSince1970,
            "eventId": UUID().uuidString,
            "deviceId": "watch"
        ]

        let session = WCSession.default

        if session.isReachable {
            // Nur live senden, NICHT zusätzlich queueing
            session.sendMessage(payload, replyHandler: nil, errorHandler: { error in
                print("sendMessage error:", error.localizedDescription)
            })
            lastStatus = "📤 live"
        } else {
            // Nur queueing, wenn nicht erreichbar
            pendingCount += 1
            lastStatus = "📤 queued (\(pendingCount))"
            session.transferUserInfo(payload)
        }
    }

    func selectExercise(workoutId: String, workoutExerciseId: String) {
        refreshFlags()

        let payload: [String: Any] = [
            "type": "exercise_changed",
            "workoutId": workoutId,
            "workoutExerciseId": workoutExerciseId,
            "timestamp": Date().timeIntervalSince1970
        ]

        let session = WCSession.default
        session.transferUserInfo(payload)

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
            lastStatus = "➡️ Übung gewählt"
        } else {
            lastStatus = "➡️ queued"
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivity: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        if let error { print("Watch WCSession activation error:", error) }
        Task { @MainActor in WatchConnectivity.shared.refreshFlags() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in WatchConnectivity.shared.refreshFlags() }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            WatchConnectivity.shared.startObservingActiveWorkoutForHR()
            WatchConnectivity.shared.handleApplicationContext(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String : Any]) {
        if let type = message["type"] as? String, type == "activeWorkoutStatePing" {
            Task { @MainActor in WatchConnectivity.shared.lastStatus = "📩 ping" }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String : Any],
                             replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            if let type = message["type"] as? String {
                WatchConnectivity.shared.lastStatus = "📩 \(type)"
            }
        }
        replyHandler(["ok": true])
    }
}

// MARK: - HR: Start/Stop & Send

private extension WatchConnectivity {
    func startObservingActiveWorkoutForHR() {
        guard !hrStreamingStarted else { return }
        hrStreamingStarted = true

        $activeWorkout
            .map(\.isActive)
            .removeDuplicates()
            .sink { [weak self] isActive in
                guard let self else { return }
                Task { @MainActor in
                    if isActive {
                        await self.startWatchHeartRateWorkoutIfNeeded()
                    } else {
                        await self.stopWatchHeartRateWorkoutIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
    }

    func startWatchHeartRateWorkoutIfNeeded() async {
        #if os(watchOS)
        guard hkSession == nil, hkBuilder == nil else { return }

        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
        else {
            lastStatus = "❌ HR not available"
            return
        }

        // Für HKWorkoutSession MUSS Schreibrecht für Workout angefragt werden
        let workoutType = HKObjectType.workoutType()

        do {
            // Debug: Plist-Text prüfen
            print("HK Share usage:",
                  Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") as? String ?? "nil")
            print("HK Update usage:",
                  Bundle.main.object(forInfoDictionaryKey: "NSHealthUpdateUsageDescription") as? String ?? "nil")

            try await healthStore.requestAuthorization(
                toShare: [workoutType],     // ← wichtig!
                read: [hrType]
            )
        } catch {
            lastStatus = "❌ HK auth"
            print("❌ HK auth failed:", error)
            return
        }

        // Optional: prüfen, ob wirklich autorisiert wurde
        if #available(watchOS 6.0, *) {
            let status = healthStore.authorizationStatus(for: workoutType)
            guard status == .sharingAuthorized else {
                lastStatus = "❌ Workout write denied"
                print("❌ Workout sharing not authorized (status: \(status.rawValue))")
                return
            }
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let s = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let b = s.associatedWorkoutBuilder()

            s.delegate = self
            b.delegate = self
            b.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            hkSession = s
            hkBuilder = b

            let start = Date()
            s.startActivity(with: start)

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                b.beginCollection(withStart: start) { _, error in
                    if let error { cont.resume(throwing: error) } else { cont.resume(returning: ()) }
                }
            }

            lastStatus = "⌚️ HR on"
        } catch {
            lastStatus = "❌ HR start"
            print("❌ startWatchHeartRateWorkout failed:", error)
            hkSession = nil
            hkBuilder = nil
        }
        #endif
    }

    func stopWatchHeartRateWorkoutIfNeeded() async {
        watchHeartRateBPM = 0

        #if os(watchOS)
        guard let s = hkSession, let b = hkBuilder else {
            lastStatus = "⌚️ HR off"
            return
        }

        // Beenden ohne Health-Workout zu speichern:
        // end -> endCollection -> discardWorkout (NICHT finishWorkout)
        s.end()

        b.endCollection(withEnd: Date()) { _, _ in
            b.discardWorkout()
            Task { @MainActor in
                self.hkSession = nil
                self.hkBuilder = nil
                self.lastStatus = "⌚️ HR off"
            }
        }
        #endif
    }

    func sendHeartRateToPhone(_ bpm: Double) {
        let payload: [String: Any] = [
            "type": "hr",
            "bpm": bpm,
            "timestamp": Date().timeIntervalSince1970,
            "deviceId": "watch"
        ]

        let session = WCSession.default
        refreshFlags()

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { err in
                print("❌ send HR error:", err.localizedDescription)
            })
        } else {
            // ✅ liefert wenigstens den letzten Wert zuverlässig
            do { try session.updateApplicationContext(payload) }
            catch { session.transferUserInfo(payload) }
        }
    }
}

// MARK: - HealthKit delegates (watchOS)

#if os(watchOS)
extension WatchConnectivity: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) { }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in WatchConnectivity.shared.lastStatus = "❌ HK err" }
        print("❌ HK workout session error:", error)
    }
}

extension WatchConnectivity: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType),
              let stats = workoutBuilder.statistics(for: hrType),
              let q = stats.mostRecentQuantity()
        else { return }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = q.doubleValue(for: unit)

        Task { @MainActor in
            WatchConnectivity.shared.watchHeartRateBPM = bpm
            WatchConnectivity.shared.sendHeartRateToPhone(bpm)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
}
#endif
