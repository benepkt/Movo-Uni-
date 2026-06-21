import ActivityKit
import WidgetKit
import SwiftUI

private let liveAccent = Color(red: 0.30, green: 0.72, blue: 1.00)

struct MovoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Effektive Sprache bestimmen (ContentState → App Group/UserDefaults → Locale)
            let lang = effectiveLanguage(from: context)
            let elapsed = "\(Int(context.state.elapsedTime) / 60)m"
            let weight = formatWeightLong(
                kg: context.state.totalWeight,
                unitRaw: context.state.weightUnitRaw
            )
            let isActivity = context.state.modeRaw == "activity"
            let title = isActivity && !context.state.activityTitle.isEmpty ? context.state.activityTitle : L("live.running", lang)
            let distance = formatDistance(context.state.distanceKm)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(liveAccent.opacity(0.18))
                            .frame(width: 42, height: 42)
                        Image(systemName: isActivity ? context.state.activityIcon : "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(liveAccent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(L("live.keepGoing", lang))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.56))
                    }

                    Spacer()

                    Text(elapsed)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                HStack(spacing: 10) {
                    TrainingMetricView(
                        icon: isActivity ? "point.topleft.down.curvedto.point.bottomright.up" : "checkmark.circle.fill",
                        label: isActivity ? L("live.distance", lang) : L("live.sets", lang),
                        value: isActivity ? distance : "\(context.state.completedExercises)"
                    )

                    TrainingMetricView(
                        icon: isActivity ? "speedometer" : "scalemass.fill",
                        label: isActivity ? L("live.paceSpeed", lang) : L("live.weight", lang),
                        value: isActivity ? (context.state.paceOrSpeed.isEmpty ? "—" : context.state.paceOrSpeed) : weight
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.06, blue: 0.08), Color(red: 0.08, green: 0.10, blue: 0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(liveAccent)

        } dynamicIsland: { context in
            let lang = effectiveLanguage(from: context)
            let elapsed = "\(Int(context.state.elapsedTime) / 60)m"
            let shortWeight = formatWeightShort(
                kg: context.state.totalWeight,
                unitRaw: context.state.weightUnitRaw
            )
            let isActivity = context.state.modeRaw == "activity"
            let title = isActivity && !context.state.activityTitle.isEmpty ? context.state.activityTitle : L("live.running", lang)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandMetricBlock(
                        icon: isActivity ? "point.topleft.down.curvedto.point.bottomright.up" : "checkmark.circle.fill",
                        label: isActivity ? L("live.distance", lang) : L("live.sets", lang),
                        value: isActivity ? formatDistance(context.state.distanceKm) : "\(context.state.completedExercises)"
                    )
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: isActivity ? context.state.activityIcon : "bolt.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(liveAccent)
                            Text(title)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        Text(L("live.tapToContinue", lang))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    IslandMetricBlock(
                        icon: "clock.fill",
                        label: L("live.duration", lang),
                        value: elapsed
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        IslandPill(icon: isActivity ? "speedometer" : "scalemass.fill", text: isActivity ? (context.state.paceOrSpeed.isEmpty ? "—" : context.state.paceOrSpeed) : shortWeight)
                        IslandPill(icon: isActivity ? context.state.activityIcon : "figure.strengthtraining.traditional", text: isActivity ? L("live.activity", lang) : L("live.strength", lang))
                    }
                    .padding(.top, 2)
                }

            } compactLeading: {
                Image(systemName: isActivity ? context.state.activityIcon : "bolt.fill")
                    .foregroundStyle(liveAccent)

            } compactTrailing: {
                Text(elapsed)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()

            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(liveAccent)
            }
            .keylineTint(liveAccent)
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

private func formatDistance(_ km: Double) -> String {
    guard km > 0 else { return "0.0km" }
    return String(format: "%.2fkm", km)
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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(liveAccent)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.48))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct IslandMetricBlock: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(liveAccent)
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct IslandPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.10))
        .clipShape(Capsule())
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
        "live.running": "Training läuft",
        "live.keepGoing": "Weiter dranbleiben",
        "live.tapToContinue": "Zum Fortsetzen öffnen",
        "live.strength": "Kraft",
        "live.distance": "Distanz",
        "live.paceSpeed": "Tempo",
        "live.activity": "Aktivität"
    ]
    let en: [String: String] = [
        "live.sets": "Sets",
        "live.duration": "Time",
        "live.weight": "Weight",
        "live.running": "Workout running",
        "live.keepGoing": "Keep going",
        "live.tapToContinue": "Open to continue",
        "live.strength": "Strength",
        "live.distance": "Distance",
        "live.paceSpeed": "Pace",
        "live.activity": "Activity"
    ]
    let isDE = lang.hasPrefix("de")
    return (isDE ? de[key] : en[key]) ?? en[key] ?? key
}
