import SwiftUI
import Charts

struct CaloriesDetailView: View {
    @EnvironmentObject var appSettings: AppSettings
    @ObservedObject var healthManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    
    @State private var daysBack: Int = 7
    @State private var dailyData: [DailyCalories] = []
    
    // Locale anhand der App-Sprache
    private var appLocale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }
    
    // Stats
    private var totalCalories: Int {
        dailyData.reduce(0) { $0 + $1.calories }
    }
    
    private var avgCalories: Int {
        guard !dailyData.isEmpty else { return 0 }
        return totalCalories / dailyData.count
    }
    
    private var bestDay: Int {
        dailyData.map(\.calories).max() ?? 0
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Header / Current Value
                    VStack(spacing: 8) {
                        Text(appSettings.localized("calories.title"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(healthManager.todayCalories)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text(appSettings.localized("unit.kcal"))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(appSettings.localized("calories.activeEnergy"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 20)
                    
                    // 2. Chart Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(appSettings.localized("calories.activityTrend"))
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
                                appSettings.localized("calories.noData.title"),
                                systemImage: "flame.fill",
                                description: Text(appSettings.localized("calories.noData.description"))
                            )
                            .frame(height: 250)
                        } else {
                            Chart {
                                ForEach(dailyData) { day in
                                    BarMark(
                                        x: .value(appSettings.localized("statistics.date"), day.date, unit: .day),
                                        y: .value(appSettings.localized("calories.unit"), day.calories)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.orange, .orange.opacity(0.7)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                }
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
                        }
                    }
                    
                    // 3. Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatBox(
                            title: appSettings.localized("statistics.total"),
                            value: "\(totalCalories) \(appSettings.localized("unit.kcal"))",
                            icon: "sum",
                            color: .orange
                        )
                        StatBox(
                            title: appSettings.localized("statistics.average"),
                            value: "\(avgCalories) \(appSettings.localized("unit.kcal"))",
                            icon: "chart.bar.fill",
                            color: .purple
                        )
                        StatBox(
                            title: appSettings.localized("statistics.bestDay"),
                            value: "\(bestDay) \(appSettings.localized("unit.kcal"))",
                            icon: "trophy.fill",
                            color: .yellow
                        )
                        StatBox(
                            title: appSettings.localized("statistics.days"),
                            value: "\(dailyData.count)",
                            icon: "calendar",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // 4. Daily History
                    VStack(alignment: .leading, spacing: 16) {
                        Text(appSettings.localized("calories.dailyHistory"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(dailyData.sorted(by: { $0.date > $1.date })) { day in
                                HStack {
                                    Text(formattedDate(day.date))
                                        .font(.body)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                        Text("\(day.calories) \(appSettings.localized("unit.kcal"))")
                                            .font(.body.weight(.semibold))
                                            .monospacedDigit()
                                    }
                                }
                                .padding()
                                Divider()
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appSettings.localized("calories.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                }
            }
        }
        .onAppear {
            loadData()
        }
        .onChange(of: daysBack) { _ in
            loadData()
        }
    }
    
    private func loadData() {
        healthManager.fetchCaloriesHistory(days: daysBack) { entries in
            dailyData = entries.map { entry in
                DailyCalories(date: entry.date, calories: entry.calories)
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    
    // Wie viele Tage Abstand zwischen den Ticks?
    private func axisStride(for daysBack: Int) -> Int {
        switch daysBack {
        case ...7:
            // 7 Tage -> jeden Tag ein Label
            return 1
        default:
            // 30 Tage -> z.B. jeden 3. oder 5. Tag
            return 3   // oder 5, wenn du es noch luftiger willst
        }
    }

    // Wie soll das Label aussehen?
    private func axisLabel(for date: Date, daysBack: Int, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale

        if daysBack <= 7 {
            // „Mo“, „Di“, …
            f.dateFormat = "E"
        } else {
            // „1.“, „4.“, „7.“, …
            f.dateFormat = "d."
        }

        return f.string(from: date)
    }

    struct DailyCalories: Identifiable {
        let id = UUID()
        let date: Date
        let calories: Int
    }
    
    // Kleiner Stat-Card-Baustein für das Grid
    struct StatBox: View {
        let title: String
        let value: String
        let icon: String
        let color: Color
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(color.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(color)
                        }
                        Spacer()
                    }
                    
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
