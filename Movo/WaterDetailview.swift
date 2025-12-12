import SwiftUI
import Charts

struct WaterDetailView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    
    @AppStorage("water.intake") private var waterIntake: Int = 0
    @AppStorage("water.goal") private var waterGoal: Int = 2000
    
    // Persistent water history
    @AppStorage("water.history") private var waterHistoryData: Data = Data()
    @State private var waterHistory: [Date: Int] = [:]
    
    @State private var daysBack: Int = 7
    @State private var dailyData: [DailyWater] = []
    
    // Locale anhand der App-Sprache
    private var appLocale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }
    
    // Stats
    private var totalWater: Int {
        dailyData.reduce(0) { $0 + $1.amount }
    }
    
    private var avgWater: Int {
        guard !dailyData.isEmpty else { return 0 }
        return totalWater / dailyData.count
    }
    
    private var goalsHit: Int {
        dailyData.filter { $0.amount >= waterGoal }.count
    }
    
    private var progressToday: Double {
        guard waterGoal > 0 else { return 0 }
        return min(1.0, Double(waterIntake) / Double(waterGoal))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Header / Current Value
                    VStack(spacing: 8) {
                        Text(appSettings.localized("water.title"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(waterIntake)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.cyan)
                            Text(appSettings.localized("unit.ml"))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        // Progress bar
                        VStack(spacing: 8) {
                            ProgressView(value: progressToday)
                                .tint(.cyan)
                                .frame(width: 200)
                            
                            Text(
                                String(
                                    format: appSettings.localized("water.progressOfGoal"),
                                    Int(progressToday * 100),
                                    waterGoal
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Quick Add Buttons
                    HStack(spacing: 12) {
                        QuickAddButton(amount: 250, icon: "drop.fill") {
                            waterIntake += 250
                            saveTodayIntake()
                        }
                        QuickAddButton(amount: 500, icon: "drop.fill") {
                            waterIntake += 500
                            saveTodayIntake()
                        }
                        QuickAddButton(amount: 1000, icon: "drop.fill") {
                            waterIntake += 1000
                            saveTodayIntake()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Undo Button
                    if waterIntake > 0 {
                        Button(action: {
                            waterIntake = max(0, waterIntake - 250)
                            saveTodayIntake()
                        }) {
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.orange)
                                Text(
                                    String(
                                        format: appSettings.localized("water.undo.step"),
                                        250
                                    )
                                )
                                .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)
                    }
                    
                    // 2. Chart Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(appSettings.localized("water.hydrationTrend"))
                                .font(.headline)
                            Spacer()
                            Picker(appSettings.localized("common.range"), selection: $daysBack) {
                                Text(String(format: appSettings.localized("range.days"), 7)).tag(7)
                                Text(String(format: appSettings.localized("range.days"), 30)).tag(30)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 180)
                        }
                        .padding(.horizontal)
                        
                        if dailyData.isEmpty {
                            ContentUnavailableView(
                                appSettings.localized("water.noData.title"),
                                systemImage: "drop.fill",
                                description: Text(appSettings.localized("water.noData.description"))
                            )
                            .frame(height: 250)
                        } else {
                            Chart {
                                ForEach(dailyData) { day in
                                    BarMark(
                                        x: .value(appSettings.localized("statistics.date"), day.date, unit: .day),
                                        y: .value(appSettings.localized("water.unit"), day.amount)
                                    )
                                    .foregroundStyle(
                                        day.amount >= waterGoal
                                        ? Color.cyan
                                        : Color.cyan.opacity(0.5)
                                    )
                                }
                                
                                // Goal line
                                RuleMark(y: .value("Goal", waterGoal))
                                    .lineStyle(.init(lineWidth: 2, dash: [5, 5]))
                                    .foregroundStyle(.cyan.opacity(0.5))
                            }
                            .frame(height: 250)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: axisStride(for: daysBack))) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(axisLabel(for: date, daysBack: daysBack, locale: appLocale))
                                        }
                                    }
                                }
                            }
                            .environment(\.locale, appLocale)
                            .padding(.horizontal)

                            .environment(\.locale, appLocale)
                            .padding(.horizontal)
                        }
                    }
                    
                    // 3. Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatBox(
                            title: appSettings.localized("statistics.total"),
                            value: "\(totalWater) \(appSettings.localized("unit.ml"))",
                            icon: "drop.fill",
                            color: .cyan
                        )
                        StatBox(
                            title: appSettings.localized("statistics.average"),
                            value: "\(avgWater) \(appSettings.localized("unit.ml"))",
                            icon: "chart.bar.fill",
                            color: .blue
                        )
                        StatBox(
                            title: appSettings.localized("water.goalsHit.title"),
                            value: String(
                                format: appSettings.localized("water.goalsHit.value"),
                                goalsHit,
                                dailyData.count
                            ),
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        StatBox(
                            title: appSettings.localized("statistics.today"),
                            value: "\(waterIntake) \(appSettings.localized("unit.ml"))",
                            icon: "drop.fill",
                            color: .cyan
                        )
                    }
                    .padding(.horizontal)
                    
                    // 4. Goal Setting
                    VStack(alignment: .leading, spacing: 16) {
                        Text(appSettings.localized("water.dailyGoal"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Text(appSettings.localized("water.goal.target"))
                                .font(.body)
                            Spacer()
                            Stepper(
                                "",
                                onIncrement: { waterGoal += 250 },
                                onDecrement: { waterGoal = max(500, waterGoal - 250) }
                            )
                            Text("\(waterGoal) \(appSettings.localized("unit.ml"))")
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appSettings.localized("water.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                }
            }
        }
        .onAppear {
            loadHistory()
            loadData()
        }
        .onChange(of: daysBack) { _ in
            loadData()
        }
    }
    
    
    // Abstand zwischen den Ticks auf der X-Achse
    private func axisStride(for daysBack: Int) -> Int {
        switch daysBack {
        case ...7:
            // 7 Tage -> jeden Tag ein Label
            return 1
        default:
            // 30 Tage -> alle 3 Tage ein Label
            return 3      // wenn du es noch luftiger willst: 5
        }
    }

    // Text für das X-Achsen-Label
    private func axisLabel(for date: Date, daysBack: Int, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale

        if daysBack <= 7 {
            // "Mo", "Di", …
            f.dateFormat = "E"
        } else {
            // "1.", "4.", "7.", …
            f.dateFormat = "d."
        }

        return f.string(from: date)
    }

    // MARK: - Data / Persistence
    
    private func loadHistory() {
        if let decoded = try? JSONDecoder().decode([Date: Int].self, from: waterHistoryData) {
            waterHistory = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(waterHistory) {
            waterHistoryData = encoded
        }
    }
    
    private func saveTodayIntake() {
        let today = Calendar.current.startOfDay(for: Date())
        waterHistory[today] = waterIntake
        saveHistory()
        loadData() // Refresh the chart
    }
    
    private func loadData() {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else { return }
        
        var data: [DailyWater] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let day = calendar.startOfDay(for: currentDate)
            let amount: Int
            
            if calendar.isDateInToday(currentDate) {
                amount = waterIntake
            } else if let historical = waterHistory[day] {
                amount = historical
            } else {
                amount = 0 // No data for this day
            }
            
            data.append(DailyWater(date: day, amount: amount))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        dailyData = data
    }
}

struct DailyWater: Identifiable {
    let id = UUID()
    let date: Date
    var amount: Int
}

struct QuickAddButton: View {
    @EnvironmentObject var appSettings: AppSettings
    
    let amount: Int
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.cyan)
                
                Text(
                    String(
                        format: appSettings.localized("water.quickAdd"),
                        amount
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
