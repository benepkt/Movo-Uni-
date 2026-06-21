import SwiftUI
import HealthKit
import Charts

// MARK: - Home Stats Grid
struct HomeStatsGrid: View {
    @ObservedObject var healthManager: HealthKitManager
    let workoutsToday: Int
    let lastTrainingDate: Date?
    
    @AppStorage("steps.goal") private var stepsGoal: Int = 8000
    @AppStorage("profile.weightKg") private var weightKg: Double = 0
    @AppStorage("profile.hasGoalWeight") private var hasGoalWeight: Bool = false
    @AppStorage("profile.goalWeightKg")  private var goalWeightKg: Double = 75.0

    private var effectiveGoalWeightKg: Double? { hasGoalWeight ? goalWeightKg : nil }

    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings
    
    // Actions
    var onOpenSteps: () -> Void
    var onOpenWeight: () -> Void
    var onOpenCalories: () -> Void
    var onOpenWater: () -> Void
    var onOpenSleep: () -> Void
    var onOpenLastTraining: () -> Void
    
    private var todaySteps: Int { healthManager.todaySteps }
    private var todayCalories: Int { healthManager.todayCalories }
    
    // Dynamic Items
    let items: [DashboardItem]
    
    // Water State
    @AppStorage("water.intake") private var waterIntake: Int = 0
    @AppStorage("water.goal") private var waterGoal: Int = 2000
    
    // Sleep State
    @State private var sleepHours: Double = 0
    
    // Steps Graph Data
    @State private var hourlySteps: [Double] = []
    
    // Weight history for Delta
    @State private var latestWeight: Double?
    @State private var previousWeight: Double?
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var appLocale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }
    
    // Delta zwischen letzter und vorletzter Messung
    private var weightDelta: Double? {
        guard let last = latestWeight, let prev = previousWeight else { return nil }
        let d = last - prev
        return abs(d) < 0.05 ? nil : d   // Mini-Schwankungen ausblenden
    }
    
    // MARK: - Sleep Texts
    
    private var sleepValueText: String {
        guard sleepHours > 0 else { return "—" }
        
        let f = NumberFormatter()
        f.locale = appLocale
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        
        return f.string(from: NSNumber(value: sleepHours))
            ?? String(format: "%.1f", sleepHours)
    }
    
    private var sleepSubtitleText: String {
        if sleepHours > 0 {
            return appSettings.localized("sleep.unit.hours")
        } else {
            return appSettings.localized("sleep.noData.short")
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    cardView(for: item)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            loadWeightHistory()
            loadSleepSummary()
            loadHourlySteps()
        }
    }
    
    // MARK: - Card Factory
    
    @ViewBuilder
    private func cardView(for item: DashboardItem) -> some View {
        switch item {
        case .steps:
            StepsGraphCard(
                steps: todaySteps,
                title: item.title(using: appSettings),
                hourlySteps: hourlySteps,
                action: onOpenSteps
            )
            
        case .calories:
            StatGridCard(
                icon: item.icon,
                iconColor: .orange,
                title: item.title(using: appSettings),
                value: "\(todayCalories)",
                subtitle: "kcal",
                action: onOpenCalories
            )
            
        case .weight:
            WeightCard(
                title: "\(item.title(using: appSettings)), kg",
                latestWeight: latestWeight ?? (weightKg > 0 ? weightKg : nil),
                delta: weightDelta,
                goal: effectiveGoalWeightKg,
                locale: appLocale,
                onTap: onOpenWeight
            )
            
        case .lastTraining:
            StatGridCard(
                icon: item.icon,
                iconColor: .purple,
                title: item.title(using: appSettings),
                value: formatLastTrainingDate(lastTrainingDate),
                subtitle: lastTrainingDate != nil ? "Last Session" : "No data",
                action: onOpenLastTraining
            )
            
        case .water:
            Button(action: onOpenWater) {
                WaterCard(
                    current: waterIntake,
                    goal: waterGoal,
                    onAdd: { waterIntake += 250 }
                )
            }
            .buttonStyle(.plain)
            
        case .sleep:
            StatGridCard(
                icon: item.icon,
                iconColor: .indigo,
                title: item.title(using: appSettings),
                value: sleepValueText,
                subtitle: sleepSubtitleText,
                action: onOpenSleep
            )
        }
    }
    
    // MARK: - Weight Card
    
    struct WeightCard: View {
        let title: String
        let latestWeight: Double?
        let delta: Double?
        let goal: Double?
        let locale: Locale
        let onTap: () -> Void
        
        private var formattedCurrent: String {
            guard let w = latestWeight else { return "—" }
            return HomeStatsGrid.WeightCard.formatWeight(w, locale: locale)
        }
        
        private var deltaText: String? {
            guard let d = delta else { return nil }
            return HomeStatsGrid.WeightCard.formatWeight(abs(d), locale: locale)
        }
        
        private var deltaSymbol: String {
            guard let d = delta else { return "" }
            return d > 0 ? "arrow.up" : "arrow.down"
        }
        
        private var deltaColor: Color {
            guard let d = delta else { return .secondary }
            return d > 0 ? .orange : .green
        }
        
        private var goalText: String {
            guard let goal else { return "Weight Goal: —" }
            let formattedGoal = HomeStatsGrid.WeightCard.formatWeight(goal, locale: locale)
            return "Weight Goal: \(formattedGoal) kg"
        }

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formattedCurrent)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.6)
                        
                        if let deltaText {
                            HStack(spacing: 3) {
                                Image(systemName: deltaSymbol)
                                    .font(.system(size: 14, weight: .bold))
                                Text(deltaText)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundStyle(deltaColor)
                        }
                    }
                    
                    Text(goalText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 140)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        
        private static func formatWeight(_ value: Double, locale: Locale) -> String {
            let f = NumberFormatter()
            f.locale = locale
            f.minimumFractionDigits = 1
            f.maximumFractionDigits = 1
            return f.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        }
    }
    
    // MARK: - Special Cards
    
    struct WaterCard: View {
        let current: Int
        let goal: Int
        let onAdd: () -> Void
        @Environment(\.designTokens) private var t
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        Circle().fill(Color.cyan.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                    Spacer()
                    
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.cyan)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 12)
                
                Text("\(current)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer(minLength: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Water")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("/ \(goal) ml")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 120)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        }
    }
    
    // MARK: - Helpers
    
    private func loadWeightHistory() {
        healthManager.fetchWeightHistory(days: 90) { entries in
            let sorted = entries.sorted { $0.date < $1.date }
            DispatchQueue.main.async {
                self.latestWeight = sorted.last?.value
                self.previousWeight = sorted.dropLast().last?.value
                if let w = self.latestWeight {
                    self.weightKg = w   // Profilgewicht mitziehen
                }
            }
        }
    }
    
    private func loadSleepSummary() {
        healthManager.fetchSleepHistory(days: 7) { entries in
            let last = entries.sorted { $0.date < $1.date }.last
            // Debug, falls nötig:
            // print("Sleep last night:", last?.hours as Any)
            DispatchQueue.main.async {
                self.sleepHours = last?.hours ?? 0
            }
        }
    }
    
    private func formatLastTrainingDate(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return appSettings.localized("home.today")
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d. MMM"
            return formatter.string(from: date)
        }
        
    }
        
    private func loadHourlySteps() {
        healthManager.fetchTodayHourlySteps { steps in
            DispatchQueue.main.async {
                self.hourlySteps = steps
            }
        }
    }
}

// MARK: - New Steps Graph Card
struct StepsGraphCard: View {
    let steps: Int
    let title: String
    let hourlySteps: [Double]
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground)) // Adaptive
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    Spacer()
                    
                    // Steps Count
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(steps)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary) // Adaptive
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 8) 
                    
                    // Chart
                    Chart {
                        ForEach(Array(hourlySteps.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Hour", index),
                                y: .value("Steps", value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.cyan)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            AreaMark(
                                x: .value("Hour", index),
                                y: .value("Steps", value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 50)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
            }
            .frame(height: 160) 
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}


