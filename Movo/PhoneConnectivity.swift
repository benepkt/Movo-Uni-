import Foundation
import WatchConnectivity

final class PhoneConnectivity: NSObject, WCSessionDelegate {
    static let shared = PhoneConnectivity()
    private override init() { super.init() }

    // Keys
    private let activeWorkoutKey = "activeWorkoutPayloadJSON"
    private let watchStartOptionsKey = "watchStartOptionsJSON"
    private var lastActiveWorkoutJSON: String?
    private var lastActiveWorkoutPushAt: Date = .distantPast
    private var lastLiveUpdateSignature: String?
    private var lastLiveUpdateSentAt: Date = .distantPast

    // ✅ Callbacks (wichtig damit wirklich gespeichert wird)
    @MainActor var onSetLogged: ((String, String, Int, Double) -> Void)?
    @MainActor var onSetUpdated: ((String, String, String, Int, Double) -> Void)?   // NEU: workoutId, exerciseId, setId, reps, weight
    @MainActor var onSetRemoved: ((String, String) -> Void)?                         // NEU: workoutExerciseId, setId
    @MainActor var onExerciseChanged: ((String, String) -> Void)?
    @MainActor var onHeartRate: ((Double) -> Void)?
    @MainActor var onStartTemplateRequested: ((String) -> Void)?
    @MainActor var onStartPlanTemplateRequested: ((String) -> Void)?

    // MARK: - Dedupe Cache (verhindert doppelte Speicherung)
    private var recentEventIds: [String] = []
    private let recentEventMax = 100
    private func isDuplicateEvent(_ id: String?) -> Bool {
        guard let id, !id.isEmpty else { return false }
        if recentEventIds.contains(id) { return true }
        recentEventIds.append(id)
        if recentEventIds.count > recentEventMax {
            recentEventIds.removeFirst(recentEventIds.count - recentEventMax)
        }
        return false
    }

    // MARK: - Lifecycle

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - iPhone -> Watch (State)

    func pushActiveWorkoutState(_ payload: ActiveWorkoutPayload) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        guard session.isPaired, session.isWatchAppInstalled else {
            return
        }

        do {
            let data = try JSONEncoder().encode(payload)
            let json = String(data: data, encoding: .utf8) ?? ""
            let now = Date()
            if json == lastActiveWorkoutJSON,
               now.timeIntervalSince(lastActiveWorkoutPushAt) < 1 {
                return
            }
            lastActiveWorkoutJSON = json
            lastActiveWorkoutPushAt = now

            var context = session.applicationContext
            context[activeWorkoutKey] = json
            context["activeWorkoutUpdatedAt"] = Date().timeIntervalSince1970
            try session.updateApplicationContext(context)

            if session.isReachable {
                session.sendMessage(["type": "activeWorkoutStatePing"], replyHandler: nil, errorHandler: nil)
            }
        } catch {
            print("❌ pushActiveWorkoutState failed:", error.localizedDescription)
        }
    }

    func pushWatchStartOptions(_ payload: WatchStartOptionsPayload) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.isPaired, session.isWatchAppInstalled else { return }

        do {
            let data = try JSONEncoder().encode(payload)
            let json = String(data: data, encoding: .utf8) ?? ""
            var context = session.applicationContext
            context[watchStartOptionsKey] = json
            context["watchStartOptionsUpdatedAt"] = Date().timeIntervalSince1970
            try session.updateApplicationContext(context)
            if session.isReachable {
                session.sendMessage(["type": "watchStartOptionsPing"], replyHandler: nil, errorHandler: nil)
            }
        } catch {
            print("❌ pushWatchStartOptions failed:", error.localizedDescription)
        }
    }

    // MARK: - iPhone -> Watch (Live Update)

    func sendLiveUpdate(elapsed: TimeInterval,
                        completed: Int,
                        totalKg: Double,
                        unitRaw: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        guard session.isPaired, session.isWatchAppInstalled else { return }

        let elapsedBucket = Int(elapsed / 5)
        let totalBucket = Int(totalKg.rounded())
        let signature = "\(elapsedBucket)|\(completed)|\(totalBucket)|\(unitRaw.lowercased())"
        let now = Date()
        if signature == lastLiveUpdateSignature,
           now.timeIntervalSince(lastLiveUpdateSentAt) < 5 {
            return
        }
        lastLiveUpdateSignature = signature
        lastLiveUpdateSentAt = now

        let payload: [String: Any] = [
            "type": "liveUpdate",
            "elapsed": elapsed,
            "completed": completed,
            "totalKg": totalKg,
            "unitRaw": unitRaw.lowercased()
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            do { try session.updateApplicationContext(payload) } catch { }
        }
    }

    // MARK: - Watch -> iPhone (Events)

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in self.handleIncoming(payload: message) }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            self.handleIncoming(payload: message)
            replyHandler(["ok": true])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in self.handleIncoming(payload: userInfo) }
    }

    // ✅ WICHTIG: HR-Fallback (und weitere States) kommen oft via ApplicationContext
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in self.handleIncoming(payload: applicationContext) }
    }

    @MainActor
    private func handleIncoming(payload: [String: Any]) {
        guard let type = payload["type"] as? String else { return }

        switch type {

        case "hr":
            guard let bpm = payload["bpm"] as? Double else { return }
            onHeartRate?(bpm)

        case "set_logged":
            if isDuplicateEvent(payload["eventId"] as? String) {
                print("↩️ duplicate set_logged ignored (eventId)")
                return
            }
            guard
                let workoutId = payload["workoutId"] as? String,
                let workoutExerciseId = payload["workoutExerciseId"] as? String,
                let reps = payload["reps"] as? Int,
                let weight = payload["weight"] as? Double
            else {
                print("❌ set_logged missing fields:", payload)
                return
            }
            print("✅ RECEIVED set_logged FROM WATCH ✅",
                  "workoutId:", workoutId,
                  "exerciseId:", workoutExerciseId,
                  "reps:", reps,
                  "weight:", weight
            )
            onSetLogged?(workoutId, workoutExerciseId, reps, weight)

        case "set_updated":
            if isDuplicateEvent(payload["eventId"] as? String) {
                print("↩️ duplicate set_updated ignored (eventId)")
                return
            }
            guard
                let workoutId = payload["workoutId"] as? String,
                let workoutExerciseId = payload["workoutExerciseId"] as? String,
                let setId = payload["setId"] as? String,
                let reps = payload["reps"] as? Int,
                let weight = payload["weight"] as? Double
            else {
                print("❌ set_updated missing fields:", payload)
                return
            }
            print("✅ RECEIVED set_updated FROM WATCH ✅",
                  "workoutId:", workoutId,
                  "exerciseId:", workoutExerciseId,
                  "setId:", setId,
                  "reps:", reps,
                  "weight:", weight
            )
            onSetUpdated?(workoutId, workoutExerciseId, setId, reps, weight)

        case "set_removed":
            if isDuplicateEvent(payload["eventId"] as? String) {
                print("↩️ duplicate set_removed ignored (eventId)")
                return
            }
            guard
                let workoutExerciseId = payload["workoutExerciseId"] as? String,
                let setId = payload["setId"] as? String
            else {
                print("❌ set_removed missing fields:", payload)
                return
            }
            print("✅ RECEIVED set_removed FROM WATCH ✅",
                  "exerciseId:", workoutExerciseId,
                  "setId:", setId
            )
            onSetRemoved?(workoutExerciseId, setId)

        case "exercise_changed":
            guard
                let workoutId = payload["workoutId"] as? String,
                let workoutExerciseId = payload["workoutExerciseId"] as? String
            else { return }
            onExerciseChanged?(workoutId, workoutExerciseId)

        case "start_template_from_watch":
            guard let templateId = payload["templateId"] as? String else { return }
            onStartTemplateRequested?(templateId)

        case "start_plan_template_from_watch":
            guard let templateId = payload["templateId"] as? String else { return }
            onStartPlanTemplateRequested?(templateId)

        default:
            break
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error { print("iOS WCSession activation error:", error.localizedDescription) }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📶 iOS Reachability changed:", session.isReachable)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}
