import Foundation
import PostHog

enum AnalyticsService {
    static let analyticsEnabledKey = "analyticsEnabled"

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: analyticsEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: analyticsEnabledKey)
    }

    static func applyAnalyticsPreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: analyticsEnabledKey)
        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    static func identifyUser(id: String, isGuest: Bool, provider: String? = nil) {
        guard isEnabled else { return }
        guard !id.isEmpty else { return }

        var properties: [String: Any] = [
            "is_guest": isGuest,
            "platform": "ios"
        ]
        if let provider {
            properties["auth_provider"] = provider
        }

        PostHogSDK.shared.identify(id, userProperties: properties)
        track("user_identified", properties: properties)
    }

    static func resetUser() {
        PostHogSDK.shared.reset()
    }

    static func screen(_ name: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        var screenProperties = properties
        screenProperties["screen_name"] = name
        track("screen_viewed", properties: screenProperties)
    }

    static func track(_ event: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event, properties: enriched(properties))
    }

    static func trackWorkoutSaved(entry: TrainingEntry,
                                  historyCountBeforeSave: Int,
                                  source: String) {
        let exercises = entry.exercises
        let sets = exercises.flatMap(\.sets)
        let completedSets = sets.filter(\.isCompleted).count
        let embeddedActivities = entry.activities.count
        let durationMinutes = max(0, Int((entry.duration / 60).rounded()))
        let hasEntryActivityMetrics = entry.loggedDistanceKm != nil
            || entry.activeCalories != nil
            || entry.averageHeartRate != nil
            || entry.elevationGainM != nil
        let hasEmbeddedActivityMetrics = entry.activities.contains { activity in
            activity.distanceKm != nil
                || activity.resistanceLevel != nil
                || activity.inclinePercent != nil
                || activity.averageWatts != nil
                || activity.activeCalories != nil
                || activity.averageHeartRate != nil
                || activity.elevationGainM != nil
        }

        track("workout_saved", properties: [
            "source": source,
            "mode": exercises.isEmpty ? "activity" : "strength",
            "exercise_count": exercises.count,
            "set_count": sets.count,
            "completed_set_count": completedSets,
            "embedded_activity_count": embeddedActivities,
            "duration_minutes": durationMinutes,
            "has_activity_metrics": hasEntryActivityMetrics || hasEmbeddedActivityMetrics,
            "history_count_before": historyCountBeforeSave,
            "is_first_workout": historyCountBeforeSave == 0
        ])
    }

    static func trackWorkoutStarted(source: String,
                                    template: TrainingTemplate? = nil,
                                    hasActivePlan: Bool = false) {
        var properties: [String: Any] = [
            "source": source,
            "has_active_plan": hasActivePlan
        ]

        if let template {
            properties["template_id"] = template.id
            properties["exercise_count"] = template.exercises.count
            properties["activity_count"] = template.activities.count
            properties["is_movo_template"] = template.ownerId == "builtin" || template.ownerId == "movo"
        }

        track("workout_started", properties: properties)

        if template != nil {
            let event = source == "from_plan" || source == "watch_plan"
                ? "plan_template_started"
                : "template_started"
            track(event, properties: properties)
        }
    }

    static func trackPlanSaved(isEditing: Bool,
                               templateCount: Int,
                               trainingDaysPerWeek: Int,
                               durationWeeks: Int,
                               isUnlimited: Bool,
                               smartOrderingEnabled: Bool,
                               movoTemplateCount: Int,
                               ownTemplateCount: Int) {
        track(isEditing ? "plan_updated" : "plan_created", properties: [
            "template_count": templateCount,
            "training_days_per_week": trainingDaysPerWeek,
            "duration_weeks": isUnlimited ? 0 : durationWeeks,
            "is_unlimited": isUnlimited,
            "smart_ordering_enabled": smartOrderingEnabled,
            "movo_template_count": movoTemplateCount,
            "own_template_count": ownTemplateCount
        ])
    }

    static func trackTemplateCreated(_ template: TrainingTemplate, source: String) {
        track("template_created", properties: [
            "source": source,
            "exercise_count": template.exercises.count,
            "activity_count": template.activities.count,
            "is_movo_template": template.ownerId == "builtin" || template.ownerId == "movo"
        ])
    }

    static func trackTemplateDeleted(_ template: TrainingTemplate) {
        track("template_deleted", properties: [
            "exercise_count": template.exercises.count,
            "activity_count": template.activities.count
        ])
    }

    private static func enriched(_ properties: [String: Any]) -> [String: Any] {
        var result = properties
        result["app_area"] = "movo"
        result["schema_version"] = 1
        return result
    }
}
