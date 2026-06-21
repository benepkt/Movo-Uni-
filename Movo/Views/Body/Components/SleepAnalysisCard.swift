import SwiftUI
import Charts

struct SleepAnalysisCard: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @EnvironmentObject var appSettings: AppSettings
    
    @Binding var selectedDate: Date
    var sleepHistory: [HealthKitManager.SleepEntry]
    
    @State private var showLogSleep = false
    
    // Process real data for the last 7 days ending at Today (fixed anchor)
    private var chartData: [(date: Date, day: String, hours: Double)] {
        let cal = Calendar.current
        var result: [(Date, String, Double)] = []
        
        // Anchor to Today so the chart doesn't slide when selecting past dates
        let anchorDate = Date()
        
        // Show last 7 days relative to Today (inclusive)
        for i in (0..<7).reversed() {
             if let d = cal.date(byAdding: .day, value: -i, to: anchorDate) {
                 // Check manual override first
                 let manual = ManualBodyDataManager.shared.getMetric("sleep")
                 let hours: Double
                 if let manual = manual, cal.isDateInToday(d) && cal.isDateInToday(manual.date) {
                     hours = manual.value
                 } else {
                     let match = sleepHistory.first { cal.isDate($0.date, inSameDayAs: d) }
                     hours = match?.hours ?? 0.0
                 }
                 
                 let f = DateFormatter()
                 // Short day "Mo", "Di"
                 f.dateFormat = "EE" 
                 f.locale = Locale(identifier: appSettings.language)
                 result.append((d, f.string(from: d), hours))
            }
        }
        return result
    }
    
    private var currentSleepValue: Double? {
        let cal = Calendar.current
        
        // Check manual override first
        if cal.isDateInToday(selectedDate) {
             if let manual = ManualBodyDataManager.shared.getMetric("sleep"), cal.isDateInToday(manual.date) {
                 return manual.value
             }
        }
        
        return sleepHistory.first { cal.isDate($0.date, inSameDayAs: selectedDate) }?.hours
    }
    
    // Formatting: "7h 12m" or "7 Std. 12 Min." localized
    private var sleepString: String {
        guard let val = currentSleepValue, val > 0 else { return "--" }
        
        let totalSeconds = val * 3600
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated 
        return formatter.string(from: TimeInterval(totalSeconds)) ?? "--"
    }
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(appSettings.localized("body.sleep.title").uppercased()) // "SLEEP SCORE" or "SCHLAF"
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    
                    if let avg = averageSleepString {
                        Text("• Ø \(avg)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
                
                Spacer()
                
                // Manual Entry Button
                if Calendar.current.isDateInToday(selectedDate) {
                    Button(action: {
                        showLogSleep = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            // Value
            HStack(alignment: .lastTextBaseline) {
                Text(sleepString)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                
                if currentSleepValue != nil {
                     Text(scoreQuality)
                        .font(.caption)
                        .foregroundStyle(scoreColor)
                }
            }
            
            // Chart / Visualization
            chartView
                .frame(height: 100)
            
            Divider().background(Color.secondary.opacity(0.1))
            
            // Footer Text
            Text(appSettings.localized("body.sleep.tip")) 
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .sheet(isPresented: $showLogSleep) {
            ManualSleepSheet()
                .presentationDetents([.fraction(0.55), .medium]) // Increased height to prevent cutoff
        }
    }
    
    private func barStyle(isSelected: Bool, isToday: Bool) -> LinearGradient {
        if isSelected {
            return LinearGradient(colors: [.orange, .red], startPoint: .bottom, endPoint: .top)
        } else if isToday {
            return LinearGradient(colors: [.indigo, .purple], startPoint: .bottom, endPoint: .top)
        } else {
            return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.5)], startPoint: .bottom, endPoint: .top)
        }
    }
    
    private var averageSleepString: String? {
        let values = chartData.map { $0.hours }.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        let avg = values.reduce(0, +) / Double(values.count)
        
        let totalSeconds = avg * 3600
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(totalSeconds))
    }

    private var scoreQuality: String {
        let val = currentSleepValue ?? 0.0
        if val > 7.5 { return appSettings.localized("body.score.optimal") }
        if val > 6.0 { return appSettings.localized("body.score.okay") }
        return appSettings.localized("body.score.low")
    }
    
    private var scoreColor: Color {
        let val = currentSleepValue ?? 0.0
        if val > 7.5 { return .green }
        if val > 6.0 { return .yellow }
        return .red
    }
    
    private var chartView: some View {
        Chart {
            ForEach(chartData, id: \.day) { item in
                let isSelected = Calendar.current.isDate(item.date, inSameDayAs: selectedDate)
                let isToday = Calendar.current.isDateInToday(item.date)
                
                BarMark(
                    x: .value("Day", item.day),
                    y: .value("Hours", item.hours)
                )
                .foregroundStyle(barStyle(isSelected: isSelected, isToday: isToday))
                .cornerRadius(6)
            }
            
            RuleMark(y: .value("Goal", 8.0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.green.opacity(0.6))
        }
        .chartXAxis {
             AxisMarks(values: .automatic) { _ in
                 AxisValueLabel()
                     .foregroundStyle(.secondary)
             }
        }
        .chartYAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { location in
                        let x = location.x - geo[proxy.plotAreaFrame].origin.x
                        if let day: String = proxy.value(atX: x) {
                            if let match = chartData.first(where: { $0.day == day }) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedDate = match.date
                                    UISelectionFeedbackGenerator().selectionChanged()
                                }
                            }
                        }
                    }
            }
        }
    }
}

struct ManualSleepSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @State private var hours: Double = 7.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Check-in Header Style
            HStack {
                Text(appSettings.localized("sleep.manual.title")) // "Schlaf eintragen"
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.3))
                }
            }
            .padding()
            
            Divider()
            
                VStack(spacing: 24) { // Reduced spacing from 32
                    
                    // Value Display
                    VStack(spacing: 4) { // Reduced spacing from 8
                        Text(String(format: appSettings.localized("sleep.manual.hours"), hours)) // "%.1f Std."
                            .font(.system(size: 48, weight: .bold, design: .rounded)) // Reduced size from 56
                            .foregroundStyle(.indigo)
                            .contentTransition(.numericText())
                        
                        Text(appSettings.localized("sleep.manual.desc")) // "Schlafdauer für heute nachtragen"
                            .font(.caption) // Reduced from subheadline
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24) // Reduced from 40
                    
                    // Slider
                    VStack(spacing: 12) {
                        Slider(value: $hours, in: 0...12, step: 0.5)
                            .accentColor(.indigo)
                        
                        HStack {
                            Text("0h")
                            Spacer()
                            Text("12h")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            
            // Pinned Save Button
            VStack {
                Button(action: {
                    ManualBodyDataManager.shared.saveMetric("sleep", value: hours)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                }) {
                    Text(appSettings.localized("sleep.manual.save")) // "Speichern"
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .indigo.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
            .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        }
        .background(Color(.systemBackground))
    }
}
