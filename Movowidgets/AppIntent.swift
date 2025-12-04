//  AppIntent.swift

import WidgetKit
import AppIntents

@available(iOSApplicationExtension 17.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {

    static var title: LocalizedStringResource { "Schritte-Widget" }

    static var description: IntentDescription {
        "Stelle das Tagesziel für dieses Schritte-Widget ein."
    }

    // Das Ziel gehört *nur* zu diesem Widget
    @Parameter(title: "Tagesziel", default: 10000)
    var dailyGoal: Int
}
