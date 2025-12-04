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
        if isWeek {
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
