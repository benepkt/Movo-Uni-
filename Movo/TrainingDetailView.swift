import SwiftUI
import MapKit
import CoreLocation

// MARK: - Training Detail

struct TrainingDetailView: View {
    let training: TrainingEntry
    @EnvironmentObject var appSettings: AppSettings

    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg

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
        // falls du später ein echtes Feld hast -> hier umstellen
        extractDistanceKm(from: training.title)
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
        ScrollView {
            VStack(spacing: 24) {
                if isWeek {
                    weekSection
                } else if isRun {
                    runSection
                } else {
                    strengthSection
                }
            }
            .padding(.vertical)
            .padding(.horizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(appSettings.localized("details.title"))
    }

    // MARK: - WEEK SECTION

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(localizedWeekTitle(training.title,
                                        weekFormat: appSettings.localized("week.number")))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(appSettings.accentColor)

                DetailMetaChips(items: [
                    .init(icon: "calendar", title: dateString),
                    .init(icon: "figure.strengthtraining.traditional",
                          title: "\(training.exercises.count) \(L("details.exercises", "Übungen"))"),
                    .init(icon: "square.grid.3x3.fill",
                          title: "3 \(L("rounds", "Runden"))")
                ])
            }

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
                            Text(ex.name).font(.headline)
                            Spacer()
                            Text("35s × 3 \(L("rounds.short", "Rdn"))")
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color(.systemBackground)))
                                .overlay(
                                    Capsule().stroke(Color(.separator), lineWidth: 0.5)
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
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
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
            // Header + Meta
            VStack(alignment: .leading, spacing: 10) {
                // z.B. „Outdoor Walk“
                Text(cardioTypeText)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(appSettings.accentColor)

                DetailMetaChips(items: runMetaItems)
            }

            // 4 Summary-Karten im 2×2 Grid
            if let analytics = runAnalytics {
                RunSummaryGrid(analytics: analytics, durationText: runDurationText)
            } else {
                HStack(spacing: 12) {
                    DetailMetricCard(
                        title: L("details.duration", "Dauer"),
                        value: runDurationText,
                        icon: "clock"
                    )
                }
            }

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
            VStack(alignment: .leading, spacing: 10) {
                Text(training.title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(appSettings.accentColor)

                DetailMetaChips(items: strengthMetaItems)
            }

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
            .padding(.bottom, 20)
        }
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
        guard distanceKm > 0 else { return [] }
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

    private var caloriesText: String {
        let kcal = Int(analytics.distanceKm * 60.0)   // grober Schätzer
        return "\(kcal) kcal"
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            RunMetricCard(
                icon: "clock",
                title: L("details.duration", "Dauer"),
                value: durationText
            )

            RunMetricCard(
                icon: "ruler",
                title: L("run.distance", "Distanz"),
                value: distanceText
            )

            RunMetricCard(
                icon: "speedometer",
                title: L("run.pace.avg", "Ø Pace"),
                value: avgPaceText
            )

            RunMetricCard(
                icon: "flame.fill",
                title: L("run.calories", "Kalorien"),
                value: caloriesText
            )
        }
        .padding(.top, 8)
    }
}

private struct RunMetricCard: View {
    let icon: String
    let title: String
    let value: String

    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .imageScale(.medium)
                    .foregroundColor(appSettings.accentColor)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(appSettings.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(
                    color: .black.opacity(scheme == .dark ? 0.35 : 0.08),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        )
    }
}

// MARK: - Pace Section

private struct RunPaceSection: View {
    let analytics: RunAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pace")
                .font(.headline)

            Text("Average \(paceString(analytics.avgPaceSecondsPerKm)) min/km")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                    .fill(Color(.secondarySystemBackground))

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
                .font(.headline)

            if analytics.splits.isEmpty {
                Text("Keine Splits verfügbar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                        .fill(Color(.secondarySystemBackground))
                )
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
                .frame(width: 22, alignment: .leading)

            Text(String(format: "%.2f km", split.distanceKm))
                .font(.footnote)
                .frame(width: 60, alignment: .leading)

            Text(paceString(split.paceSecondsPerKm))
                .font(.footnote.monospacedDigit())
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
        .background(Capsule().fill(Color(.secondarySystemBackground)))
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1)
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundColor(appSettings.accentColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(
                    color: .black.opacity(scheme == .dark ? 0.25 : 0.08),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        )
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
                    .font(.headline)
                Spacer()
                if let chip = headlineChip {
                    Text(chip)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(.systemBackground)))
                        .overlay(
                            Capsule().stroke(Color(.separator), lineWidth: 0.5)
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
                .fill(Color(.secondarySystemBackground))
                .shadow(
                    color: .black.opacity(scheme == .dark ? 0.25 : 0.06),
                    radius: 8,
                    x: 0,
                    y: 3
                )
        )
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

struct DetailSetRow: View {
    @EnvironmentObject var appSettings: AppSettings

    let index: Int
    let text: String
    let done: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(L("details.set", "Satz")) \(index):")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text(text)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(.systemBackground)))

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
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private func L(_ key: String, _ fallback: String) -> String {
        let v = appSettings.localized(key)
        return (v == key) ? fallback : v
    }
}
