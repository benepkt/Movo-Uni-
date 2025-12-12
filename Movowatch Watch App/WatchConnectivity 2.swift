import Foundation
import WatchConnectivity

extension WatchConnectivity {
    func logSetLiveOnly(workoutId: String, workoutExerciseId: String, reps: Int, weight: Double) {
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
            session.sendMessage(payload, replyHandler: nil, errorHandler: { error in
                print("sendMessage error:", error.localizedDescription)
            })
            lastStatus = "📤 live"
        } else {
            lastStatus = "⚠️ not reachable"
        }
    }

    func logSetReliableOnly(workoutId: String, workoutExerciseId: String, reps: Int, weight: Double) {
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
        pendingCount += 1
        lastStatus = "📤 queued (\(pendingCount))"
        session.transferUserInfo(payload)
    }

    // NEU: Update eines bestehenden Satzes
    func updateSet(workoutId: String, workoutExerciseId: String, setId: String, reps: Int, weight: Double) {
        refreshFlags()
        let payload: [String: Any] = [
            "type": "set_updated",
            "workoutId": workoutId,
            "workoutExerciseId": workoutExerciseId,
            "setId": setId,
            "reps": reps,
            "weight": weight,
            "timestamp": Date().timeIntervalSince1970,
            "eventId": UUID().uuidString,
            "deviceId": "watch"
        ]
        let session = WCSession.default

        // zuverlässig in die Queue
        pendingCount += 1
        lastStatus = "📤 queued (\(pendingCount))"
        session.transferUserInfo(payload)

        // optional sofort live
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { error in
                print("sendMessage error:", error.localizedDescription)
            })
            lastStatus = "📤 live + queued"
        }

        // Optimistic UI Update lokal
        applyOptimisticUpdate_UpdateSet(exerciseId: workoutExerciseId, setId: setId, reps: reps, weight: weight)
    }

    // NEU: Satz löschen
    func removeSet(workoutExerciseId: String, setId: String) {
        refreshFlags()
        let payload: [String: Any] = [
            "type": "set_removed",
            "workoutExerciseId": workoutExerciseId,
            "setId": setId,
            "timestamp": Date().timeIntervalSince1970,
            "eventId": UUID().uuidString,
            "deviceId": "watch"
        ]
        let session = WCSession.default

        // zuverlässig queue
        pendingCount += 1
        lastStatus = "🗑️ queued (\(pendingCount))"
        session.transferUserInfo(payload)

        // optional live
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { error in
                print("sendMessage error:", error.localizedDescription)
            })
            lastStatus = "🗑️ live + queued"
        }

        // Optimistic lokal: Satz entfernen, ggf. Übung entfernen
        applyOptimisticUpdate_RemoveSet(exerciseId: workoutExerciseId, setId: setId)
    }

    // MARK: - Optimistic Updates lokal

    // Renamed to avoid collision with the primary logSet in WatchConnectivity.swift
    func logSetOptimistic(workoutId: String,
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

        // ✅ reliable queue
        pendingCount += 1
        lastStatus = "📤 queued (\(pendingCount))"
        session.transferUserInfo(payload)

        // ✅ optional immediate
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { error in
                print("sendMessage error:", error.localizedDescription)
            })
            lastStatus = "📤 live + queued"
        } else {
            lastStatus = "📤 queued (offline)"
        }

        // Optimistic UI Update lokal
        applyOptimisticUpdate_LogSet(exerciseId: workoutExerciseId, reps: reps, weight: weight)
    }

    // Optional: neuer Satz lokal mit Defaults vom letzten Satz erzeugen (für Watch-UI)
    func addSetOptimisticWithDefaults(exerciseId: String) {
        var payload = self.activeWorkout
        guard let idx = payload.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        var exercise = payload.exercises[idx]
        let last = exercise.sets.last
        let newSet = ActiveWorkoutPayload.LoggedSetItem(
            id: UUID().uuidString,
            reps: last?.reps ?? 0,
            weight: last?.weight ?? 0.0,
            completed: false
        )
        exercise.sets.append(newSet)
        exercise.setCount = exercise.sets.count
        payload.exercises[idx] = exercise

        self.activeWorkout = payload
    }

    // Mutiert @Published activeWorkout sofort
    private func applyOptimisticUpdate_LogSet(exerciseId: String, reps: Int, weight: Double) {
        var payload = self.activeWorkout
        guard let idx = payload.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        var exercise = payload.exercises[idx]
        let newSet = ActiveWorkoutPayload.LoggedSetItem(
            id: UUID().uuidString,
            reps: reps,
            weight: weight,
            completed: false
        )
        exercise.sets.append(newSet)
        exercise.setCount = exercise.sets.count
        payload.exercises[idx] = exercise

        self.activeWorkout = payload
    }

    private func applyOptimisticUpdate_UpdateSet(exerciseId: String, setId: String, reps: Int, weight: Double) {
        var payload = self.activeWorkout
        guard let exIdx = payload.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        var exercise = payload.exercises[exIdx]
        guard let setIdx = exercise.sets.firstIndex(where: { $0.id == setId }) else { return }

        exercise.sets[setIdx].reps = reps
        exercise.sets[setIdx].weight = weight
        exercise.sets[setIdx].completed = exercise.sets[setIdx].completed // keep as-is
        exercise.setCount = exercise.sets.count
        payload.exercises[exIdx] = exercise

        self.activeWorkout = payload
    }

    private func applyOptimisticUpdate_RemoveSet(exerciseId: String, setId: String) {
        var payload = self.activeWorkout
        guard let exIdx = payload.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        var exercise = payload.exercises[exIdx]

        if let setIdx = exercise.sets.firstIndex(where: { $0.id == setId }) {
            exercise.sets.remove(at: setIdx)
        }

        if exercise.sets.isEmpty {
            // ganze Übung entfernen
            payload.exercises.remove(at: exIdx)
        } else {
            exercise.setCount = exercise.sets.count
            payload.exercises[exIdx] = exercise
        }

        self.activeWorkout = payload
    }
}

