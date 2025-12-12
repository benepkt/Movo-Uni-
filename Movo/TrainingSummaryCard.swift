import SwiftUI
import Foundation

struct TrainingSummaryCard: View {
    let entry: TrainingEntry
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var trainingStore: TrainingStore

    private var isWeek: Bool {
        let t = entry.title.lowercased()
        return t.contains("woche ") || t.contains("week ")
    }
    
    private var isJogging: Bool {
        let t = entry.title.lowercased()
        return t.contains("joggen") || t.contains("running") || t.contains("lauf")
    }

    var body: some View {
        NavigationLink {
            TrainingDetailView(training: entry)
                .environmentObject(appSettings)
                .environmentObject(trainingStore)
        } label: { cardLabel }
        .buttonStyle(.plain)
    }

    // MARK: - Label
    @ViewBuilder
    private var cardLabel: some View {
        if isJogging {
            joggingVariant
        } else if isWeek {
            weekVariant
        } else {
            defaultVariant
        }
    }

    // MARK: - Default (nicht-Week)
    private var defaultVariant: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.title3.weight(.semibold))

            Text("\(formattedDate(entry.date)) • \(entry.exercises.count) \(appSettings.localized("exercises")) • \(totalSets(entry)) \(appSettings.localized("sets"))")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text(appSettings.localized("see.details"))
                .font(.footnote)
                .foregroundColor(appSettings.accentColor)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Jogging-Variante (fitness tracking style)
    private var joggingVariant: some View {
        let distanceKm = extractDistance(from: entry.title)
        let duration = entry.duration
        let pace = calculatePace(distance: distanceKm, duration: duration)
        let calories = estimateCalories(distanceKm: distanceKm)
        
        return VStack(alignment: .leading, spacing: 16) {
            // Large distance at top
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.2f", distanceKm).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 48, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                
                Image(systemName: "figure.run")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.green)
            }
            
            // Activity type
            Text("Outdoor Running")
                .font(.title3.weight(.semibold))
            
            // Date/time info
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(formattedDateTime(entry.date, duration: duration))
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            
            // Stats grid - 2 columns
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    statBlock(value: String(format: "%.0f", calories), unit: "KCAL", label: "Active Calories")
                    statBlock(value: String(format: "%.2f", distanceKm).replacingOccurrences(of: ".", with: ","), unit: "KM", label: "Distance")
                }
                
                HStack(spacing: 12) {
                    statBlock(value: formattedDuration(duration), unit: "", label: "Duration")
                    statBlock(value: pace, unit: "MIN/KM", label: "Avg Pace")
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    private func statBlock(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    // Helper functions for jogging variant
    private func extractDistance(from title: String) -> Double {
        // Extract distance from title like "Joggen – 5.23 km"
        let components = title.components(separatedBy: "–")
        if components.count > 1 {
            let distPart = components[1].trimmingCharacters(in: .whitespaces)
            let numString = distPart.replacingOccurrences(of: "km", with: "")
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespaces)
            return Double(numString) ?? 0.0
        }
        return 0.0
    }
    
    private func calculatePace(distance: Double, duration: TimeInterval) -> String {
        guard distance > 0 else { return "--:--" }
        let secondsPerKm = duration / distance
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func estimateCalories(distanceKm: Double) -> Double {
        // Simple estimate: ~75 kg person * 0.75 kcal per kg per km
        return distanceKm * 75.0 * 0.75
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formattedDateTime(_ date: Date, duration: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM 'at' HH:mm"
        let startTime = formatter.string(from: date)
        
        let endDate = date.addingTimeInterval(duration)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let endTime = timeFormatter.string(from: endDate)
        
        return "\(startTime)–\(endTime)"
    }

    // MARK: - Week-Variante (zeit-/stationsbasiert)
    private var weekVariant: some View {
        let week = entryAsWeek(entry)
        let plan = plannedTiming(for: week)

        let dateString = formattedDate(entry.date)
        let exercisesCount = entry.exercises.count
        let setsCount = totalSets(entry)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 54, height: 54)
                Image(systemName: "calendar")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(localizedWeekTitle(entry.title, weekFormat: appSettings.localized("week.number")))
                    .font(.headline)

                Text(dateString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    chip(icon: "clock",
                         text: "\(plan.minutes) min • \(plan.rounds)×")

                    chip(icon: "figure.strengthtraining.traditional",
                         text: "\(exercisesCount) \(appSettings.localized("details.exercises"))")

                    chip(icon: "square.grid.3x3.fill",
                         text: "\(setsCount) \(appSettings.localized("details.sets"))")
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - UI Helpers
    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).imageScale(.small)
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(.tertiarySystemBackground)))
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func totalSets(_ entry: TrainingEntry) -> Int {
        entry.exercises.flatMap { $0.sets }.count
    }

    // MARK: - Planung (eingebettet, um keinen Code zu duplizieren)
    private struct PlanConsts {
        static let targetTotalSeconds = 900
        static let exerciseSeconds = 35
        static let restBetweenExercisesSeconds = 20
        static let restBetweenRoundsSeconds = 45
    }
    private struct PlannedSession {
        let rounds: Int
        let totalSeconds: Int
        var minutes: Int { Int(round(Double(totalSeconds) / 60.0)) }
    }

    private func plannedTiming(for week: Week) -> PlannedSession {
        // Anzahl Stationen aus Warmup + Übungen + Cooldown (robust, kein stationCount nötig)
        let exCount = max((week.warmUp + week.exercises + week.coolDown).count, 1)

        let perRound = exCount * PlanConsts.exerciseSeconds
                     + max(0, exCount - 1) * PlanConsts.restBetweenExercisesSeconds

        let approxPerRoundWithLongRest = perRound + PlanConsts.restBetweenRoundsSeconds
        let rounds = max(
            2,
            Int(ceil(Double(PlanConsts.targetTotalSeconds + PlanConsts.restBetweenRoundsSeconds)
                     / Double(max(1, approxPerRoundWithLongRest))))
        )
        let totalSeconds = rounds * perRound + max(0, rounds - 1) * PlanConsts.restBetweenRoundsSeconds
        return PlannedSession(rounds: rounds, totalSeconds: totalSeconds)
    }

    /// Minimale Rekonstruktion, falls hier nur `TrainingEntry` vorliegt.
    private func entryAsWeek(_ entry: TrainingEntry) -> Week {
        Week(number: 0, warmUp: [], exercises: entry.exercises, coolDown: [])
    }
}

// falls du die Funktion nicht schon woanders hast:
@inline(__always)
func localizedWeekTitle(_ raw: String, weekFormat: String = "Woche %d") -> String {
    let lower = raw.lowercased().replacingOccurrences(of: "week", with: "woche")
    if let n = lower.components(separatedBy: CharacterSet.decimalDigits.inverted)
        .compactMap({ Int($0) }).first {
        return String(format: weekFormat, n)
    }
    return raw.replacingOccurrences(of: "week", with: "Woche", options: .caseInsensitive)
}
