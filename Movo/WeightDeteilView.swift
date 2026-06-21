import SwiftUI
import Charts

struct WeightDetailView: View {
    @EnvironmentObject var appSettings: AppSettings
    @ObservedObject var healthManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    
    @State private var history: [HealthKitManager.WeightEntry] = []
    @State private var daysBack: Int = 30
    
    // MARK: - Stats
    
    private var currentWeight: Double { history.last?.value ?? 0 }
    private var minWeight: Double { history.map(\.value).min() ?? 0 }
    private var maxWeight: Double { history.map(\.value).max() ?? 0 }
    
    private var avgWeight: Double {
        guard !history.isEmpty else { return 0 }
        return history.map(\.value).reduce(0, +) / Double(history.count)
    }

    private var trendText: String {
        guard let latest = history.last?.value,
              let previous = history.dropLast().last?.value else { return "—" }
        let delta = latest - previous
        if abs(delta) < 0.15 { return appSettings.language.lowercased().hasPrefix("de") ? "Stabil" : "Stable" }
        let formatted = formatWeight(abs(delta))
        return delta > 0 ? "↑ \(formatted) kg" : "↓ \(formatted) kg"
    }
    
    // Chart Y-Axis Range (dynamic with padding)
    private var yAxisRange: ClosedRange<Double> {
        let min = (minWeight - 2).rounded(.down)
        let max = (maxWeight + 2).rounded(.up)
        if min == max { return (min - 1)...(max + 1) }
        return min...max
    }
    
    private var appLocale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }

    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.pink.opacity(0.25), t.palette.primary.opacity(0.18), .clear],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 420
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        chartSection
                        statsSection
                        historySection
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(appSettings.localized("weight.details.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadData() }
        .onChange(of: daysBack) { _ in loadData() }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(appSettings.localized("common.weight"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.60))
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currentWeight > 0 ? String(format: "%.1f", currentWeight) : "—")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("kg")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(appSettings.localized("weight.chart.trend"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: $daysBack) {
                    Text(appSettings.localized("range.7days")).tag(7)
                    Text(appSettings.localized("range.30days")).tag(30)
                    Text(appSettings.localized("range.90days")).tag(90)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }
            .padding(.horizontal)
            
            if history.isEmpty {
                ContentUnavailableView(
                    appSettings.localized("weight.empty.title"),
                    systemImage: "chart.xyaxis.line",
                    description: Text(appSettings.localized("weight.empty.description"))
                )
                .frame(height: 250)
            } else {
                Chart {
                    ForEach(history, id: \.date) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.value)
                        )
                        .foregroundStyle(Color.pink)
                        .symbol(Circle())
                        .symbolSize(30)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", entry.date),
                            yStart: .value("Min", yAxisRange.lowerBound),
                            yEnd: .value("Weight", entry.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.24), Color.pink.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartYScale(domain: yAxisRange)
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
                .frame(height: 250)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()),
                            GridItem(.flexible())],
                  spacing: 16) {
            WeightStatBox(
                title: appSettings.localized("weight.stat.average"),
                value: String(format: "%.1f kg", avgWeight),
                icon: "scalemass",
                color: .purple
            )
            WeightStatBox(
                title: appSettings.localized("weight.stat.minimum"),
                value: String(format: "%.1f kg", minWeight),
                icon: "arrow.down",
                color: .green
            )
            WeightStatBox(
                title: appSettings.localized("weight.stat.maximum"),
                value: String(format: "%.1f kg", maxWeight),
                icon: "arrow.up",
                color: .red
            )
            WeightStatBox(
                title: appSettings.localized("weight.stat.entries"),
                value: "\(history.count)",
                icon: "list.bullet",
                color: .orange
            )
            WeightStatBox(
                title: appSettings.language.lowercased().hasPrefix("de") ? "Trend" : "Trend",
                value: trendText,
                icon: "chart.line.uptrend.xyaxis",
                color: .pink
            )
        }
        .padding(.horizontal)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(appSettings.localized("weight.history.title"))
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)
            
            let recent = Array(
                history
                    .sorted { $0.date > $1.date }
            )
            
            VStack(spacing: 0) {
                ForEach(recent, id: \.date) { entry in
                    HStack {
                        Text(historyDateString(entry.date))
                            .font(.body)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "%.1f kg", entry.value))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .padding()
                    Divider()
                }
            }
            .background(.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    // Wie viele Tage Abstand zwischen den Ticks?
    private func axisStride(for daysBack: Int) -> Int {
        switch daysBack {
        case ...7:
            // 7 Tage -> jeden Tag ein Label
            return 1
        case 8...30:
            // 30 Tage -> ca. alle 5 Tage
            return 5
        default:
            // 90 Tage -> ca. alle 15 Tage
            return 15
        }
    }

    // Wie soll das Label aussehen?
    private func axisLabel(for date: Date, daysBack: Int, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale

        switch daysBack {
        case ...7:
            // "Mo", "Di", ...
            f.dateFormat = "E"
        case 8...30:
            // "1.", "6.", "11.", ...
            f.dateFormat = "d."
        default:
            // "Jan", "Feb", ...
            f.dateFormat = "MMM"
        }

        return f.string(from: date)
    }

    
    private func historyDateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = appLocale
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func formatWeight(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = appLocale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
    
    // MARK: - Data
    
    private func loadData() {
        healthManager.fetchWeightHistory(days: daysBack) { entries in
            DispatchQueue.main.async {
                withAnimation {
                    self.history = entries
                }
            }
        }
    }
}

private struct WeightStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding()
        .background(.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// Helper View for shared light-mode detail stats
struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
