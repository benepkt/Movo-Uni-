//
//  MovoLiveActivityControl.swift
//  MovoLiveActivity
//
//  Created by Benedikt on 06.08.25.
//

import AppIntents
import SwiftUI
import WidgetKit
import ActivityKit   // ⬅️ NEU


struct MovoLiveActivityControl: ControlWidget {
    static let kind: String = "benepkt.Movo.MovoLiveActivity"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

extension MovoLiveActivityControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> MovoLiveActivityControl.Value {
            .init(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> MovoLiveActivityControl.Value {
            // Live Activity läuft, wenn es mind. eine Workout-Activity gibt
            let running = !Activity<WorkoutActivityAttributes>.activities.isEmpty
            return .init(isRunning: running, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Timer Name Configuration"

    @Parameter(title: "Timer Name", default: "Timer")
    var timerName: String
}
struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer Name")
    var name: String

    @Parameter(title: "Timer is running")
    var value: Bool

    init() {}
    init(_ name: String) { self.name = name }

    func perform() async throws -> some IntentResult {
        if value {
            // Einschalten → starte Live Activity, falls noch keine läuft
            if Activity<WorkoutActivityAttributes>.activities.isEmpty {
                try await startWorkoutActivity()
            }
        } else {
            // Ausschalten → beende alle laufenden Activities
            await endAllWorkoutActivities()
        }
        // Widget/Control neu laden
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    // MARK: - Helpers (nur in der Extension nötig)

    private func startWorkoutActivity() async throws {
        let attributes = WorkoutActivityAttributes(
            workoutID: UUID(),
            startedAt: Date()
        )
        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedTime: 0,
            completedExercises: 0,
            totalWeight: 0
        )
        _ = try Activity<WorkoutActivityAttributes>.request(
            attributes: attributes,
            contentState: initialState,
            pushType: nil
        )
    }

    private func endAllWorkoutActivities() async {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
