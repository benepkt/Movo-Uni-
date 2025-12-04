import ActivityKit
import WidgetKit
import SwiftUI

struct MovoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Effektive Sprache bestimmen (ContentState → App Group/UserDefaults → Locale)
            let lang = effectiveLanguage(from: context)

            HStack {
                TrainingMetricView(
                    icon: "figure.strengthtraining.traditional",
                    label: L("live.sets", lang),
                    value: "\(context.state.completedExercises)"
                )

                Divider().frame(height: 40)

                TrainingMetricView(
                    icon: "clock",
                    label: L("live.duration", lang),
                    value: "\(Int(context.state.elapsedTime) / 60)m"
                )

                Divider().frame(height: 40)

                // Gewicht mit korrekter Einheit (kg/lb) und lokalem Zahlformat
                TrainingMetricView(
                    icon: "scalemass",
                    label: L("live.weight", lang),
                    value: formatWeightLong(
                        kg: context.state.totalWeight,
                        unitRaw: context.state.weightUnitRaw
                    )
                )
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            let lang = effectiveLanguage(from: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TrainingMetricMini(
                        icon: "figure.strengthtraining.traditional",
                        value: "\(context.state.completedExercises)"
                    )
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text("🏋️ " + L("live.running", lang))
                            .font(.subheadline)
                        HStack(spacing: 12) {
                            TrainingMetricMini(
                                icon: "clock",
                                value: "\(Int(context.state.elapsedTime) / 60)m"
                            )
                            // Kurzformat ohne Leerzeichen, 0–1 Nachkommastellen
                            TrainingMetricMini(
                                icon: "scalemass",
                                value: formatWeightShort(
                                    kg: context.state.totalWeight,
                                    unitRaw: context.state.weightUnitRaw
                                )
                            )
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("⏱").font(.title3)
                }

            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")

            } compactTrailing: {
                Text("\(Int(context.state.elapsedTime) / 60)m")

            } minimal: {
                Text("🏋️")
            }
        }
    }
}

// MARK: - Format-Helpers (keine App-Abhängigkeit)

private func formatWeightLong(kg: Double, unitRaw: String) -> String {
    let (value, symbol) = convert(kg: kg, unitRaw: unitRaw)
    let nf = NumberFormatter()
    nf.locale = .current
    nf.numberStyle = .decimal
    nf.minimumFractionDigits = 0
    nf.maximumFractionDigits = 2
    return (nf.string(from: NSNumber(value: value)) ?? "0") + " " + symbol
}

private func formatWeightShort(kg: Double, unitRaw: String) -> String {
    let (value, symbol) = convert(kg: kg, unitRaw: unitRaw)
    let nf = NumberFormatter()
    nf.locale = .current
    nf.numberStyle = .decimal
    nf.minimumFractionDigits = 0
    nf.maximumFractionDigits = 1
    return (nf.string(from: NSNumber(value: value)) ?? "0") + symbol
}

private func convert(kg: Double, unitRaw: String) -> (Double, String) {
    if unitRaw.lowercased() == "lb" {
        return (kg * 2.20462262185, "lb")
    } else {
        return (kg, "kg")
    }
}

// MARK: - Mini-Views

struct TrainingMetricView: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Label(value, systemImage: icon)
                .font(.subheadline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TrainingMetricMini: View {
    let icon: String
    let value: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.caption)
    }
}

// MARK: - Lokalisierung (leichtgewichtige Widget-Variante)

/// Sprache: 1) aus ContentState.languageRaw, 2) App Group "app.language", 3) Standard-Defaults, 4) Locale-Fallback
func effectiveLanguage(from context: ActivityViewContext<WorkoutActivityAttributes>) -> String {
    // 1) Aus dem ContentState (wenn vorhanden)
    let raw = context.state.languageRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    if !raw.isEmpty { return raw.lowercased() }

    // 2) App Group (Widget <-> App). APP_GROUP_ID muss in einer Shared-Datei definiert sein.
    if let ud = UserDefaults(suiteName: APP_GROUP_ID),
       let code = ud.string(forKey: "app.language"), !code.isEmpty {
        return code.lowercased()
    }

    // 3) Standard-Defaults (Fallback)
    if let code = UserDefaults.standard.string(forKey: "app.language"), !code.isEmpty {
        return code.lowercased()
    }

    // 4) Locale-Fallback
    return (Locale.current.languageCode ?? "en").lowercased()
}

/// Mini-String-Tabelle nur für die Live Activity.
/// Keys an deine App-Strings angelehnt, aber unabhängig, damit das Widget eigenständig bleibt.
private func L(_ key: String, _ lang: String) -> String {
    let de: [String: String] = [
        "live.sets": "Sätze",
        "live.duration": "Dauer",
        "live.weight": "Gewicht",
        "live.running": "Training läuft"
    ]
    let en: [String: String] = [
        "live.sets": "Sets",
        "live.duration": "Time",
        "live.weight": "Weight",
        "live.running": "Workout running"
    ]
    let isDE = lang.hasPrefix("de")
    return (isDE ? de[key] : en[key]) ?? en[key] ?? key
}
