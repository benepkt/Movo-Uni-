import SwiftUI
import MapKit
import CoreLocation

// MARK: - Training Detail

struct TrainingDetailView: View {
    let training: TrainingEntry
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var trainingStore: TrainingStore
    @Environment(\.designTokens) private var t

    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg
    @State private var editedActivities: [WorkoutActivityBlock] = []
    @State private var didLoadActivities = false
    @State private var activityEditTarget: WorkoutActivityBlock?

    // WEEK vs RUN vs STRENGTH
    private var isWeek: Bool {
        let t = training.title.lowercased()
        return t.contains("woche ") || t.contains("week ")
    }

    private var isRun: Bool {
        !isWeek && training.exercises.isEmpty
    }

    // MARK: - Run Analytics

    private var runDistanceKm: Double? {
        if let logged = training.loggedDistanceKm, logged > 0 { return logged }
        return extractDistanceKm(from: training.title)
    }

    private var runAnalytics: RunAnalytics? {
        guard let d = runDistanceKm, d > 0 else { return nil }

        let coords: [CLLocationCoordinate2D]
        if let poly = training.routePolyline, !poly.isEmpty {
            coords = decodePolyline(poly)
        } else {
            coords = []
        }

        return RunAnalytics(
            distanceKm: d,
            duration: training.duration,
            coordinates: coords
        )
    }

    private var runDurationText: String {
        formatHMS(training.duration)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            detailBackground

            ScrollView {
                VStack(spacing: 22) {
                    detailHero
                    if isWeek {
                        weekSection
                    } else if isRun {
                        runSection
                    } else {
                        strengthSection
                    }
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            if !didLoadActivities {
                editedActivities = training.activities
                didLoadActivities = true
            }
        }
        .sheet(item: $activityEditTarget) { activity in
            TrainingActivityEditSheet(
                activity: activity,
                isDE: appSettings.language.lowercased().hasPrefix("de"),
                accent: t.palette.primary
            ) { updated in
                updateStoredActivity(updated)
            }
        }
    }

    private var detailBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [t.palette.primary.opacity(0.36), Color.blue.opacity(0.14), .clear],
                center: .topLeading,
                startRadius: 24,
                endRadius: 430
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color.cyan.opacity(0.11), .clear],
                center: .bottomTrailing,
                startRadius: 28,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    private var detailHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(detailKindTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(t.palette.primary)
                    Text(detailTitle)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Text(dateString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
                Text(training.emoji ?? (isRun ? "🔥" : "💪"))
                    .font(.system(size: 34))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.10)))
                    .overlay(Circle().stroke(.white.opacity(0.13), lineWidth: 1))
            }
            DetailMetaChips(items: isRun ? runMetaItems : (isWeek ? weekMetaItems : strengthMetaItems))
        }
    }

    private var detailTitle: String {
        if isWeek {
            return localizedWeekTitle(training.title, weekFormat: appSettings.localized("week.number"))
        }
        return training.title.isEmpty ? L("training.training", "Training") : training.title
    }

    private var detailKindTitle: String {
        if isWeek { return L("details.plan", "Plan") }
        if isRun { return cardioTypeText }
        return L("details.strength", "Krafttraining")
    }

    // MARK: - WEEK SECTION

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            let plan = plannedTimingForWeekEntry()
            HStack(spacing: 12) {
                DetailMetricCard(
                    title: L("details.duration", "Dauer"),
                    value: "~\(plan.minutes) min",
                    icon: "clock"
                )
                DetailMetricCard(
                    title: L("calories", "Kalorien"),
                    value: "~\(plan.kcal) kcal",
                    icon: "flame.fill"
                )
            }

            VStack(spacing: 14) {
                ForEach(training.exercises) { ex in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(ex.name)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("35s × 3 \(L("rounds.short", "Rdn"))")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundStyle(.white.opacity(0.78))
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
        }
    }

    private var weekMetaItems: [DetailMetaChips.Item] {
        [
            .init(icon: "calendar", title: dateString),
            .init(icon: "figure.strengthtraining.traditional",
                  title: "\(training.exercises.count) \(L("details.exercises", "Übungen"))"),
            .init(icon: "square.grid.3x3.fill",
                  title: "3 \(L("rounds", "Runden"))")
        ]
    }

    private func plannedTimingForWeekEntry() -> (minutes: Int, kcal: Int) {
        let exerciseSeconds = 35
        let restBetweenExercises = 20
        let restBetweenRounds = 45
        let rounds = 3

        let exCount = max(training.exercises.count, 1)
        let perRound = exCount * exerciseSeconds
        + max(0, exCount - 1) * restBetweenExercises

        let totalSeconds = rounds * perRound
        + max(0, rounds - 1) * restBetweenRounds

        let minutes = Int(round(Double(totalSeconds) / 60.0))
        let kcal = Int(round((Double(totalSeconds) / 60.0) * 8.0))
        return (minutes, kcal)
    }
    // MARK: - RUN SECTION

    private var runSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let analytics = runAnalytics {
                RunSummaryGrid(
                    analytics: analytics,
                    durationText: runDurationText,
                    cardioType: cardioTypeText,
                    activeCalories: training.activeCalories,
                    averageHeartRate: training.averageHeartRate,
                    elevationGainM: training.elevationGainM,
                    perceivedEffort: training.perceivedEffort
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    DetailMetricCard(
                        title: L("details.duration", "Dauer"),
                        value: runDurationText,
                        icon: "clock"
                    )
                    if let calories = training.activeCalories {
                        DetailMetricCard(title: L("run.calories", "Kalorien"), value: "\(Int(calories.rounded())) kcal", icon: "flame.fill")
                    }
                    if let hr = training.averageHeartRate {
                        DetailMetricCard(title: "Ø Puls", value: "\(Int(hr.rounded())) bpm", icon: "heart.fill")
                    }
                    if let effort = training.perceivedEffort {
                        DetailMetricCard(title: L("details.effort", "Anstrengung"), value: "\(effort)/10", icon: "gauge.with.dots.needle.67percent")
                    }
                }
            }

            activityDetailsCard

            // Karte
            if let analytics = runAnalytics, !analytics.coordinates.isEmpty {
                RunRouteMap(route: analytics.coordinates)
            } else if let poly = training.routePolyline,
                      !poly.isEmpty {
                RunRouteMap(route: decodePolyline(poly))
            }

            // Pace + Splits
            if let analytics = runAnalytics {
                RunPaceSection(analytics: analytics)
                RunSplitsSection(analytics: analytics)
            }
        }
    }

    private var activityDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L("details.activityData", "Aktivitätsdaten"), systemImage: "waveform.path.ecg")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if let distance = runDistanceKm {
                    compactDetail("Distanz", String(format: "%.2f km", distance), "point.topleft.down.curvedto.point.bottomright.up")
                }
                compactDetail("Dauer", runDurationText, "timer")
                if let calories = training.activeCalories {
                    compactDetail("Kalorien", "\(Int(calories.rounded())) kcal", "flame.fill")
                }
                if let hr = training.averageHeartRate {
                    compactDetail("Ø Puls", "\(Int(hr.rounded())) bpm", "heart.fill")
                }
                if let elevation = training.elevationGainM {
                    compactDetail("Höhenmeter", "\(Int(elevation.rounded())) m", "mountain.2.fill")
                }
                if let effort = training.perceivedEffort {
                    compactDetail("Anstrengung", "\(effort)/10", "gauge.with.dots.needle.67percent")
                }
            }

            if let note = training.activityNote,
               !note.isEmpty,
               training.healthSourceName == nil,
               training.healthDeviceName == nil {
                Text(note)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 2)
            }

            if training.healthSourceName != nil || training.healthDeviceName != nil || training.isIndoorWorkout != nil {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(t.palette.primary)
                    Text(healthSourceText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func compactDetail(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(t.palette.primary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.07)))
    }

    private var runMetaItems: [DetailMetaChips.Item] {
        var items: [DetailMetaChips.Item] = [
            .init(icon: "calendar", title: dateString)
        ]
        if let range = timeRangeText {
            items.append(.init(icon: "clock", title: range))
        }
        return items
    }

    // MARK: - STRENGTH SECTION

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                DetailMetricCard(
                    title: L("details.duration", "Dauer"),
                    value: formatTime(training.duration),
                    icon: "clock"
                )

                if hasAnyNumericWeight {
                    DetailMetricCard(
                        title: L("details.weight", "Gewicht"),
                        value: totalWeightDisplay,
                        icon: "scalemass"
                    )
                }
            }

            VStack(spacing: 14) {
                ForEach(training.exercises) { ex in
                    DetailExerciseCard(exercise: ex, unit: weightUnit)
                }
            }

            if !displayActivities.isEmpty {
                embeddedActivitiesCard
            }
        }
        .padding(.bottom, 20)
    }

    private var embeddedActivitiesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L("details.embeddedActivities", "Aktivitäten im Training"), systemImage: "figure.outdoor.cycle")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                ForEach(displayActivities) { activity in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Text(activity.emoji ?? "🔥")
                                .font(.title3)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(.white.opacity(0.09)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.title)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(.white)
                                Text(activitySubtitle(activity))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.54))
                            }
                            Spacer(minLength: 0)
                            Button {
                                activityEditTarget = activity
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(t.palette.primary)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }

                        if let note = activity.note, !note.isEmpty {
                            Text(note)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                    .padding(13)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.07)))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var displayActivities: [WorkoutActivityBlock] {
        didLoadActivities ? editedActivities : training.activities
    }

    private func updateStoredActivity(_ updated: WorkoutActivityBlock) {
        if let index = editedActivities.firstIndex(where: { $0.id == updated.id }) {
            editedActivities[index] = updated
        } else {
            editedActivities.append(updated)
        }
        var entry = training
        entry.activities = editedActivities
        entry.updatedAt = Date()
        trainingStore.update(entry: entry)
        activityEditTarget = nil
    }

    private var strengthMetaItems: [DetailMetaChips.Item] {
        var items: [DetailMetaChips.Item] = [
            .init(icon: "calendar", title: dateString),
            .init(
                icon: "figure.strengthtraining.traditional",
                title: "\(training.exercises.count) \(L("details.exercises", "Übungen"))"
            ),
            .init(
                icon: "square.grid.3x3.fill",
                title: "\(totalSets) \(L("details.sets", "Sätze"))"
            )
        ]
        if let range = timeRangeText {
            // Uhr direkt nach dem Datum
            items.insert(.init(icon: "clock", title: range), at: 1)
        }
        return items
    }

    // MARK: - Cardio-Type & Zeitspanne (Helper)

    /// Versucht, aus dem Titel einen Cardio-Typ zu erkennen („Outdoor Walk“ usw.)
    private var cardioTypeText: String {
        if let cardioType = training.cardioType, !cardioType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cardioType
        }
        let raw = training.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()

        if lower.contains("walk") || lower.contains("spazier") {
            return L("run.type.walk", "Outdoor Walk")
        }
        if lower.contains("run") || lower.contains("lauf") || lower.contains("jog") {
            return L("run.type.run", "Outdoor Run")
        }
        if lower.contains("hike") || lower.contains("wander") {
            return L("run.type.hike", "Outdoor Hike")
        }

        // Fallback: nimm einfach den Titel oder einen generischen Text
        return raw.isEmpty ? L("run.type.generic", "Cardio-Workout") : raw
    }

    private var healthSourceText: String {
        var parts: [String] = []
        if let source = training.healthSourceName, !source.isEmpty {
            parts.append(source)
        }
        if let device = training.healthDeviceName, !device.isEmpty {
            parts.append(device)
        }
        if let indoor = training.isIndoorWorkout {
            parts.append(indoor ? L("workout.location.indoor", "Indoor") : L("workout.location.outdoor", "Outdoor"))
        }
        return parts.isEmpty ? "Apple Health" : parts.joined(separator: " · ")
    }

    /// Zeitspanne wie „11:34–11:41“ (optional, falls Dauer > 0)
    private var timeRangeText: String? {
        guard training.duration > 0 else { return nil }
        let end = training.date.addingTimeInterval(training.duration)

        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .none
        f.timeStyle = .short

        return "\(f.string(from: training.date))–\(f.string(from: end))"
    }

    // MARK: - Generic Helpers

    private var dateString: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        return f.string(from: training.date)
    }

    private var totalSets: Int {
        training.exercises.flatMap { $0.sets }.count
    }

    private var hasAnyNumericWeight: Bool {
        training.exercises
            .flatMap { $0.sets }
            .contains { SetFormatter.hasNumericWeight($0.weight) }
    }

    private var totalKg: Double {
        training.exercises
            .flatMap { $0.sets }
            .reduce(0.0) { acc, s in
                let kg = SetFormatter.numericKg(s.weight) ?? 0
                let reps = Double(Int(s.reps.filter("0123456789".contains)) ?? 1)
                return acc + kg * reps
            }
    }

    private var totalWeightDisplay: String {
        let v = weightUnit.fromKilograms(totalKg)
        return "\(formatInt(v)) \(weightUnit.symbol)"
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func formatHMS(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func L(_ key: String, _ fallback: String) -> String {
        let v = appSettings.localized(key)
        return (v == key) ? fallback : v
    }

    private func formatInt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v.rounded()))"
    }

    private func activitySubtitle(_ activity: WorkoutActivityBlock) -> String {
        var parts: [String] = []
        let minutes = Int((activity.duration / 60).rounded())
        if minutes > 0 { parts.append("\(minutes) min") }
        if let distance = activity.distanceKm, distance > 0 {
            parts.append(String(format: "%.2f km", distance))
        }
        if let resistance = activity.resistanceLevel, resistance > 0 {
            parts.append("Level \(Int(resistance.rounded()))")
        }
        if let incline = activity.inclinePercent, incline > 0 {
            parts.append("\(Int(incline.rounded()))%")
        }
        if let watts = activity.averageWatts, watts > 0 {
            parts.append("\(Int(watts.rounded())) W")
        }
        if let calories = activity.activeCalories, calories > 0 {
            parts.append("\(Int(calories.rounded())) kcal")
        }
        if let heartRate = activity.averageHeartRate, heartRate > 0 {
            parts.append("\(Int(heartRate.rounded())) bpm")
        }
        if let elevation = activity.elevationGainM, elevation > 0 {
            parts.append("\(Int(elevation.rounded())) m")
        }
        if let effort = activity.perceivedEffort {
            parts.append(L("details.effort", "Anstrengung") + " \(effort)/10")
        }
        return parts.isEmpty ? L("details.loggedInWorkout", "Im Training erfasst") : parts.joined(separator: " · ")
    }

    /// „… 3.84 km“ → 3.84
    private func extractDistanceKm(from title: String) -> Double? {
        let pattern = #"([0-9]+(?:[.,][0-9]+)?)\s*km"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsRange = NSRange(title.startIndex..<title.endIndex, in: title)
        guard let match = regex.firstMatch(in: title, options: [], range: nsRange),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }
        let numberString = String(title[range])
        let withDot = numberString.replacingOccurrences(of: ",", with: ".")
        return Double(withDot)
    }

    /// Week-Titel wie „Legs – Woche 3“
    private func localizedWeekTitle(_ raw: String, weekFormat: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let pattern = #"(?i)\b(?:week|woche)\s*(\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: trimmed,
                options: [],
                range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
              ),
              match.numberOfRanges >= 2,
              let numRange = Range(match.range(at: 1), in: trimmed),
              let weekNum = Int(trimmed[numRange])
        else {
            return trimmed
        }

        let localizedWeek = String(format: weekFormat, weekNum)
        let fullRange = Range(match.range(at: 0), in: trimmed)!
        let prefix = trimmed[..<fullRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "–—-:•|").union(.whitespaces))

        return prefix.isEmpty ? localizedWeek : "\(prefix) – \(localizedWeek)"
    }
}

// MARK: - Run Analytics

private struct RunAnalytics {
    let distanceKm: Double
    let duration: TimeInterval
    let coordinates: [CLLocationCoordinate2D]

    var avgPaceSecondsPerKm: Double {
        duration / max(distanceKm, 0.01)
    }

    struct Split: Identifiable {
        let id = UUID()
        let index: Int
        let distanceKm: Double
        let paceSecondsPerKm: Double
    }

    /// 1-km-Splits ( letzter Split ggf. kürzer )
    var splits: [Split] {
        guard distanceKm > 0, !coordinates.isEmpty else { return [] }
        let kmCount = max(1, Int(ceil(distanceKm)))
        let fullKm = Double(kmCount - 1)
        let perKm = 1.0

        var result: [Split] = []
        for i in 0..<kmCount {
            let index = i + 1
            let dist: Double
            if i < kmCount - 1 {
                dist = perKm
            } else {
                dist = distanceKm - fullKm
            }
            result.append(
                Split(index: index,
                      distanceKm: max(dist, 0.01),
                      paceSecondsPerKm: avgPaceSecondsPerKm)
            )
        }
        return result
    }

    /// Dummy-Samples für einfachen Pace-Chart (konstant)
    var paceSamplesNormalized: [Double] {
        let count = max(20, Int(distanceKm * 10))
        guard count > 1 else { return [] }
        return Array(repeating: 1.0, count: count)
    }
}

private func paceString(_ secondsPerKm: Double) -> String {
    let m = Int(secondsPerKm) / 60
    let s = Int(secondsPerKm) % 60
    return String(format: "%d:%02d", m, s)
}

// MARK: - Run Summary Grid

private struct RunSummaryGrid: View {
    let analytics: RunAnalytics
    let durationText: String
    let cardioType: String
    let activeCalories: Double?
    let averageHeartRate: Double?
    let elevationGainM: Double?
    let perceivedEffort: Int?
    @EnvironmentObject var appSettings: AppSettings

    private func L(_ key: String, _ fallback: String) -> String {
        let v = appSettings.localized(key)
        return (v == key) ? fallback : v
    }

    private var distanceText: String {
        String(format: "%.2f km", analytics.distanceKm)
    }

    private var avgPaceText: String {
        "\(paceString(analytics.avgPaceSecondsPerKm)) min/km"
    }

    private var speedText: String {
        guard analytics.duration > 0 else { return "–" }
        let kmh = analytics.distanceKm / (analytics.duration / 3600.0)
        return String(format: "%.1f km/h", kmh)
    }

    private var secondaryMetric: (title: String, value: String) {
        let lower = cardioType.lowercased()
        if lower.contains("rad") || lower.contains("cycl") || lower.contains("bike") {
            return (L("run.speed.avg", "Ø Speed"), speedText)
        }
        if lower.contains("swim") || lower.contains("schwimm") {
            return (L("run.pace.avg", "Ø Pace"), "\(paceString(analytics.avgPaceSecondsPerKm / 10.0)) /100m")
        }
        return (L("run.pace.avg", "Ø Pace"), avgPaceText)
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            RunMetricCard(icon: "clock", title: L("details.duration", "Dauer"), value: durationText)
            RunMetricCard(icon: "ruler", title: L("run.distance", "Distanz"), value: distanceText)
            RunMetricCard(icon: "speedometer", title: secondaryMetric.title, value: secondaryMetric.value)
            if let activeCalories {
                RunMetricCard(icon: "flame.fill", title: L("run.calories", "Kalorien"), value: "\(Int(activeCalories.rounded())) kcal")
            }
            if let averageHeartRate {
                RunMetricCard(icon: "heart.fill", title: "Ø Puls", value: "\(Int(averageHeartRate.rounded())) bpm")
            }
            if let elevationGainM {
                RunMetricCard(icon: "mountain.2.fill", title: "Höhe", value: "\(Int(elevationGainM.rounded())) m")
            }
            if let perceivedEffort {
                RunMetricCard(icon: "gauge.with.dots.needle.67percent", title: L("details.effort", "Anstrengung"), value: "\(perceivedEffort)/10")
            }
        }
        .padding(.top, 8)
    }
}

private struct RunMetricCard: View {
    let icon: String
    let title: String
    let value: String

    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        HStack(spacing: 12) {
            // Icon on the left
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            // VALUE above label (inverted from before)
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.52))
            }
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Pace Section

private struct RunPaceSection: View {
    let analytics: RunAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pace")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)

            Text("Average \(paceString(analytics.avgPaceSecondsPerKm)) min/km")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.56))

            PaceAreaChart(values: analytics.paceSamplesNormalized)
                .frame(height: 130)
        }
    }
}

private struct PaceAreaChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = max(values.count, 2)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                if !values.isEmpty {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        for (idx, v) in values.enumerated() {
                            let x = CGFloat(idx) / CGFloat(count - 1) * w
                            let y = h - CGFloat(v) * h * 0.8
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.closeSubpath()
                    }
                    .fill(Color.blue.opacity(0.25))

                    Path { path in
                        for (idx, v) in values.enumerated() {
                            let x = CGFloat(idx) / CGFloat(count - 1) * w
                            let y = h - CGFloat(v) * h * 0.8
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Splits Section

private struct RunSplitsSection: View {
    let analytics: RunAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Splits")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)

            if analytics.splits.isEmpty {
                Text("Keine Splits verfügbar")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.52))
            } else {
                let slowest =
                    analytics.splits.map { $0.paceSecondsPerKm }.max()
                    ?? analytics.avgPaceSecondsPerKm

                VStack(spacing: 8) {
                    ForEach(analytics.splits) { split in
                        RunSplitRow(split: split, slowestPace: slowest)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
    }
}

private struct RunSplitRow: View {
    let split: RunAnalytics.Split
    let slowestPace: Double

    var body: some View {
        HStack(spacing: 8) {
            Text("\(split.index)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 22, alignment: .leading)

            Text(String(format: "%.2f km", split.distanceKm))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 60, alignment: .leading)

            Text(paceString(split.paceSecondsPerKm))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 56, alignment: .leading)

            GeometryReader { geo in
                let ratio = slowestPace > 0 ? split.paceSecondsPerKm / slowestPace : 1
                let barWidth = max(geo.size.width * CGFloat(ratio), 6)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.blue)
                    .frame(width: barWidth, height: 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Run Route Map

private struct RunRouteMap: View {
    let route: [CLLocationCoordinate2D]

    @State private var region: MKCoordinateRegion

    init(route: [CLLocationCoordinate2D]) {
        self.route = route
        _region = State(initialValue: RunRouteMap.makeRegion(for: route))
    }

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                Map(initialPosition: .region(region)) {
                    if !route.isEmpty {
                        MapPolyline(coordinates: route)
                            .stroke(.blue, lineWidth: 4)
                    }
                }
            } else {
                Map(coordinateRegion: $region)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private static func makeRegion(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coords.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 50.0, longitude: 8.0),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let extra = 1.3
        let latDelta = max((maxLat - minLat) * extra, 0.005)
        let lonDelta = max((maxLon - minLon) * extra, 0.005)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
}

// MARK: - Polyline Helpers

func decodePolyline(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
    var coordinates: [CLLocationCoordinate2D] = []
    let data = Array(encodedPolyline.utf8)
    let length = data.count
    var index = 0

    var lat: Int32 = 0
    var lon: Int32 = 0

    while index < length {
        var b: UInt8
        var shift: UInt32 = 0
        var result: Int32 = 0

        repeat {
            b = data[index] - 63
            index += 1
            result |= Int32(b & 0x1F) << shift
            shift += 5
        } while b >= 0x20 && index < length

        let dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1)
        lat &+= dlat

        shift = 0
        result = 0

        repeat {
            b = data[index] - 63
            index += 1
            result |= Int32(b & 0x1F) << shift
            shift += 5
        } while b >= 0x20 && index < length

        let dlon = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1)
        lon &+= dlon

        let finalLat = Double(lat) * 1e-5
        let finalLon = Double(lon) * 1e-5
        coordinates.append(
            CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon)
        )
    }

    return coordinates
}

extension Array where Element == CLLocationCoordinate2D {
    func encodePolyline() -> String {
        guard !isEmpty else { return "" }

        var encoded = ""
        var lastLat: Int32 = 0
        var lastLon: Int32 = 0

        for coord in self {
            let lat = Int32(round(coord.latitude * 1e5))
            let lon = Int32(round(coord.longitude * 1e5))

            let dlat = lat - lastLat
            let dlon = lon - lastLon

            encodeComponent(dlat, into: &encoded)
            encodeComponent(dlon, into: &encoded)

            lastLat = lat
            lastLon = lon
        }

        return encoded
    }

    private func encodeComponent(_ value: Int32, into output: inout String) {
        var v = value << 1
        if value < 0 { v = ~v }

        var chunk = v
        while chunk >= 0x20 {
            let c = (0x20 | (chunk & 0x1F)) + 63
            output.append(Character(UnicodeScalar(Int(c))!))
            chunk >>= 5
        }
        let c = chunk + 63
        output.append(Character(UnicodeScalar(Int(c))!))
    }
}

// MARK: - Reusable Components (wie gehabt)

struct DetailMetaChips: View {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        init(icon: String, title: String) {
            self.icon = icon
            self.title = title
        }
    }

    let items: [Item]

    private let cols: [GridItem] = [
        GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                DetailMetaChip(icon: item.icon, title: item.title)
            }
        }
    }
}

struct DetailMetaChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).imageScale(.medium)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(.white.opacity(0.78))
        .background(Capsule().fill(Color.white.opacity(0.09)))
        .overlay(
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct DetailMetricCard: View {
    let title: String
    let value: String
    let icon: String

    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(appSettings.accentColor)
                Text(title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.52))
            }
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

struct DetailExerciseCard: View {
    let exercise: Exercise
    let unit: WeightUnit

    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appSettings: AppSettings

    private var headlineChip: String? {
        guard let first = exercise.sets.first else { return nil }
        return displaySet(weight: first.weight, reps: first.reps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Spacer()
                if let chip = headlineChip {
                    Text(chip)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white.opacity(0.78))
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { idx, set in
                    DetailSetRow(
                        index: idx + 1,
                        text: displaySet(weight: set.weight, reps: set.reps),
                        done: set.isCompleted
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func displaySet(weight: String, reps: String) -> String {
        if let kg = SetFormatter.numericKg(weight) {
            let v = unit.fromKilograms(kg)
            let num = formatInt(v)
            let sym = unit.symbol
            let repsClean = reps.trimmingCharacters(in: .whitespacesAndNewlines)
            if repsClean.isEmpty {
                return "\(num) \(sym)"
            } else {
                return "\(num) \(sym) × \(repsClean)"
            }
        } else {
            let w = weight.trimmingCharacters(in: .whitespacesAndNewlines)
            let r = reps.trimmingCharacters(in: .whitespacesAndNewlines)
            if w.isEmpty { return r }
            if r.isEmpty { return w }
            return "\(w) × \(r)"
        }
    }

    private func formatInt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v.rounded()))"
    }
}

private struct TrainingActivityEditSheet: View {
    let activity: WorkoutActivityBlock
    let isDE: Bool
    let accent: Color
    var onSave: (WorkoutActivityBlock) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var minutes: String
    @State private var distance: String
    @State private var resistance: String
    @State private var incline: String
    @State private var watts: String
    @State private var calories: String
    @State private var heartRate: String
    @State private var elevation: String
    @State private var effort: Int
    @State private var note: String

    init(activity: WorkoutActivityBlock, isDE: Bool, accent: Color, onSave: @escaping (WorkoutActivityBlock) -> Void) {
        self.activity = activity
        self.isDE = isDE
        self.accent = accent
        self.onSave = onSave
        _title = State(initialValue: activity.title)
        _minutes = State(initialValue: activity.duration > 0 ? "\(Int((activity.duration / 60).rounded()))" : "")
        _distance = State(initialValue: Self.text(activity.distanceKm))
        _resistance = State(initialValue: Self.text(activity.resistanceLevel))
        _incline = State(initialValue: Self.text(activity.inclinePercent))
        _watts = State(initialValue: Self.text(activity.averageWatts))
        _calories = State(initialValue: Self.text(activity.activeCalories))
        _heartRate = State(initialValue: Self.text(activity.averageHeartRate))
        _elevation = State(initialValue: Self.text(activity.elevationGainM))
        _effort = State(initialValue: activity.perceivedEffort ?? 5)
        _note = State(initialValue: activity.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(colors: [accent.opacity(0.32), .clear], center: .topLeading, startRadius: 24, endRadius: 420)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(isDE ? "Aktivität bearbeiten" : "Edit activity")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        editField(isDE ? "Name" : "Name", text: $title, icon: "text.cursor")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            editField(isDE ? "Minuten" : "Minutes", text: $minutes, icon: "timer", keyboard: .decimalPad)
                            editField(isDE ? "Distanz km" : "Distance km", text: $distance, icon: "point.topleft.down.curvedto.point.bottomright.up", keyboard: .decimalPad)
                            editField("Level", text: $resistance, icon: "dial.medium", keyboard: .decimalPad)
                            editField(isDE ? "Steigung %" : "Incline %", text: $incline, icon: "angle", keyboard: .decimalPad)
                            editField("Watt", text: $watts, icon: "bolt.fill", keyboard: .decimalPad)
                            editField("kcal", text: $calories, icon: "flame.fill", keyboard: .decimalPad)
                            editField(isDE ? "Ø Puls" : "Avg HR", text: $heartRate, icon: "heart.fill", keyboard: .decimalPad)
                            editField(isDE ? "Höhenmeter" : "Elevation", text: $elevation, icon: "mountain.2.fill", keyboard: .decimalPad)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(isDE ? "Anstrengung \(effort)/10" : "Effort \(effort)/10")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.58))
                            Slider(value: Binding(get: { Double(effort) }, set: { effort = Int($0.rounded()) }), in: 1...10, step: 1)
                                .tint(accent)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))

                        editField(isDE ? "Notiz" : "Note", text: $note, icon: "note.text")

                        Button {
                            onSave(makeUpdatedActivity())
                            dismiss()
                        } label: {
                            Label(isDE ? "Änderungen speichern" : "Save changes", systemImage: "checkmark.circle.fill")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(.black)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(accent))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                }
            }
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDE ? "Abbrechen" : "Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func editField(_ label: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 20)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.sentences)
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func makeUpdatedActivity() -> WorkoutActivityBlock {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkoutActivityBlock(
            id: activity.id,
            title: trimmedTitle.isEmpty ? activity.title : trimmedTitle,
            kindRaw: activity.kindRaw,
            emoji: activity.emoji,
            duration: max(0, (parseDecimal(minutes) ?? 0) * 60),
            distanceKm: parseDecimal(distance),
            resistanceLevel: parseDecimal(resistance),
            inclinePercent: parseDecimal(incline),
            averageWatts: parseDecimal(watts),
            activeCalories: parseDecimal(calories),
            averageHeartRate: parseDecimal(heartRate),
            elevationGainM: parseDecimal(elevation),
            perceivedEffort: effort,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
    }

    private func parseDecimal(_ raw: String) -> Double? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private static func text(_ value: Double?) -> String {
        guard let value, value > 0 else { return "" }
        if value.rounded() == value { return "\(Int(value))" }
        return String(format: "%.2f", value)
    }
}

struct DetailSetRow: View {
    @EnvironmentObject var appSettings: AppSettings

    let index: Int
    let text: String
    let done: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(L("details.set", "Satz")) \(index):")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.52))

            Spacer()

            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.08)))

            if done {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.green)
                    .imageScale(.medium)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func L(_ key: String, _ fallback: String) -> String {
        let v = appSettings.localized(key)
        return (v == key) ? fallback : v
    }
}
