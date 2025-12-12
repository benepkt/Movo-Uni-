import SwiftUI
import Charts
import HealthKit

struct SleepDetailView: View {
    @EnvironmentObject var appSettings: AppSettings
    @ObservedObject var healthManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    
    @State private var daysBack: Int = 7
    @State private var dailyData: [DailySleep] = []
    
    // Stats
    private var avgSleep: Double {
        guard !dailyData.isEmpty else { return 0 }
        return dailyData.reduce(0.0) { $0 + $1.hours } / Double(dailyData.count)
    }
    
    private var bestNight: Double {
        dailyData.map(\.hours).max() ?? 0
    }
    
    
    private var appLocale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }

    
    private var worstNight: Double {
        dailyData.map(\.hours).min() ?? 0
    }
    
    private var goalAchieved: Int {
        dailyData.filter { $0.hours >= 7.0 }.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Header / Current Value
                    VStack(spacing: 8) {
                        Text(appSettings.localized("common.sleep"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(avgSleep > 0 ? String(format: "%.1f", avgSleep) : "—")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.indigo)
                            Text(appSettings.localized("sleep.unit.hours"))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(appSettings.localized("sleep.average"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 20)
                    
                    // Info banner
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text(appSettings.localized("sleep.info.healthkit"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // 2. Chart Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(appSettings.localized("sleep.pattern"))
                                .font(.headline)
                            Spacer()
                            Picker("", selection: $daysBack) {
                                Text("7 \(appSettings.localized("days"))").tag(7)
                                Text("30 \(appSettings.localized("days"))").tag(30)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 180)
                        }
                        .padding(.horizontal)
                        
                        if dailyData.isEmpty {
                            ContentUnavailableView(
                                appSettings.localized("sleep.noData.title"),
                                systemImage: "moon.fill",
                                description: Text(appSettings.localized("sleep.noData.description"))
                            )
                            .frame(height: 250)
                        } else {
                            Chart {
                                ForEach(dailyData) { day in
                                    BarMark(
                                        x: .value(appSettings.localized("statistics.date"), day.date, unit: .day),
                                        y: .value(appSettings.localized("sleep.unit.hours"), day.hours)
                                    )
                                    .foregroundStyle(
                                        day.hours >= 7.0 ? Color.indigo : Color.indigo.opacity(0.5)
                                    )
                                }
                                
                                // Recommended sleep line (7 hours)
                                RuleMark(y: .value(appSettings.localized("sleep.recommended"), 7.0))
                                    .lineStyle(.init(lineWidth: 2, dash: [5, 5]))
                                    .foregroundStyle(.indigo.opacity(0.5))
                            }
                            .frame(height: 250)
                            .chartYScale(domain: 0...10)
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

                            .padding(.horizontal)

                            .padding(.horizontal)
                        }
                    }
                    
                    // 3. Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatBox(
                            title: appSettings.localized("sleep.stat.average"),
                            value: String(format: "%.1fh", avgSleep),
                            icon: "chart.bar.fill",
                            color: .indigo
                        )
                        StatBox(
                            title: appSettings.localized("sleep.stat.bestNight"),
                            value: String(format: "%.1fh", bestNight),
                            icon: "star.fill",
                            color: .yellow
                        )
                        StatBox(
                            title: appSettings.localized("sleep.stat.shortest"),
                            value: String(format: "%.1fh", worstNight),
                            icon: "moon.zzz.fill",
                            color: .purple
                        )
                        StatBox(
                            title: String(format: appSettings.localized("sleep.stat.goalNights"), 7),
                            value: "\(goalAchieved)/\(dailyData.count)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                    
                    // 4. Daily History
                    VStack(alignment: .leading, spacing: 16) {
                        Text(appSettings.localized("sleep.recentNights"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(dailyData.sorted(by: { $0.date > $1.date }).prefix(10)) { day in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(day.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.body)
                                        Text(day.quality)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: "moon.fill")
                                            .font(.caption)
                                            .foregroundStyle(.indigo)
                                        Text(String(format: "%.1fh", day.hours))
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
            .navigationTitle(appSettings.localized("common.sleep"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                }
            }
        }
        .onAppear {
            Task {
                // Stelle sicher, dass die Leserechte für Schlaf vorliegen
                if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                    await healthManager.requestReadAuthorizationIfNeeded(
                        readTypes: [sleepType],
                        forcePrompt: true
                    )
                }
                loadData()
            }
        }
        .onChange(of: daysBack) { _ in
            loadData()
        }
    }
    
    private func loadData() {
        healthManager.fetchSleepHistory(days: daysBack) { entries in
            DispatchQueue.main.async {
                self.dailyData = entries.map { entry in
                    let qualityKey: String
                    if entry.hours >= 8.0 {
                        qualityKey = "sleep.quality.excellent"
                    } else if entry.hours >= 7.0 {
                        qualityKey = "sleep.quality.good"
                    } else if entry.hours >= 6.0 {
                        qualityKey = "sleep.quality.fair"
                    } else {
                        qualityKey = "sleep.quality.poor"
                    }
                    
                    let quality = appSettings.localized(qualityKey)
                    
                    return DailySleep(
                        date: entry.date,
                        hours: entry.hours,
                        quality: quality
                    )
                }
            }
        }
    }
    
    // Abstand der Ticks auf der X-Achse
    private func axisStride(for daysBack: Int) -> Int {
        switch daysBack {
        case ...7:
            // 7 Tage -> jeden Tag beschriften
            return 1
        default:
            // 30 Tage -> z.B. jeden 3. Tag
            return 3   // oder 5, wenn du es noch luftiger willst
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

    
    
    struct DailySleep: Identifiable {
        let id = UUID()
        let date: Date
        let hours: Double
        let quality: String
    }
}
