import SwiftUI
import Charts

struct MetricDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings // Added
    
    // Config
    let title: String
    let unit: String
    let color: Color
    
    // Data (We expect ordered history)
    var history: [(date: Date, value: Double, status: String)]
    var onAdd: (() -> Void)? = nil
    
    // Interaction State
    @State private var selectedDate: Date?
    @State private var showInfo: Bool = false
    @State private var currentRangeEnd: Date = Date()
    
    // Helpers
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale(identifier: appSettings.language == "de" ? "de_DE" : "en_US")
        return cal
    }
    
    private var currentRangeStart: Date {
        calendar.date(byAdding: .day, value: -6, to: currentRangeEnd) ?? currentRangeEnd
    }
    
    // Filtered Data for Graph
    private var weeklyData: [(date: Date, value: Double, status: String)] {
        // Filter range: Start 00:00 to End 23:59
        let start = calendar.startOfDay(for: currentRangeStart)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: currentRangeEnd) ?? currentRangeEnd
        
        return history.filter { item in
            item.date >= start && item.date <= end
        }
    }
    
    // Metrics for Range
    private var averageValue: Double {
        guard !weeklyData.isEmpty else { return 0 }
        return weeklyData.reduce(0) { $0 + $1.value } / Double(weeklyData.count)
    }
    
    // Global Stats
    private var visibleMin: Double { weeklyData.map { $0.value }.min() ?? 0 }
    private var visibleMax: Double { weeklyData.map { $0.value }.max() ?? 0 }
    
    private var dateRangeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: appSettings.language == "de" ? "de_DE" : "en_US")
        f.dateFormat = "d. MMM"
        return "\(f.string(from: currentRangeStart)) - \(f.string(from: currentRangeEnd))"
    }
    
    // Trend Calculation
    private var trend: (arrow: String, text: String, color: Color)? {
        let prevEnd = calendar.date(byAdding: .day, value: -7, to: currentRangeEnd)!
        let prevStart = calendar.date(byAdding: .day, value: -6, to: prevEnd)!
        
        let prevData = history.filter { $0.date >= calendar.startOfDay(for: prevStart) && $0.date <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: prevEnd)! }
        
        guard !weeklyData.isEmpty, !prevData.isEmpty else { return nil }
        
        let currAvg = weeklyData.reduce(0) { $0 + $1.value } / Double(weeklyData.count)
        let prevAvg = prevData.reduce(0) { $0 + $1.value } / Double(prevData.count)
        
        let diff = currAvg - prevAvg
        if abs(diff) < 0.1 { return ("arrow.right", appSettings.localized("body.detail.trend.stable"), .secondary) } // "Stabil"
        else if diff > 0 { return ("arrow.up", appSettings.localized("body.detail.trend.up"), .red) } // "Steigend"
        else { return ("arrow.down", appSettings.localized("body.detail.trend.down"), .green) } // "Sinkend"
    }
    
    // Selection Helper
    private var selectedValue: (date: Date, value: Double)? {
        guard let d = selectedDate else { return nil }
        // Find closest data point
        return weeklyData.min(by: { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) })
            .map { ($0.date, $0.value) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Area
                    VStack(spacing: 16) {
                        // Date Range Nav
                        HStack {
                            Button { changeRange(by: -7) } label: {
                                Image(systemName: "chevron.left")
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Text(dateRangeString)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(width: 160)
                            
                            Button { changeRange(by: 7) } label: {
                                Image(systemName: "chevron.right")
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .disabled(Calendar.current.isDateInToday(currentRangeEnd))
                        }
                        
                        // Main Value (Dynamic based on selection)
                        VStack(spacing: 4) {
                            if let sel = selectedValue {
                                Text(String(format: "%.1f", sel.value))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .contentTransition(.numericText())
                                Text(itemDateFormatter.string(from: sel.date))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(String(format: "%.1f", weeklyData.last?.value ?? history.last?.value ?? 0)) 
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text(unit)
                                        .font(.title3.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .animation(.snappy, value: selectedDate)
                        
                        // Status Badge / Breakdown
                        if let sel = selectedValue {
                            // find status for selected date
                            if let match = weeklyData.first(where: { $0.date == sel.date }) {
                                HStack(spacing: 4) {
                                    Text(match.status) // This now holds "S: 15 | T: 20" for fitness
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                        } else if let status = weeklyData.last?.status, !status.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    Text(status)
                                    .foregroundStyle(.green)
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                    .padding(.top, 16)
                    
                    // Chart
                    Chart {
                        ForEach(weeklyData, id: \.date) { item in
                            // Line (only if > 1 point, visually better)
                            if weeklyData.count > 1 {
                                LineMark(
                                    x: .value("Tag", item.date, unit: .day),
                                    y: .value("Wert", item.value)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(color)
                            }
                            
                            // Area (Gradient)
                            if weeklyData.count > 1 {
                                AreaMark(
                                    x: .value("Tag", item.date, unit: .day),
                                    y: .value("Wert", item.value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [color.opacity(0.3), color.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                            
                            // Point (Always visible, handles sparse data)
                            PointMark(
                                x: .value("Tag", item.date, unit: .day),
                                y: .value("Wert", item.value)
                            )
                            .foregroundStyle(color)
                            .symbolSize(selectedDate != nil && calendar.isDate(item.date, inSameDayAs: selectedValue?.date ?? Date.distantFuture) ? 100 : 30)
                        }
                        
                        if let sel = selectedValue {
                            RuleMark(x: .value("Selected", sel.date))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(dateWeekdayFormatter.string(from: date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 220)
                    .padding(.horizontal)
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(DragGesture()
                                    .onChanged { value in
                                        let origin = geometry[proxy.plotAreaFrame].origin
                                        let x = value.location.x - origin.x
                                        if let date = proxy.value(atX: x, as: Date.self) {
                                            selectedDate = date
                                        }
                                    }
                                    .onEnded { _ in selectedDate = nil }
                                )
                        }
                    }
                    
                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MetricStatBox(icon: "chart.bar.fill", title: appSettings.localized("body.detail.avg"), value: String(format: "%.1f %@", averageValue, unit), color: color) // "Ø 7 Tage"
                        MetricStatBox(icon: "arrow.up.right", title: appSettings.localized("body.detail.max"), value: String(format: "%.1f %@", visibleMax, unit), color: .secondary) // "Max"
                        
                        if let t = trend {
                            MetricStatBox(icon: t.arrow, title: appSettings.localized("body.detail.trend"), value: t.text, color: t.color) // "Trend"
                        }
                    }
                    .padding(.horizontal)
                    
                    // History List
                    VStack(alignment: .leading, spacing: 16) {
                        Text(appSettings.localized("body.detail.verlauf")) // "Verlauf"
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            if weeklyData.isEmpty {
                                Text(appSettings.localized("body.detail.noData")) // "Keine Daten in diesem Zeitraum"
                                    .foregroundStyle(.secondary)
                                    .padding()
                            } else {
                                ForEach(weeklyData.reversed(), id: \.date) { item in
                                    MetricHistoryRow(item: item, unit: unit)
                                    if item.date != weeklyData.first?.date {
                                        Divider()
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if let action = onAdd {
                            Button { action() } label: {
                                Image(systemName: "plus")
                            }
                        }
                        Button { showInfo = true } label: {
                            Image(systemName: "info.circle")
                        }
                        Button(appSettings.localized("common.done")) { dismiss() } // "Fertig"
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showInfo) {
                MetricInfoSheet(title: title, unit: unit)
                    .presentationDetents([.medium])
            }
        }
    }
    
    private func changeRange(by days: Int) {
        let potentialDate = calendar.date(byAdding: .day, value: days, to: currentRangeEnd) ?? currentRangeEnd
        if potentialDate > Date() {
           currentRangeEnd = Date()
        } else {
           currentRangeEnd = potentialDate
        }
    }
    
    // Formatters
    private var dateWeekdayFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: appSettings.language == "de" ? "de_DE" : "en_US")
        f.dateFormat = "EE"
        return f
    }
    
    private var itemDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: appSettings.language == "de" ? "de_DE" : "en_US")
        f.dateFormat = "d. MMM HH:mm"
        return f
    }
}

// Helpers
struct MetricStatBox: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline).foregroundStyle(.primary)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MetricHistoryRow: View {
    @EnvironmentObject var appSettings: AppSettings // Added
    let item: (date: Date, value: Double, status: String)
    let unit: String
    @State private var isExpanded: Bool = false
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: appSettings.language == "de" ? "de_DE" : "en_US")
        f.dateFormat = "E., d. MMM"
        return f
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: appSettings.language == "de" ? "de_DE" : "en_US")
        f.dateFormat = "HH:mm"
        return f
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.status)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                    Text(dateFormatter.string(from: item.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", item.value))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(unit)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.leading, 4)
                }
            }
            
            if isExpanded {
                HStack {
                    Text(appSettings.localized("body.detail.measuredAt")) // "Gemessen um:"
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(timeFormatter.string(from: item.date))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.leading, 36)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .contentShape(Rectangle()) // Make full row tapable
        .onTapGesture {
            withAnimation(.spring()) {
                isExpanded.toggle()
            }
        }
    }
}

struct MetricInfoSheet: View {
    let title: String
    let unit: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings // Added
    
    var body: some View {
        VStack(spacing: 24) {
            Text("\(appSettings.localized("body.detail.about")) \(title)") // "Über \(title)"
                .font(.title2.bold())
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 16) {
                // Hardcoded german strings here for now, could be improved but user didn't explicitly complain about these descriptive texts, only UI labels.
                // Keeping as is or minimal improvements.
                infoRow(icon: "info.circle.fill", text: appSettings.localized("body.detail.info1"))
                infoRow(icon: "chart.line.uptrend.xyaxis", text: appSettings.localized("body.detail.info2"))
                
                if title == appSettings.localized("body.metric.fitness") { // "Fitnessniveau"
                    Divider()
                    Text(appSettings.localized("body.detail.fitnessCalcTitle"))
                        .font(.headline)
                    Text(appSettings.localized("body.detail.fitnessCalcDesc"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            
            Spacer()
            
            Button(appSettings.localized("body.detail.understood")) { dismiss() } // "Verstanden"
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .padding()
    }
    
    func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.title3)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true) // Fix truncation
        }
    }
}
