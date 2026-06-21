import SwiftUI

struct ActivityHeatmap: View {
    let entries: [TrainingEntry]
    var onOpenYear: (() -> Void)? = nil

    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    // Heutiges Datum als State, damit wir auf Tages-/Jahreswechsel reagieren können
    @State private var today: Date = Calendar.current.startOfDay(for: Date())

    // Layout-Konstanten (müssen mit Grid unten übereinstimmen)
    private let cellSize: CGFloat = 10
    private let columnSpacing: CGFloat = 3
    private let rowSpacing: CGFloat = 3

    // Datenstruktur für das Grid
    private struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
        let level: Int // 0..4 für Farbintensität
    }

    // MARK: - Jahresgrenzen (aktuelles Kalenderjahr, auf Wochen ausgerichtet)

    private var yearStartAlignedToMonday: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: today)
        let jan1 = cal.date(from: DateComponents(year: comps.year, month: 1, day: 1))!
        if let weekStart = cal.dateInterval(of: .weekOfYear, for: jan1)?.start {
            return weekStart
        }
        return cal.startOfDay(for: jan1)
    }

    private var yearEndAlignedToSunday: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: today)
        let dec31 = cal.date(from: DateComponents(year: comps.year, month: 12, day: 31))!
        let weekday = cal.component(.weekday, from: dec31) // 1=So, 2=Mo, ...
        let daysUntilSunday = (8 - weekday) % 7
        return cal.date(byAdding: .day, value: daysUntilSunday, to: cal.startOfDay(for: dec31))!
    }

    private var yearJan1: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: today)
        return cal.date(from: DateComponents(year: comps.year, month: 1, day: 1))!
    }

    private var yearDec31: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: today)
        return cal.date(from: DateComponents(year: comps.year, month: 12, day: 31))!
    }

    // MARK: - Grid-Berechnung (aktuelles Jahr)

    private var gridData: [[DayData]] {
        let cal = Calendar.current
        let startDate = yearStartAlignedToMonday
        let endDate = yearEndAlignedToSunday

        // Mapping Datum -> Count (nur dieses Jahr inkl. überstehende Wochen, aber gezählt wird nur innerhalb [Jan1..Dec31])
        var counts: [Date: Int] = [:]
        for entry in entries {
            let d = cal.startOfDay(for: entry.date)
            if d >= startDate && d <= endDate {
                if d >= yearJan1 && d <= yearDec31 {
                    counts[d, default: 0] += 1
                }
            }
        }

        var weeks: [[DayData]] = []
        var currentWeek: [DayData] = []

        var currentDate = startDate
        while currentDate <= endDate {
            let c = counts[currentDate] ?? 0
            let level = min(4, c > 0 ? c + 1 : 0)

            currentWeek.append(DayData(date: currentDate, count: c, level: level))

            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }

            currentDate = cal.date(byAdding: .day, value: 1, to: currentDate)!
        }

        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }

        return weeks
    }

    // MARK: - Monatslabels (dynamisch je Spalten-Span)

    private var monthHeaderSpans: [(name: String, columns: Int)] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        fmt.locale = Locale(identifier: code)
        fmt.dateFormat = "MMM"

        var perColumnMonth: [Int] = []
        for week in gridData {
            let inYearDays = week.filter { $0.date >= yearJan1 && $0.date <= yearDec31 }
            if let firstInYear = inYearDays.first {
                perColumnMonth.append(cal.component(.month, from: firstInYear.date))
            } else {
                if let first = week.first?.date {
                    if first < yearJan1 {
                        perColumnMonth.append(1)   // Januar
                    } else {
                        perColumnMonth.append(12)  // Dezember
                    }
                }
            }
        }

        var spans: [(name: String, columns: Int)] = []
        var idx = 0
        while idx < perColumnMonth.count {
            let month = perColumnMonth[idx]
            var run = 1
            var j = idx + 1
            while j < perColumnMonth.count && perColumnMonth[j] == month {
                run += 1
                j += 1
            }
            let year = Calendar.current.component(.year, from: today)
            let labelDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: 15))!
            spans.append((fmt.string(from: labelDate), run))
            idx = j
        }
        return spans
    }

    // MARK: - Index der Spalte, in der der aktuelle Monat beginnt

    private var currentMonthStartColumnIndex: Int? {
        let cal = Calendar.current
        let year = cal.component(.year, from: today)
        guard let monthStart = cal.date(from: DateComponents(year: year, month: cal.component(.month, from: today), day: 1)) else {
            return nil
        }
        for (wIndex, week) in gridData.enumerated() {
            if week.contains(where: { $0.date >= monthStart }) {
                return wIndex
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appSettings.localized("statistics.activity"))
                        .font(.headline)

                    let workoutCount = entries.filter {
                        let d = Calendar.current.startOfDay(for: $0.date)
                        return d >= yearJan1 && d <= yearDec31
                    }.count

                    Text(
                        String(
                            format: appSettings.localized("statistics.activity.subtitle"),
                            workoutCount
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Grid
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Dynamische Monats-Header entsprechend der Spaltenanzahl
                        HStack(spacing: 0) {
                            ForEach(Array(monthHeaderSpans.enumerated()), id: \.offset) { _, span in
                                Text(span.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(
                                        width: CGFloat(span.columns) * (cellSize + columnSpacing),
                                        alignment: .leading
                                    )
                            }
                        }

                        // Heatmap Cells (Spalten = Wochen)
                        HStack(spacing: columnSpacing) {
                            ForEach(gridData.indices, id: \.self) { wIndex in
                                let week = gridData[wIndex]
                                VStack(spacing: rowSpacing) {
                                    ForEach(week) { day in
                                        cell(day, size: cellSize)
                                    }
                                }
                                .id(wIndex)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onOpenYear?() }
                    }
                    .padding(.bottom, 8)
                }
                .onAppear {
                    if let idx = currentMonthStartColumnIndex {
                        proxy.scrollTo(idx, anchor: .leading)
                    } else if let lastIndex = gridData.indices.last {
                        proxy.scrollTo(lastIndex, anchor: .trailing)
                    }
                }
                .onChange(of: today) { _ in
                    if let idx = currentMonthStartColumnIndex {
                        withAnimation { proxy.scrollTo(idx, anchor: .leading) }
                    }
                }
            }

            // Legende
            HStack(spacing: 4) {
                Text(appSettings.localized("common.less"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(forLevel: i))
                        .frame(width: 10, height: 10)
                }

                Text(appSettings.localized("common.more"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = Calendar.current.startOfDay(for: Date())
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                let start = Calendar.current.startOfDay(for: Date())
                if start != today { today = start }
            }
        }
    }

    private func cell(_ day: DayData, size: CGFloat = 10) -> some View {
        let inYear = day.date >= yearJan1 && day.date <= yearDec31
        let fill: Color = inYear
            ? color(for: day.count)
            : Color(.systemGray4).opacity(0.4) // überstehende Tage dezent, nicht „weiß“

        return RoundedRectangle(cornerRadius: 2)
            .fill(fill)
            .frame(width: size, height: size)
    }

    private func color(for count: Int) -> Color {
        if count == 0 { return Color(.systemGray5) }
        let intensity = min(Double(count) * 0.3 + 0.2, 1.0)
        return t.palette.primary.opacity(intensity)
    }

    private func color(forLevel level: Int) -> Color {
        if level == 0 { return Color(.systemGray5) }
        let intensity = min(max(0.0, Double(level) * 0.2 + 0.2), 1.0)
        return t.palette.primary.opacity(intensity)
    }
}
