import SwiftUI
import Charts
import WidgetKit
import Combine

// MARK: - Zeitraum-Filter
enum TimeFilter: String, CaseIterable { case week = "week", month = "month", year = "year", all = "all" }

struct StatisticsView: View {
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg

    @State private var showProfile = false
    @AppStorage("profile.imageData") private var profileImageData: Data?

    @State private var selectedFilter: TimeFilter = .month
    @State private var selectedExercise: String? = nil

    // Paywall Overlay State
    @State private var showPaywall = false
    @State private var dim: CGFloat = 0          // 0…1
    @State private var blur: CGFloat = 0         // leichter Hintergrund-Blur

    // Formatter
    private var appLocale: Locale {
        Locale(identifier: (appSettings.language == "de") ? "de_DE" : "en_US")
    }
    private var nfInt: NumberFormatter {
        let f = NumberFormatter()
        f.locale = appLocale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }
    private var dfMedium: DateFormatter {
        let df = DateFormatter()
        df.locale = appLocale
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }

    // Daten
    private var filteredHistory: [TrainingEntry] {
        let now = Date()
        let cal = Calendar.current
        let start: Date? = {
            switch selectedFilter {
            case .week:  return cal.date(byAdding: .day, value: -7, to: now)
            case .month: return cal.date(byAdding: .month, value: -1, to: now)
            case .year:  return cal.date(byAdding: .year, value: -1, to: now)
            case .all:   return nil
            }
        }()
        guard let start else { return trainingStore.history }
        let startOfDay = cal.startOfDay(for: start)
        return trainingStore.history.filter { $0.date >= startOfDay }
    }

    private var durationByDay: [(date: Date, minutes: Double)] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredHistory) { cal.startOfDay(for: $0.date) }
        return grouped
            .map { ($0.key, $0.value.reduce(0.0) { $0 + ($1.duration / 60.0) }) }
            .sorted { $0.0 < $1.0 }
    }

    private var exerciseNames: [String] {
        Array(Set(filteredHistory.flatMap { $0.exercises.map(\.name) }))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    // KPIs
    private var totalMinutes: Int {
        let totalSeconds: Double = filteredHistory.reduce(0.0) { $0 + $1.duration }
        return Int((totalSeconds / 60.0).rounded())
    }

    private var totalVolumeKgDouble: Double {
        filteredHistory
            .flatMap { $0.exercises.flatMap(\.sets) }
            .reduce(0.0) { $0 + parseKg($1.weight) * Double(parseInt($1.reps)) }
    }

    private var bestSession: TrainingEntry? {
        filteredHistory.max(by: { entryTotalKg($0) < entryTotalKg($1) })
    }

    private var weeklyWorkoutCounts: [(weekStart: Date, count: Int)] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredHistory) {
            cal.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date
        }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    private var exerciseVolumeTop5Kg: [(name: String, volumeKg: Double)] {
        let map = filteredHistory
            .flatMap { $0.exercises }
            .reduce(into: [String: Double]()) { acc, ex in
                let vKg = ex.sets.reduce(0.0) { $0 + parseKg($1.weight) * Double(parseInt($1.reps)) }
                let name = ex.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                acc[name, default: 0] += vKg
            }
        return map
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { ($0.0, $0.1) }
    }

    // MARK: - Muscle Map (immer: letzte 7 Tage)

    private var historyThisWeek: [TrainingEntry] {
        let now = Date()
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: now)!   // letzte 7 Tage
        let startOfDay = cal.startOfDay(for: start)
        return trainingStore.history.filter { $0.date >= startOfDay }
    }

    private var muscleLoadThisWeek: [MuscleRegion: Double] {
        var acc: [MuscleRegion: Double] = [:]

        for entry in historyThisWeek {
            for ex in entry.exercises {
                let name = ex.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let volumeKg = ex.sets.reduce(0.0) { sum, s in
                    sum + parseKg(s.weight) * Double(parseInt(s.reps))
                }
                for r in regions(forExerciseName: name) {
                    acc[r, default: 0] += volumeKg
                }
            }
        }
        return acc
    }

    // MARK: - NEW: Muscle Load (für die Muscle Map)
    private var muscleLoad: [MuscleRegion: Double] {
        var acc: [MuscleRegion: Double] = [:]

        for entry in filteredHistory {
            for ex in entry.exercises {
                let name = ex.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let volumeKg = ex.sets.reduce(0.0) { sum, s in
                    sum + parseKg(s.weight) * Double(parseInt(s.reps))
                }

                for r in regions(forExerciseName: name) {
                    acc[r, default: 0] += volumeKg
                }
            }
        }
        return acc
    }

    /// Grober Mapper (Startpunkt). Später ideal: über echte Exercise-Metadaten statt Name-Contains.
    private func regions(forExerciseName n: String) -> [MuscleRegion] {
        if n.contains("bench") || n.contains("bank") || n.contains("chest") { return [.chest, .triceps, .shoulders] }
        if n.contains("overhead") || n.contains("military") || n.contains("shoulder") { return [.shoulders, .triceps] }
        if n.contains("curl") || n.contains("bizeps") || n.contains("biceps") { return [.biceps, .forearms] }
        if n.contains("triceps") || n.contains("pushdown") || n.contains("dip") { return [.triceps] }
        if n.contains("pullup") || n.contains("chin") || n.contains("lat") { return [.lats, .biceps] }
        if n.contains("row") || n.contains("rudern") { return [.lats, .traps, .biceps] }
        if n.contains("deadlift") || n.contains("kreuzheben") { return [.lowerBack, .glutes, .hamstrings] }
        if n.contains("squat") || n.contains("kniebeuge") { return [.quads, .glutes, .hamstrings] }
        if n.contains("leg extension") || n.contains("beinstrecker") { return [.quads] }
        if n.contains("leg curl") || n.contains("beinbeuger") { return [.hamstrings] }
        if n.contains("calf") || n.contains("waden") { return [.calves, .calvesBack] }
        if n.contains("abs") || n.contains("bauch") || n.contains("crunch") || n.contains("plank") { return [.abs] }
        return []
    }

    // MARK: - Body

    var body: some View {
        let unit = weightUnit
        let nf = nfInt
        let isPremium = purchaseManager.hasUnlockedStatistics

        return NavigationStack {
            ZStack {
                // MAIN
                ScrollView {
                    VStack(spacing: 24) {
                        // Zeitraum
                        Picker(appSettings.localized("statistics.period"), selection: $selectedFilter) {
                            ForEach(TimeFilter.allCases, id: \.self) { f in
                                Text(appSettings.localized("statistics.period.\(f.rawValue)"))
                                    .tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // KPI: Trainings & Zeit – beide KOSTENLOS
                        HStack(spacing: 16) {
                            let workoutsStr = nf.string(from: NSNumber(value: filteredHistory.count)) ?? "\(filteredHistory.count)"
                            let minutesStr  = nf.string(from: NSNumber(value: totalMinutes)) ?? "\(totalMinutes)"
                            let minutesAbbrev = "min"

                            MetricCardValueSmall(
                                title: appSettings.localized("statistics.trainings"),
                                value: workoutsStr,
                                icon: "figure.strengthtraining.traditional"
                            )
                            .frame(maxWidth: .infinity)

                            MetricCardValueSmall(
                                title: appSettings.localized("statistics.time"),
                                value: "\(minutesStr) \(minutesAbbrev)",
                                icon: "clock"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .id(selectedFilter)
                        .animation(currentAnimation, value: selectedFilter)
                        .padding(.horizontal)

                        // Gesamtgewicht – KOSTENLOS und jetzt direkt oben
                        let curVal  = unit.fromKilograms(totalVolumeKgDouble)
                        let curStr  = nf.string(from: NSNumber(value: Int(round(curVal)))) ?? String(Int(round(curVal)))
                        MetricCardFeaturedValue(
                            title: appSettings.localized("statistics.total.weight"),
                            value: "\(curStr) \(unit.symbol)",
                            icon: "scalemass"
                        )
                        .padding(.horizontal)

                        MuscleMapSummary(load: muscleLoadThisWeek)
                            .padding(.horizontal)

                        // Aktivitätsverlauf – KOSTENLOS
                        ActivityHeatmap(entries: trainingStore.history)
                            .padding(.horizontal)

                        // Premium-Teaser direkt darunter
                        if !isPremium {
                            PremiumStatsTeaser {
                                openPaywall()
                            }
                            .padding(.horizontal)
                        }

                        // Bestes Training – kostenlos (falls vorhanden)
                        if let best = bestSession {
                            ChallengeStyleSectionCard(
                                title: appSettings.localized("statistics.best.training"),
                                icon: "trophy.fill",
                                gradient: [.yellow.opacity(0.35), .orange.opacity(0.5)]
                            ) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(prettifiedTitle(best.title))
                                        .font(.headline)
                                    Text(dfMedium.string(from: best.date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    let bestKg = entryTotalKg(best)
                                    let bestMinutes = Int((best.duration / 60.0).rounded())
                                    let bestMinutesStr = nf.string(from: NSNumber(value: bestMinutes)) ?? "\(bestMinutes)"
                                    Text("\(fmtUnit(bestKg, unit: unit, nf: nf)) • \(bestMinutesStr) min")
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal)
                        }

                        // ======= Ab hier Premium-Bereich =======

                        // Trainingsdauer je Tag
                        ChallengeStyleSectionCard(
                            title: appSettings.localized("statistics.duration.chart"),
                            icon: "chart.bar.fill",
                            gradient: [.blue.opacity(0.25), .purple.opacity(0.25)],
                            locked: !isPremium
                        ) {
                            if isPremium {
                                if #available(iOS 16.0, *) {
                                    if durationByDay.isEmpty {
                                        Text(appSettings.localized("statistics.empty.range"))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Chart {
                                            ForEach(durationByDay, id: \.date) { b in
                                                BarMark(
                                                    x: .value(appSettings.localized("statistics.date"), b.date, unit: .day),
                                                    y: .value(appSettings.localized("statistics.minutes"), b.minutes),
                                                    width: .fixed(12)
                                                )
                                            }
                                        }
                                        .frame(height: 200)
                                        .chartYAxis { AxisMarks(position: .leading) }
                                        .chartYAxisLabel(position: .leading) {
                                            Text(appSettings.localized("statistics.minutes"))
                                        }
                                        .chartXAxis { dayAxisMarks() }
                                        .applyPaddedDomain(durationByDay.map(\.date))
                                    }
                                } else {
                                    Text(appSettings.localized("common.ios16.required"))
                                }
                            } else {
                                LockedSectionMessage(
                                    text: "Mit Movo Pro siehst du hier deine Trainingsdauer pro Tag."
                                )
                            }
                        }
                        .padding(.horizontal)
                        .onTapGesture { if !isPremium { openPaywall() } }

                        // Workouts pro Woche
                        ChallengeStyleSectionCard(
                            title: appSettings.localized("statistics.workouts.per.week"),
                            icon: "calendar",
                            gradient: [.teal.opacity(0.25), .blue.opacity(0.25)],
                            locked: !isPremium
                        ) {
                            if isPremium {
                                if #available(iOS 16.0, *) {
                                    if weeklyWorkoutCounts.isEmpty {
                                        Text(appSettings.localized("statistics.empty.range"))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Chart {
                                            ForEach(weeklyWorkoutCounts, id: \.weekStart) { w in
                                                BarMark(
                                                    x: .value(appSettings.localized("statistics.week"), w.weekStart),
                                                    y: .value(appSettings.localized("statistics.trainings"), w.count)
                                                )
                                            }
                                        }
                                        .frame(height: 200)
                                        .chartXAxis {
                                            switch selectedFilter {
                                            case .week, .month:
                                                AxisMarks(values: .stride(by: .weekOfYear)) {
                                                    AxisGridLine()
                                                    AxisTick()
                                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                                }
                                            case .year, .all:
                                                AxisMarks(values: .stride(by: .month)) {
                                                    AxisGridLine()
                                                    AxisTick()
                                                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                LockedSectionMessage(
                                    text: "Mit Movo Pro siehst du, wie viele Workouts du pro Woche schaffst."
                                )
                            }
                        }
                        .padding(.horizontal)
                        .onTapGesture { if !isPremium { openPaywall() } }

                        // Top-Übungen
                        ChallengeStyleSectionCard(
                            title: appSettings.localized("statistics.top.exercises"),
                            icon: "list.star",
                            gradient: [.pink.opacity(0.25), .purple.opacity(0.25)],
                            locked: !isPremium
                        ) {
                            if isPremium {
                                if #available(iOS 16.0, *) {
                                    if exerciseVolumeTop5Kg.isEmpty {
                                        Text(appSettings.localized("statistics.empty.range"))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        let itemsInUnit = exerciseVolumeTop5Kg
                                            .map { ($0.name, unit.fromKilograms($0.volumeKg)) }
                                        Chart {
                                            ForEach(itemsInUnit, id: \.0) { item in
                                                BarMark(
                                                    x: .value(unit.symbol, item.1),
                                                    y: .value(appSettings.localized("statistics.exercise"), item.0)
                                                )
                                            }
                                        }
                                        .frame(height: CGFloat(itemsInUnit.count) * 38 + 40)
                                    }
                                }
                            } else {
                                LockedSectionMessage(
                                    text: "Mit Movo Pro siehst du deine Top-Übungen und ihr Gesamtvolumen."
                                )
                            }
                        }
                        .padding(.horizontal)
                        .onTapGesture { if !isPremium { openPaywall() } }

                        // Übungs-Detail-Stats
                        ChallengeStyleSectionCard(
                            title: appSettings.localized("statistics.exercise.stats"),
                            icon: "dumbbell.fill",
                            gradient: [.indigo.opacity(0.25), .blue.opacity(0.25)],
                            locked: !isPremium
                        ) {
                            if isPremium {
                                if exerciseNames.isEmpty {
                                    Text(appSettings.localized("statistics.exercise.none"))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Menu {
                                        ForEach(exerciseNames, id: \.self) { name in
                                            Button {
                                                selectedExercise = name
                                            } label: {
                                                HStack {
                                                    Text(name)
                                                    if selectedExercise == name {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(selectedExercise ?? appSettings.localized("statistics.exercise.select"))
                                                .font(.body.bold())
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }

                                    if let selectedExercise {
                                        ExerciseStatisticsView(
                                            exerciseName: selectedExercise,
                                            history: filteredHistory
                                        )
                                        .environmentObject(appSettings)
                                        .padding(.top, 12)
                                    }
                                }
                            } else {
                                LockedSectionMessage(
                                    text: "Wähle eine Übung und sieh alle Details mit Movo Pro."
                                )
                            }
                        }
                        .padding(.horizontal)
                        .onTapGesture { if !isPremium { openPaywall() } }
                    }
                    .padding(.vertical, 8)
                }
                .navigationTitle(appSettings.localized("statistics.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showProfile = true } label: {
                            ProfileAvatarButton(
                                customProfileImageData: profileImageData,
                                initials: initialsFromUser()
                            )
                        }
                        .accessibilityLabel(appSettings.localized("profile.title"))
                    }
                }
                .background(navigationLinks())
                .onAppear {
                    TrainingWeeklyShared.saveWeeks(from: trainingStore.history, goalPerWeek: 3) { $0.date }
                    WidgetCenter.shared.reloadTimelines(ofKind: "TrainingWeeklyWidget")
                    // ⬇️ NEU: Heatmap-Snapshot aus echter History + Widget-Reload
                    HeatmapShared.saveSnapshot(from: trainingStore.history) { $0.date }
                    WidgetCenter.shared.reloadTimelines(ofKind: "TrainingHeatmapWidget")
                }
                .onReceive(trainingStore.$history) { hist in
                    TrainingWeeklyShared.saveWeeks(from: hist, goalPerWeek: 3) { $0.date }
                    WidgetCenter.shared.reloadTimelines(ofKind: "TrainingWeeklyWidget")
                    // ⬇️ NEU: Heatmap-Snapshot aktualisieren + Widget-Reload
                    HeatmapShared.saveSnapshot(from: hist) { $0.date }
                    WidgetCenter.shared.reloadTimelines(ofKind: "TrainingHeatmapWidget")
                }
                .onChange(of: purchaseManager.hasUnlockedStatistics) { unlocked in
                    if unlocked { closePaywall() }
                }
                .blur(radius: blur)

                // ========= Paywall Overlay =========
                if showPaywall || dim > 0.001 {
                    Color.black
                        .ignoresSafeArea()
                        .opacity(dim)
                        .onTapGesture { closePaywall() }
                        .animation(currentAnimation, value: dim)

                    if showPaywall {
                        PaywallView(onRequestClose: { closePaywall() })
                            .environmentObject(appSettings)
                            .environmentObject(purchaseManager)
                            .environment(\.colorScheme, .dark)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .zIndex(1)
                            .animation(currentAnimation, value: showPaywall)
                    }
                }
            }
        }
    }

    // MARK: - Animation

    private var currentAnimation: Animation {
        reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.32)
    }

    // MARK: - Achsen (Charts)

    @available(iOS 16.0, *)
    @AxisContentBuilder
    private func dayAxisMarks() -> some AxisContent {
        switch selectedFilter {
        case .week:
            AxisMarks(values: .stride(by: .day)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        case .month:
            AxisMarks(values: .stride(by: .day, count: 3)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        case .year, .all:
            AxisMarks(values: .stride(by: .month)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
    }

    // MARK: - Paywall Open/Close

    private func openPaywall() {
        if reduceMotion {
            dim = 1
            blur = 0
            showPaywall = true
            return
        }
        withAnimation(currentAnimation) {
            dim = 1
            blur = 2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(currentAnimation) {
                showPaywall = true
            }
        }
    }

    private func closePaywall() {
        if reduceMotion {
            showPaywall = false
            dim = 0
            blur = 0
            return
        }
        withAnimation(currentAnimation) { showPaywall = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(currentAnimation) {
                dim = 0
                blur = 0
            }
        }
    }

    // MARK: - Helpers

    private func prettifiedTitle(_ raw: String) -> String {
        let l = raw.lowercased()
        if l.hasPrefix("week ") || l.hasPrefix("woche "),
           let n = Int(raw.filter(\.isNumber)), n > 0 {
            return (appSettings.language == "de") ? "Woche \(n)" : "Week \(n)"
        }
        return raw.isEmpty ? appSettings.localized("training.training") : raw
    }

    private func initialsFromUser() -> String {
        if let email = authService.user?.email {
            let namePart = email.split(separator: "@").first ?? ""
            let parts = namePart.split(separator: ".")
            let initials = parts.prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
            return initials.isEmpty ? "?" : initials
        } else if authService.isGuest {
            return "G"
        } else {
            return "?"
        }
    }

    @ViewBuilder
    private func navigationLinks() -> some View {
        ZStack {
            NavigationLink(isActive: $showProfile) {
                ProfileView(customProfileImageData: $profileImageData)
                    .environmentObject(appSettings)
                    .environmentObject(authService)
                    .environmentObject(trainingStore)
                    .environmentObject(gm)
            } label: { EmptyView() }
        }
        .frame(width: 0, height: 0)
    }

    // Parsing & Unit helpers (kg intern)

    private func parseKg(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        if let n = nf.number(from: trimmed) { return n.doubleValue }
        if let d = Double(trimmed.replacingOccurrences(of: ",", with: ".")) { return d }
        if let n = nf.number(from: trimmed.replacingOccurrences(of: ".", with: ",")) { return n.doubleValue }
        return 0
    }

    private func parseInt(_ s: String) -> Int {
        Int(s.filter("0123456789".contains)) ?? 0
    }

    private func fmtUnit(_ kg: Double, unit: WeightUnit, nf: NumberFormatter) -> String {
        let val = unit.fromKilograms(kg)
        let s = nf.string(from: NSNumber(value: Int(round(val)))) ?? String(Int(round(val)))
        return "\(s) \(unit.symbol)"
    }

    private func entryTotalKg(_ entry: TrainingEntry) -> Double {
        let mirror = Mirror(reflecting: entry)
        if let tw = mirror.children.first(where: { $0.label == "totalWeight" })?.value as? Double {
            return tw
        }
        return entry.exercises
            .flatMap(\.sets)
            .reduce(0.0) { $0 + parseKg($1.weight) * Double(parseInt($1.reps)) }
    }
}

// MARK: - Helpers: Domain padding (wie gehabt)

fileprivate func paddedDayDomain(from dates: [Date]) -> ClosedRange<Date>? {
    guard let min = dates.min(), let max = dates.max() else { return nil }
    let cal = Calendar.current
    let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: min)!)
    let end   = cal.startOfDay(for: cal.date(byAdding: .day, value:  1, to: max)!)
    return start ... end
}

fileprivate extension View {
    @available(iOS 16.0, *)
    func applyPaddedDomain(_ dates: [Date]) -> some View {
        if let domain = paddedDayDomain(from: dates) {
            return AnyView(self.chartXScale(domain: domain))
        } else {
            return AnyView(self)
        }
    }
}

// MARK: - Shared UI

private struct ProgressBar: View {
    let progress: Double     // 0...1
    let height: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = max(0, min(1, progress)) * geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(.white.opacity(0.08))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: w)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Nur Wert, kleine Karte (Header)

private struct MetricCardValueSmall: View {
    @Environment(\.designTokens) private var t
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(t.palette.primary.opacity(0.10))
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(t.palette.primary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(value)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .appElevatedCard()
    }
}

// MARK: - Nur Wert, große Karte (Total Weight)

private struct MetricCardFeaturedValue: View {
    @Environment(\.designTokens) private var t
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(t.palette.primary.opacity(0.10))
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(t.palette.primary)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .appElevatedCard()
    }
}

// MARK: - Section Card

struct ChallengeStyleSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let gradient: [Color]
    var locked: Bool = false

    private let content: Content

    init(
        title: String,
        icon: String,
        gradient: [Color],
        locked: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.locked = locked
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 5)
        )
        .overlay(alignment: .topTrailing) {
            if locked {
                LockBadgeSmall()
            }
        }
    }
}

// kleines Schloss-Badge (wie Sleep-HR Screenshot)

private struct LockBadgeSmall: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 13, weight: .semibold))
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .padding(10)
    }
}

// Text-Placeholder für gesperrte Bereiche

private struct LockedSectionMessage: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Avatar

private struct ProfileAvatarButton: View {
    let customProfileImageData: Data?
    let initials: String?
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let data = customProfileImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color(.systemGray5))
                    Text(initials?.prefix(2).uppercased() ?? "")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Circle())
    }
}

// MARK: - Übungs-Detail-Stats
struct ExerciseStatisticsView: View {
    let exerciseName: String
    let history: [TrainingEntry]

    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        let unit = weightUnit
        let nf = makeIntFormatter()
        let df = makeMediumDateFormatter()

        let sets = buildSets(history: history)

        let totalSets = sets.count
        let totalSessions = Set(sets.map { Calendar.current.startOfDay(for: $0.date) }).count
        let totalVolumeKg = sets.reduce(0.0) { $0 + $1.volumeKg }
        let avgWeightKg = totalSets > 0 ? sets.reduce(0.0) { $0 + $1.weightKg } / Double(totalSets) : 0
        let avgReps = totalSets > 0 ? Double(sets.reduce(0) { $0 + $1.reps }) / Double(totalSets) : 0
        let bestSetVolumeKg = sets.map(\.volumeKg).max() ?? 0
        let bestEst1RMKg = sets.map(\.est1RMKg).max() ?? 0
        let bestEst1RMDate = sets.first(where: { abs($0.est1RMKg - bestEst1RMKg) < 1e-9 })?.date

        let volumeByDayInUnit: [(date: Date, value: Double)] = {
            let grouped = Dictionary(grouping: sets, by: { Calendar.current.startOfDay(for: $0.date) })
            return grouped
                .map { (day, ss) in (day, unit.fromKilograms(ss.reduce(0.0) { $0 + $1.volumeKg })) }
                .sorted { $0.date < $1.date }
        }()

        let prTimelineInUnit: [(date: Date, value: Double, isPR: Bool)] = {
            let bestPerDay = Dictionary(grouping: sets, by: { Calendar.current.startOfDay(for: $0.date) })
                .map { (day, ss) in (day, ss.map(\.est1RMKg).max() ?? 0) }
                .sorted { $0.0 < $1.0 }
            var runMaxKg = 0.0
            return bestPerDay.map { (day, valKg) in
                let isPR = valKg > runMaxKg + 1e-9
                if isPR { runMaxKg = valKg }
                return (day, unit.fromKilograms(valKg), isPR)
            }
        }()

        let repsBuckets: [(label: String, count: Int)] = {
            let ranges: [(ClosedRange<Int>, String)] = [(1...5,"1–5"),(6...8,"6–8"),(9...12,"9–12"),(13...100,"13+")]
            var counts = Dictionary(uniqueKeysWithValues: ranges.map { ($0.1, 0) })
            for s in sets {
                if let r = ranges.first(where: { $0.0.contains(s.reps) }) {
                    counts[r.1, default: 0] += 1
                }
            }
            return ranges.map { ($0.1, counts[$0.1] ?? 0) }
        }()

        let weightBucketsInUnit: [(label: String, count: Int)] = {
            guard let minKg = sets.map(\.weightKg).min(),
                  let maxKg = sets.map(\.weightKg).max(),
                  maxKg > minKg else { return [] }
            let bins = 5
            let stepKg = (maxKg - minKg) / Double(bins)
            guard stepKg > 0 else { return [] }

            var counts = Array(repeating: 0, count: bins)
            for s in sets {
                var idx = Int((s.weightKg - minKg) / stepKg)
                if idx >= bins { idx = bins - 1 }
                if idx < 0 { idx = 0 }
                counts[idx] += 1
            }

            return (0..<bins).map { i in
                let lower = unit.fromKilograms(minKg + Double(i) * stepKg)
                let upper = unit.fromKilograms(minKg + Double(i+1) * stepKg)
                let lowerStr = nf.string(from: NSNumber(value: Int(lower.rounded()))) ?? "\(Int(lower.rounded()))"
                let upperStr = nf.string(from: NSNumber(value: Int(upper.rounded()))) ?? "\(Int(upper.rounded()))"
                return ("\(lowerStr)–\(upperStr) \(unit.symbol)", counts[i])
            }
        }()

        let topDaysInUnit = Array(volumeByDayInUnit.sorted { $0.value > $1.value }.prefix(3))

        return VStack(alignment: .leading, spacing: 16) {
            Text(exerciseName)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                kpi(appSettings.localized("details.sets"), "\(totalSets)")
                kpi(appSettings.localized("statistics.sessions"), "\(totalSessions)")
                kpi(appSettings.localized("statistics.volume"), fmtUnit(totalVolumeKg, unit: unit, nf: nf))
                kpi(appSettings.localized("statistics.avg.weight"), fmtUnit(avgWeightKg, unit: unit, nf: nf))
                kpi(appSettings.localized("statistics.avg.reps"), String(format: "%.1f", avgReps))
                kpi(appSettings.localized("statistics.best.set"), fmtUnit(bestSetVolumeKg, unit: unit, nf: nf))
                kpi(appSettings.localized("statistics.est1rm"),
                    fmtUnit(bestEst1RMKg, unit: unit, nf: nf),
                    subtitle: bestEst1RMDate.map { df.string(from: $0) })
            }

            ChallengeStyleSectionCard(
                title: appSettings.localized("statistics.volume.per.day"),
                icon: "chart.bar.fill",
                gradient: [.blue.opacity(0.25), .purple.opacity(0.25)]
            ) {
                if #available(iOS 16.0, *) {
                    if volumeByDayInUnit.isEmpty {
                        Text(appSettings.localized("statistics.no.data"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Chart {
                            ForEach(volumeByDayInUnit, id: \.date) { b in
                                BarMark(
                                    x: .value(appSettings.localized("statistics.date"), b.date, unit: .day),
                                    y: .value(unit.symbol, b.value),
                                    width: .fixed(12)
                                )
                            }
                        }
                        .frame(height: 200)
                        .applyPaddedDomain(volumeByDayInUnit.map(\.date))
                    }
                }
            }

            ChallengeStyleSectionCard(
                title: appSettings.localized("statistics.pr.timeline"),
                icon: "flame.fill",
                gradient: [.orange.opacity(0.25), .pink.opacity(0.25)]
            ) {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(prTimelineInUnit, id: \.date) { p in
                            LineMark(
                                x: .value(appSettings.localized("statistics.date"), p.date, unit: .day),
                                y: .value(unit.symbol, p.value)
                            )
                            .interpolationMethod(.monotone)
                        }
                        ForEach(prTimelineInUnit.filter { $0.isPR }, id: \.date) { p in
                            PointMark(
                                x: .value(appSettings.localized("statistics.date"), p.date, unit: .day),
                                y: .value(unit.symbol, p.value)
                            )
                            .symbolSize(80)
                        }
                    }
                    .frame(height: 200)
                }
            }

            ChallengeStyleSectionCard(
                title: appSettings.localized("statistics.sets.distribution"),
                icon: "square.grid.2x2",
                gradient: [.teal.opacity(0.25), .blue.opacity(0.25)]
            ) {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(repsBuckets, id: \.label) { b in
                            BarMark(
                                x: .value(appSettings.localized("common.category"), b.label),
                                y: .value(appSettings.localized("details.sets"), b.count)
                            )
                        }
                    }
                    .frame(height: 180)
                }
            }

            if !weightBucketsInUnit.isEmpty {
                ChallengeStyleSectionCard(
                    title: String(format: appSettings.localized("statistics.weight.distribution.format"), unit.symbol),
                    icon: "scalemass",
                    gradient: [.purple.opacity(0.25), .pink.opacity(0.25)]
                ) {
                    if #available(iOS 16.0, *) {
                        Chart {
                            ForEach(weightBucketsInUnit, id: \.label) { b in
                                BarMark(
                                    x: .value(unit.symbol, b.label),
                                    y: .value(appSettings.localized("details.sets"), b.count)
                                )
                            }
                        }
                        .frame(height: 180)
                    }
                }
            }

            if !topDaysInUnit.isEmpty {
                ChallengeStyleSectionCard(
                    title: appSettings.localized("statistics.top.days.volume"),
                    icon: "trophy.fill",
                    gradient: [.yellow.opacity(0.35), .orange.opacity(0.5)]
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(topDaysInUnit, id: \.date) { item in
                            HStack {
                                Text(df.string(from: item.date))
                                Spacer()
                                let valStr = nf.string(from: NSNumber(value: Int(item.value.rounded()))) ?? "\(Int(item.value.rounded()))"
                                Text("\(valStr) \(unit.symbol)")
                                    .font(.body.bold())
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers
    private func kpi(_ title: String, _ value: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
            if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildSets(history: [TrainingEntry]) -> [SetLite] {
        history.flatMap { entry in
            entry.exercises
                .filter { $0.name == exerciseName }
                .flatMap { ex in
                    ex.sets.map { s in
                        let wKg = parseKg(s.weight)
                        let r = parseInt(s.reps)
                        return SetLite(
                            date: entry.date,
                            weightKg: wKg,
                            reps: r,
                            volumeKg: wKg * Double(r),
                            est1RMKg: epley1RM(weightKg: wKg, reps: r)
                        )
                    }
                }
        }
        .sorted { $0.date < $1.date }
    }

    private func epley1RM(weightKg: Double, reps: Int) -> Double {
        guard weightKg > 0, reps > 0 else { return 0 }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    private func parseKg(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        if let n = nf.number(from: trimmed) { return n.doubleValue }
        if let d = Double(trimmed.replacingOccurrences(of: ",", with: ".")) { return d }
        if let n = nf.number(from: trimmed.replacingOccurrences(of: ".", with: ",")) { return n.doubleValue }
        return 0
    }

    private func parseInt(_ s: String) -> Int {
        Int(s.filter("0123456789".contains)) ?? 0
    }

    private func fmtUnit(_ kg: Double, unit: WeightUnit, nf: NumberFormatter) -> String {
        let val = unit.fromKilograms(kg)
        let s = nf.string(from: NSNumber(value: Int(round(val)))) ?? "\(Int(round(val)))"
        return "\(s) \(unit.symbol)"
    }

    private func makeIntFormatter() -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = .current
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }

    private func makeMediumDateFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }

    private struct SetLite {
        let date: Date
        let weightKg: Double
        let reps: Int
        let volumeKg: Double
        let est1RMKg: Double
    }
}

// Kleine Teaser-Karte (wird unter den KPIs angezeigt, wenn Premium gesperrt ist)
private struct PremiumStatsTeaser: View {
    var onTap: () -> Void
    init(_ onTap: @escaping () -> Void) { self.onTap = onTap }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "crown.fill").foregroundStyle(.white).font(.title2.bold())
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium-Statistiken").font(.headline)
                    Text("Beta: Alle Pro-Features sind aktuell kostenlos.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            VStack(spacing: 10) {
                row(icon: "chart.bar.fill", title: "Erweiterte Diagramme & Trends")
                row(icon: "trophy.fill",     title: "Bestes Training & Rekorde")
                row(icon: "timer",           title: "Dauer, Volumen, Top-Übungen")
                row(icon: "square.grid.2x2", title: "Widgets auf dem Homescreen")
            }

            Button(action: onTap) {
                Text("Kostenlos freischalten")
                    .fontWeight(.bold)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.blue, .purple],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(radius: 8, x: 0, y: 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func row(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 44, height: 44)
                Image(systemName: icon).foregroundStyle(.primary)
            }
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}



enum MuscleSide { case front, back }

final class AssetNameResolver {
    static let shared = AssetNameResolver()
    private var cache: [String: Bool] = [:]

    func exists(_ name: String) -> Bool {
        if let v = cache[name] { return v }
        let ok = UIImage(named: name) != nil
        cache[name] = ok
        return ok
    }

    func resolve(_ candidates: [String]) -> String? {
        candidates.first(where: exists)
    }
}

enum MuscleRegion: String, CaseIterable, Hashable {
    // Front
    case chest, shoulders, biceps, forearms, abs, quads, calves
    // Back
    case traps, lats, triceps, lowerBack, glutes, hamstrings, calvesBack

    var side: MuscleSide {
        switch self {
        case .chest, .shoulders, .biceps, .forearms, .abs, .quads, .calves: return .front
        case .traps, .lats, .triceps, .lowerBack, .glutes, .hamstrings, .calvesBack: return .back
        }
    }

    /// Kandidaten: erst "saubere" Namen, dann ".png", dann deine aktuellen Asset-Namen
    var candidateAssetNames: [String] {
        switch self {
        case .chest:      return ["muscle_front_chest", "muscle_front_chest.png"]
        case .shoulders:  return ["muscle_front_shoulders", "muscle_front_shoulders.png"]
        case .biceps:     return ["muscle_front_biceps", "muscle_front_biceps.png", "upperarms_front"]
        case .forearms:   return ["muscle_front_forearms", "muscle_front_forearms.png", "forearms_front"]
        case .abs:        return ["muscle_front_abs", "muscle_front_abs.png"]
        case .quads:      return ["muscle_front_quads", "muscle_front_quads.png"]
        case .calves:     return ["muscle_front_calves", "muscle_front_calves.png"]

        case .traps:      return ["muscle_back_traps", "muscle_back_traps.png", "traps_back"]
        case .lats:       return ["muscle_back_lats", "muscle_back_lats.png"]
        case .triceps:    return ["muscle_back_triceps", "muscle_back_triceps.png", "triceps_back"]
        case .lowerBack:  return ["muscle_back_lowerback", "muscle_back_lowerBack", "midback_back"]
        case .glutes:     return ["muscle_back_glutes", "muscle_back_glutes.png"]
        case .hamstrings: return ["muscle_back_hamstrings", "muscle_back_hamstrings.png", "hamstrings_back"]
        case .calvesBack: return ["muscle_back_calves", "muscle_back_calves.png"]
        }
    }

    var resolvedAssetName: String? {
        AssetNameResolver.shared.resolve(candidateAssetNames)
    }
}

struct MuscleMapSummary: View {
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings

    let load: [MuscleRegion: Double]
    private var maxLoad: Double { max(load.values.max() ?? 0, 1) }

    var body: some View {
        let title = String(
            format: appSettings.localized("statistics.musclemap.title.thisweek.format"),
            appSettings.localized("statistics.musclemap.title"),
            appSettings.localized("statistics.musclemap.thisweek")
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Circle().fill(t.palette.primary.opacity(0.25)).frame(width: 10, height: 10)
                Text(appSettings.localized("statistics.musclemap.legend.trained"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                MuscleFigure(side: .front, tint: t.palette.primary, load: load, maxLoad: maxLoad)
                MuscleFigure(side: .back,  tint: t.palette.primary, load: load, maxLoad: maxLoad)
            }
            .frame(maxWidth: .infinity)
        }
        .appElevatedCard()
    }
}

private struct MuscleFigure: View {
    @Environment(\.colorScheme) private var scheme

    let side: MuscleSide
    let tint: Color
    let load: [MuscleRegion: Double]
    let maxLoad: Double

    var body: some View {
        let outlineColor: Color =
            (scheme == .dark) ? .white.opacity(0.85) : .black.opacity(0.18)

        let regionBlend: BlendMode =
            (scheme == .dark) ? .screen : .multiply

        ZStack {
            Image(side == .front ? "muscle_front_outline" : "muscle_back_outline")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(outlineColor)

            ForEach(MuscleRegion.allCases.filter { $0.side == side }, id: \.self) { region in
                let v = load[region, default: 0]
                let opacity = opacityFor(value: v, maxValue: maxLoad)

                if opacity > 0.001, let name = region.resolvedAssetName {
                    Image(name)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(tint)
                        .opacity(opacity)
                        .blendMode(regionBlend)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func opacityFor(value: Double, maxValue: Double) -> Double {
        guard value > 0, maxValue > 0 else { return 0 }
        let n = min(max(value / maxValue, 0), 1)
        return 0.18 + 0.82 * sqrt(n)
    }
}


// iOS 17: Präsentationshintergrund direkt schwarz
@available(iOS 17.0, *)
private struct PresentationBGBlack: ViewModifier {
    func body(content: Content) -> some View {
        content.presentationBackground(.black)
    }
}

// iOS 16 Fallback: UIKit-Container sofort schwarz färben
private struct SolidBlackBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            Color.black
                .ignoresSafeArea()
                .overlay(UIViewBGBlack().ignoresSafeArea())
        )
    }
}

private struct UIViewBGBlack: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { let v = UIView(); v.backgroundColor = .black; return v }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private extension View {
    @ViewBuilder
    func applyPresentationBackgroundIfAvailable() -> some View {
        if #available(iOS 17.0, *) { self.modifier(PresentationBGBlack()) }
        else { self.modifier(SolidBlackBackground()) }
    }
}

// MARK: - 1) Custom Transition
extension AnyTransition {
    static var paywall: AnyTransition {
        let insertion = AnyTransition
            .opacity
            .combined(with: .move(edge: .bottom))
            .combined(with: .scale(scale: 0.995, anchor: .center)) // leicht heranzoomen

        let removal = AnyTransition
            .opacity
            .combined(with: .move(edge: .bottom))

        return .asymmetric(insertion: insertion, removal: removal)
    }
}

// MARK: - 2) Host-Container, der weich ein-/ausblendet
struct SmoothPaywallHost<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showPaywall = false
    @State private var dim: CGFloat = 0      // 0…1 Overlay-Opacity
    @State private var blur: CGFloat = 0     // Blur des Hintergrunds

    @EnvironmentObject var app: AppSettings
    @EnvironmentObject var pm: PurchaseManager

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Dein normaler Inhalt
            content
                .blur(radius: blur)

            // Dim-Overlay (interaktiv nur wenn sichtbar)
            if showPaywall || dim > 0 {
                Color.black
                    .ignoresSafeArea()
                    .opacity(dim)
                    .onTapGesture { close() }
                    .allowsHitTesting(dim > 0.01)
                    .animation(animation, value: dim)
                    .transition(.opacity)
            }

            // Paywall als Overlay mit eigener Transition
            if showPaywall {
                PaywallView(onRequestClose: { close() })
                    .environmentObject(app)
                    .environmentObject(pm)
                    .transition(.paywall)
                    .zIndex(1)
                    .animation(animation, value: showPaywall)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Premium öffnen") { open() }
            }
        }
    }

    private var animation: Animation {
        reduceMotion
            ? .linear(duration: 0.15)
            : .easeInOut(duration: 0.32)
    }

    // MARK: Open/Close
    private func open() {
        if reduceMotion {
            dim = 1; blur = 0; showPaywall = true
            return
        }
        // erst Hintergrund weich dimmen/blur-en, dann Paywall einfahren
        withAnimation(animation) { dim = 1; blur = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(animation) { showPaywall = true }
        }
    }

    private func close() {
        if reduceMotion {
            showPaywall = false; dim = 0; blur = 0
            return
        }
        // erst Paywall raus, dann Overlay zurückfahren
        withAnimation(animation) { showPaywall = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(animation) { dim = 0; blur = 0 }
        }
    }
}
