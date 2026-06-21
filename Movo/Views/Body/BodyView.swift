import SwiftUI
import Charts
import HealthKit

struct BodyView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary // Added for MuscleDistributionChart
    @Environment(\.designTokens) private var t
    @AppStorage("profile.heightCm") private var heightCm: Double = 175
    var embeddedInProfile: Bool = false
    
    // Computation for Muscle Map
    private var historyThisWeek: [TrainingEntry] {
        BodyViewHelper.filterHistory(trainingStore.history, days: 7)
    }
    
    @ObservedObject var manualData = ManualBodyDataManager.shared
    
    
    private var historyLastWeek: [TrainingEntry] {
        BodyViewHelper.filterHistory(trainingStore.history, offsetDays: 7, durationDays: 7)
    }
    
    private var muscleLoadThisWeek: [MuscleRegion: Double] {
        BodyViewHelper.calculateMuscleLoad(from: historyThisWeek)
    }
    
    private var muscleLoadLastWeek: [MuscleRegion: Double] {
        BodyViewHelper.calculateMuscleLoad(from: historyLastWeek)
    }
    
    @State private var showEditMetrics = false
    @AppStorage("body.visibleMetrics") private var visibleMetricsRaw: String = "fitnessLevel,weight,bmi,bodyFat,leanMass,hr,vo2,resp,spo2,temp"
    
    // Computed property to parse visible metrics
    private var visibleMetrics: Set<String> {
        Set(visibleMetricsRaw.split(separator: ",").map { String($0) })
    }
    
    @State private var showScoreDetails = false
    @State private var showSleepDetails = false
    @State private var selectedDate = Date()
    @State private var isLoading = true // Added loading state
    @State private var sleepHistory: [HealthKitManager.SleepEntry] = []
    @State private var stepsHistory: [HealthKitManager.StepsEntry] = []
    @State private var weightHistory: [HealthKitManager.WeightEntry] = []
    @State private var hrvHistory: [(date: Date, value: Double)] = [] // Added HRV History
    @State private var hrHistory: [HealthKitManager.HREntry] = []
    
    // Generic History States
    @State private var bodyFatHistory: [(date: Date, value: Double)] = []
    @State private var leanMassHistory: [(date: Date, value: Double)] = []
    @State private var bmiHistory: [(date: Date, value: Double)] = []
    @State private var vo2History: [(date: Date, value: Double)] = []
    @State private var respHistory: [(date: Date, value: Double)] = []
    @State private var spo2History: [(date: Date, value: Double)] = []
    @State private var tempHistory: [(date: Date, value: Double)] = []
    @State private var fitnessHistory: [(date: Date, value: Double, breakdown: String)] = []
    
    // Sheet State
    @State private var presentedMetric: MetricType?
    @State private var addMetricType: MetricType? // For + sheet
    
    enum MetricType: Identifiable, CaseIterable {
        case weight, bmi, heartRate, bodyFat, leanMass, vo2, resp, spo2, bodyTemp, fitnessLevel
        var id: Self { self }
        
        func title(with settings: AppSettings) -> String {
            switch self {
            case .weight: return settings.localized("body.metric.weight")
            case .bmi: return "BMI"
            case .heartRate: return settings.localized("body.metric.hr")
            case .bodyFat: return settings.localized("body.metric.fat")
            case .leanMass: return settings.localized("body.metric.leanMass")
            case .vo2: return "VO₂ Max"
            case .resp: return settings.localized("body.metric.resp")
            case .spo2: return settings.localized("body.metric.spo2")
            case .bodyTemp: return settings.localized("body.metric.temp")
            case .fitnessLevel: return settings.localized("body.metric.fitness")
            }
        }
        
        var unit: String {
            switch self {
            case .weight, .leanMass: return "kg"
            case .bmi: return ""
            case .heartRate: return "bpm"
            case .bodyFat, .spo2: return "%"
            case .vo2: return "ml/kg"
            case .resp: return "/min"
            case .bodyTemp: return "°C"
            case .fitnessLevel: return "pkt"
            }
        }
        
        var color: Color {
            switch self {
            case .weight: return .blue
            case .bmi: return .green
            case .heartRate: return .red
            case .bodyFat: return .orange
            case .leanMass: return .indigo
            case .vo2: return .teal
            case .resp: return .cyan
            case .spo2: return .mint
            case .bodyTemp: return .purple
            case .fitnessLevel: return .green
            }
        }
        
        var idKey: String {
             switch self {
             case .weight: return "weight"
             case .bmi: return "bmi"
             case .heartRate: return "hr"
             case .bodyFat: return "bodyFat"
             case .leanMass: return "leanMass"
             case .vo2: return "vo2"
             case .resp: return "resp"
             case .spo2: return "spo2"
             case .bodyTemp: return "temp"
             case .fitnessLevel: return "fitness"
             }
        }
    }
    
    // Calculated Score based on Sleep, Steps & Training
    struct MovoScoreBreakdown {
        let score: Int
        let status: String
        let sleepPoints: Int
        let sleepMax: Int = 40
        let sleepValue: Double
        
        let activityPoints: Int
        let activityMax: Int = 30
        let stepsValue: Int
        
        let trainingPoints: Int
        let trainingMax: Int = 20
        let hasWorkout: Bool
        
        let recoveryPoints: Int
        let recoveryMax: Int = 10
        // recovery value is just fixed for now
    }
    
    // Calculated Score based on Sleep, Steps & Training
    private var dailyMovoScore: MovoScoreBreakdown {
        let cal = Calendar.current
        
        // 1. Sleep Component (40%)
        // Check manual override for sleep
        let manualSleep = ManualBodyDataManager.shared.getMetric("sleep")
        let sleepHours: Double
        if let manual = manualSleep, cal.isDateInToday(manual.date) {
            sleepHours = manual.value
        } else {
            let sleepEntry = sleepHistory.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
            sleepHours = sleepEntry?.hours ?? 0.0
        }
        
        let sleepScoreRaw = min((sleepHours / 8.0), 1.1) * 100.0
        let sleepPoints = Int(sleepScoreRaw * 0.4)
        
        // 2. Activity Component (Steps) (30%)
        let stepsEntry = stepsHistory.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
        let steps = stepsEntry?.count ?? 0
        let stepsScoreRaw = min((Double(steps) / 8000.0), 1.2) * 100.0 
        let activityPoints = Int(stepsScoreRaw * 0.3)
        
        // 3. Training/Workout Component (20%)
        // Check if there's a workout on the selected date
        let hasWorkout = trainingStore.history.contains { entry in
            cal.isDate(entry.date, inSameDayAs: selectedDate)
        }
        let trainingPoints = hasWorkout ? 20 : 0
        
        // 4. Recovery (10%) - Baseline
        // 4. Recovery (10%) - HRV based
        // Use history for selected date, fallback to latest if same day/no history
        let hrvValue: Double
        if let entry = hrvHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
             hrvValue = entry.value
        } else if Calendar.current.isDateInToday(selectedDate) {
             hrvValue = healthKit.latestHRV ?? 0.0
        } else {
             hrvValue = 0.0 // No data for past date
        }
        
        // Simple normalization: > 60ms = 10, < 20ms = 2
        let recoveryRaw = hrvValue > 0 ? min(max((hrvValue - 20) / 4.0, 2), 10) : 5.0
        let recoveryPoints = Int(recoveryRaw)
        
        let total = Int(min(Double(sleepPoints + activityPoints + trainingPoints + recoveryPoints), 100))
        
        // Status Text
        let status: String
        switch total {
        case 90...: status = appSettings.localized("body.score.excellent")
        case 75..<90: status = appSettings.localized("body.score.strong")
        case 60..<75: status = appSettings.localized("body.score.good")
        default: status = appSettings.localized("body.score.recovery_needed")
        }
        
        return MovoScoreBreakdown(
            score: total,
            status: status,
            sleepPoints: sleepPoints,
            sleepValue: sleepHours,
            activityPoints: activityPoints,
            stepsValue: steps,
            trainingPoints: trainingPoints,
            hasWorkout: hasWorkout,
            recoveryPoints: recoveryPoints
        )
    }
    
    // Helper for Bottom Metrics String
    private var dailyMovoMetrics: (recovery: String, load: String, sleep: String) {
        let cal = Calendar.current
        
        // Sleep String
        // Check manual override for sleep
        let manualSleep = ManualBodyDataManager.shared.getMetric("sleep")
        let sleepHours: Double
        if let manual = manualSleep, cal.isDateInToday(manual.date) {
            sleepHours = manual.value
        } else {
            let sleepEntry = sleepHistory.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
            sleepHours = sleepEntry?.hours ?? 0.0
        }
        
        let h = Int(sleepHours)
        let m = Int((sleepHours - Double(h)) * 60)
        let sleepStr = sleepHours > 0 ? "\(h)h \(m)m" : "--"
        
        // Load String (Dynamic based on steps)
        let stepsEntry = stepsHistory.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
        let steps = stepsEntry?.count ?? 0
        let loadStr: String
        if steps > 12000 { loadStr = appSettings.localized("body.load.high") }
        else if steps > 6000 { loadStr = appSettings.localized("body.load.medium") }
        else { loadStr = appSettings.localized("body.load.low") }
        
        // Recovery String (Real HRV)
        let recoveryStr: String
        
        // Look up history first
        if let entry = hrvHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
            recoveryStr = "\(Int(entry.value)) ms"
        } else if Calendar.current.isDateInToday(selectedDate), let latest = healthKit.latestHRV {
            recoveryStr = "\(Int(latest)) ms"
        } else {
            recoveryStr = "--"
        }
        
        return (recoveryStr, loadStr, sleepStr)
    }

    // Day formatting
    private var dateTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return appSettings.localized("common.today")
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return appSettings.localized("common.yesterday")
        } else {
            let funcFormatter = DateFormatter()
            funcFormatter.dateFormat = "EEEE, d. MMM" // Longer format
            funcFormatter.locale = Locale(identifier: appSettings.language)
            return funcFormatter.string(from: selectedDate)
        }
    }

    var body: some View {
        Group {
            if embeddedInProfile {
                bodyContent
            } else {
                NavigationStack {
                    ScrollView {
                        bodyContent
                    }
                    .navigationTitle(appSettings.localized("tab.body"))
                    .navigationBarTitleDisplayMode(.inline)
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
        .sheet(isPresented: $showEditMetrics) {
            BodyMetricsEditView(visibleMetricsRaw: $visibleMetricsRaw)
        }
        .onAppear {
            loadBodyData()
        }
        .sheet(isPresented: $showScoreDetails) {
            ScoreDetailSheet(breakdown: dailyMovoScore)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSleepDetails) {
            SleepDetailSheet(sleepHistory: sleepHistory)
        }
        .sheet(item: $addMetricType) { metric in
            AddMetricSheet(metric: metric)
        }
        .sheet(item: $presentedMetric) { metric in
            let historyItems: [(Date, Double, String)] = {
                switch metric {
                case .weight: return weightHistory.map { ($0.date, $0.value, "Normal") }
                case .bmi: return bmiHistory.map { ($0.date, $0.value, "Normal") }
                case .heartRate: return hrHistory.map { ($0.date, $0.bpm, "Normal") }
                case .bodyFat: return bodyFatHistory.map { ($0.date, $0.value, "") }
                case .leanMass: return leanMassHistory.map { ($0.date, $0.value, "") }
                case .vo2: return vo2History.map { ($0.date, $0.value, "") }
                case .resp: return respHistory.map { ($0.date, $0.value, "") }
                case .spo2: return spo2History.map { ($0.date, $0.value, "") }
                case .bodyTemp: return tempHistory.map { ($0.date, $0.value, "") }
                case .fitnessLevel: return fitnessHistory.map { ($0.date, $0.value, $0.breakdown) }
                }
            }()

            MetricDetailView(
                title: metric.title(with: appSettings),
                unit: metric.unit,
                color: metric.color,
                history: historyItems,
                onAdd: {
                    addMetricType = metric
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            )
        }
    }

    private var bodyContent: some View {
        VStack(spacing: embeddedInProfile ? 16 : 24) {
                    
                    if !embeddedInProfile {
                        // MARK: - Date Navigation Header (Minimalist)
                        HStack(spacing: 16) {
                            Button(action: {
                                changeDate(by: -1)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }

                            HStack(spacing: 6) {
                                 Image(systemName: "calendar")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                 Text(dateTitle)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)
                            }
                            .onTapGesture {
                                selectedDate = Date()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }

                            Button(action: {
                                changeDate(by: 1)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Calendar.current.isDateInToday(selectedDate) ? .tertiary : .secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .disabled(Calendar.current.isDateInToday(selectedDate))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // 1. Movo Score (Interactive)
                        Button(action: {
                            showScoreDetails = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            MovoScoreView(
                                score: dailyMovoScore.score,
                                status: dailyMovoScore.status,
                                recoveryValue: dailyMovoMetrics.recovery,
                                loadValue: dailyMovoMetrics.load,
                                sleepValue: dailyMovoMetrics.sleep,
                                breakdown: dailyMovoScore,
                                isLoading: isLoading
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal)

                        // 2. Sleep Analysis (Interactive)
                        Button(action: {
                            showSleepDetails = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            SleepAnalysisCard(selectedDate: $selectedDate, sleepHistory: sleepHistory)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal)
                    } else {
                        profileBodySnapshot
                    }
                    
                    // 2.4 Trained Areas (Muscle Map)
                    MuscleMapSummary(
                        loadThisWeek: muscleLoadThisWeek,
                        loadLastWeek: muscleLoadLastWeek
                    )
                        .padding(.horizontal)

                    // 2.5 Body Recovery Analysis
                    if !embeddedInProfile {
                        BodyRecoverySection()
                            .padding(.bottom, 8)
                    }




                    // 3. Körpermetriken (Legacy Metrics)
                    // Note: Metrics usually show "Latest" only, but ideally should show history for selectedDate.
                    // For now, we keep "Latest" but title it "Status".
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(appSettings.localized("body.title")) // "Körperstatus"
                                .font(.title3.weight(.bold))
                            
                            Spacer()
                            
                            Button(action: {
                                showEditMetrics = true
                            }) {
                                Text(appSettings.localized("common.edit"))
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            if visibleMetrics.contains("fitnessLevel") {
                                Button {
                                     presentedMetric = .fitnessLevel
                                     UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "fitness",
                                        title: appSettings.localized("body.metric.fitness"), // "Fitnessniveau"
                                        val: Double(dailyMovoScore.activityPoints + dailyMovoScore.trainingPoints),
                                        unit: "pkt",
                                        icon: "figure.run",
                                        color: .green,
                                        history: fitnessHistory.map { ($0.date, $0.value) }, 
                                        fraction: 0
                                    )
                                }
                            }
                            
                            if visibleMetrics.contains("weight") {
                                Button {
                                    presentedMetric = .weight
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "weight",
                                        title: appSettings.localized("body.metric.weight"), // "Gewicht"
                                        val: healthKit.latestWeight,
                                        unit: "kg",
                                        icon: "scalemass.fill",
                                        color: .blue,
                                        history: weightHistory.map { ($0.date, $0.value) }
                                    )
                                }
                            }
                            
                            if visibleMetrics.contains("bmi") {
                                Button {
                                    presentedMetric = .bmi
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    // Use local calculation if HK is empty
                                    let bmiValue = healthKit.latestBMI ?? calculateBMI()
                                    metricCard(
                                        id: "bmi",
                                        title: appSettings.localized("body.metric.bmi"), // "BMI"
                                        val: bmiValue,
                                        unit: "",
                                        icon: "number.circle.fill",
                                        color: .green,
                                        history: bmiHistory
                                    )
                                }
                            }
                            
                            if visibleMetrics.contains("bodyFat") {
                                Button {
                                    presentedMetric = .bodyFat
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "bodyFat",
                                        title: appSettings.localized("body.metric.fat"), // "Körperfett"
                                        val: healthKit.latestBodyFatPercent,
                                        unit: "%",
                                        icon: "percent",
                                        color: .orange,
                                        history: bodyFatHistory
                                    )
                                }
                            }
                            
                            if visibleMetrics.contains("leanMass") {
                                Button {
                                    presentedMetric = .leanMass
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "leanMass",
                                        title: appSettings.localized("body.metric.leanMass"), // "Magermasse"
                                        val: healthKit.latestLeanBodyMass,
                                        unit: "kg",
                                        icon: "figure.arms.open",
                                        color: .indigo,
                                        history: leanMassHistory
                                    )
                                }
                            }
                            
                            if visibleMetrics.contains("hr") {
                                Button {
                                    presentedMetric = .heartRate
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "hr",
                                        title: appSettings.localized("body.metric.hr"), // "Ruhepuls"
                                        val: healthKit.latestRestingHeartRate,
                                        unit: "bpm",
                                        icon: "heart.fill",
                                        color: .red,
                                        history: hrHistory.map { ($0.date, $0.bpm) }, 
                                        fraction: 0
                                    )
                                }
                            }
                            
                            if visibleMetrics.contains("vo2") {
                                Button {
                                    presentedMetric = .vo2
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "vo2",
                                        title: appSettings.localized("body.metric.vo2"),
                                        val: healthKit.latestVO2Max,
                                        unit: "ml/kg",
                                        icon: "lungs.fill",
                                        color: .teal,
                                        history: vo2History
                                    )
                                }

                            }
                            
                            if visibleMetrics.contains("resp") {
                                Button {
                                    presentedMetric = .resp
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "resp",
                                        title: appSettings.localized("body.metric.resp"),
                                        val: healthKit.latestRespiratoryRate,
                                        unit: "/min",
                                        icon: "wind",
                                        color: .cyan,
                                        history: respHistory
                                    )
                                }

                            }
                            
                            if visibleMetrics.contains("spo2") {
                                Button {
                                    presentedMetric = .spo2
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "spo2",
                                        title: appSettings.localized("body.metric.spo2"),
                                        val: healthKit.latestOxygenSaturation,
                                        unit: "%",
                                        icon: "drop.fill",
                                        color: .mint,
                                        history: spo2History,
                                        fraction: 0
                                    )
                                }

                            }
                            
                            if visibleMetrics.contains("temp") {
                                // Wrist Temp / Body Temp
                                Button {
                                    presentedMetric = .bodyTemp
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    metricCard(
                                        id: "temp",
                                        title: appSettings.localized("body.metric.temp"),
                                        val: healthKit.latestWristTemperature,
                                        unit: "°C",
                                        icon: "thermometer.medium",
                                        color: .purple,
                                        history: tempHistory
                                    )
                                }

                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: embeddedInProfile ? 0 : 50)
                }
                .padding(.vertical)
    }

    private var profileBodySnapshot: some View {
        HStack(spacing: 12) {
            profileSnapshotItem(
                icon: "scalemass.fill",
                title: appSettings.localized("body.metric.weight"),
                value: formattedSnapshotValue(healthKit.latestWeight, unit: "kg")
            )
            profileSnapshotItem(
                icon: "figure.walk",
                title: appSettings.localized("steps.title"),
                value: "\(dailyMovoScore.stepsValue)"
            )
        }
        .padding(.horizontal)
    }

    private func profileSnapshotItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(t.palette.primary)
                .frame(width: 34, height: 34)
                .background(t.palette.primary.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func formattedSnapshotValue(_ value: Double?, unit: String) -> String {
        guard let value else { return "--" }
        return "\(String(format: "%.1f", value)) \(unit)"
    }

    private func loadBodyData() {
        healthKit.refreshAll()
        healthKit.fetchSleepHistory(days: 30) { entries in
            self.sleepHistory = entries
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                 self.isLoading = false
            }
        }
        healthKit.fetchStepsHistory(days: 30) { entries in
            self.stepsHistory = entries
            self.computeFitnessHistory()
        }
        healthKit.fetchHRVHistory(days: 30) { entries in
            self.hrvHistory = entries
        }
        healthKit.fetchWeightHistory(days: 90) { entries in
            self.weightHistory = entries
        }
        healthKit.fetchRestingHRHistory(days: 30) { entries in
            self.hrHistory = entries
        }

        healthKit.fetchQuantityHistory(for: .bodyFatPercentage, days: 90, unit: .percent()) { res in
            self.bodyFatHistory = res.map { ($0.date, $0.value * 100) }
        }
        healthKit.fetchQuantityHistory(for: .leanBodyMass, days: 365, unit: .gramUnit(with: .kilo)) { res in
            self.leanMassHistory = res
        }
        healthKit.fetchQuantityHistory(for: .bodyMassIndex, days: 365, unit: .count()) { res in
            self.bmiHistory = res
        }
        healthKit.fetchQuantityHistory(for: .vo2Max, days: 365, unit: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))) { res in
            self.vo2History = res
        }
        healthKit.fetchQuantityHistory(for: .respiratoryRate, days: 30, unit: HKUnit.count().unitDivided(by: .minute())) { res in
            self.respHistory = res
        }
        healthKit.fetchQuantityHistory(for: .oxygenSaturation, days: 30, unit: .percent()) { res in
            self.spo2History = res.map { ($0.date, $0.value * 100) }
        }

        if #available(iOS 16.0, *) {
            healthKit.fetchQuantityHistory(for: .appleSleepingWristTemperature, days: 30, unit: .degreeCelsius()) { res in
                self.tempHistory = res
            }
        }
    }
    
    
    
    // Helper to render card with safe defaults & trend calculation
    private func metricCard(id: String, title: String, val: Double?, unit: String, icon: String, color: Color, history: [(Date, Double)] = [], fraction: Int = 1, isLocked: Bool = false) -> some View {
        // Check Manual Data Override
        let manual = ManualBodyDataManager.shared.getMetric(id)
        
        let finalVal: Double?
        if let manual = manual, Calendar.current.isDateInToday(manual.date) {
            finalVal = manual.value
        } else {
            finalVal = val
        }
        
        let hasData = finalVal != nil
        let valueStr = hasData ? String(format: "%.\(fraction)f", finalVal!) : "--"
        
        let statusColor = hasData ? Color.green : Color.secondary
        
        // Comparison Logic
        var comparisonText: String = ""
        if hasData, finalVal! > 0, !history.isEmpty {
            // Find previous entry (not today)
            let sorted = history.sorted { $0.0 < $1.0 }
            
            // Should really ignore today's value if present in history to find "previous"
            // But usually history ends with today/latest. 
            // We want the last entry that is NOT today.
            if let prev = sorted.last(where: { !Calendar.current.isDateInToday($0.0) }) {
                let dateStr = DateFormatter.localizedString(from: prev.0, dateStyle: .short, timeStyle: .none)
                comparisonText = "\(appSettings.localized("common.last")): \(String(format: "%.\(fraction)f", prev.1)) \(unit) (\(dateStr))"
            } else {
                comparisonText = appSettings.localized("common.first_measurement")
            }
        }
        
        // Status Logic Refinement
        let finalStatus: String
        let metricEnum = MetricType.allCases.first { $0.idKey == id } 
        
        if id == "bmi" && hasData {
             let b = finalVal!
             if b < 18.5 { finalStatus = appSettings.localized("body.status.underweight") }
             else if b < 25 { finalStatus = appSettings.localized("body.status.normal") }
             else if b < 30 { finalStatus = appSettings.localized("body.status.overweight") }
             else { finalStatus = appSettings.localized("body.status.obese") }
        } else {
             finalStatus = "" 
        }
        
        return BodyMetricCard(
            title: title,
            value: valueStr,
            unit: unit,
            icon: icon,
            color: color,
            status: finalStatus,
            statusColor: statusColor,
            comparisonText: comparisonText,
            history: history,
            isLocked: isLocked
        )
    }
    private func changeDate(by days: Int) {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        }
    }
    
    private func computeFitnessHistory() {
        let cal = Calendar.current
        let today = Date()
        var history: [(date: Date, value: Double, breakdown: String)] = []
        
        // Past 30 days
        for i in 0..<30 {
            if let date = cal.date(byAdding: .day, value: -i, to: today) {
                // Steps
                let stepsEntry = stepsHistory.first { cal.isDate($0.date, inSameDayAs: date) }
                let steps = Double(stepsEntry?.count ?? 0)
                let activityPoints = min((steps / 8000.0), 1.2) * 30.0
                
                // Training
                let hasWorkout = trainingStore.history.contains { cal.isDate($0.date, inSameDayAs: date) }
                let trainingPoints = hasWorkout ? 20.0 : 0.0
                
                let total = activityPoints + trainingPoints
                let breakdown = "S: \(Int(activityPoints)) | T: \(Int(trainingPoints))"
                history.append((date, total, breakdown))
            }
        }
        self.fitnessHistory = history.sorted { $0.date < $1.date }
    }
    
    private func calculateBMI() -> Double? {
        guard let weight = healthKit.latestWeight, weight > 0, heightCm > 0 else { return nil }
        let heightM = heightCm / 100.0
        return weight / (heightM * heightM)
    }
    


    }


// MARK: - Styles & Details

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ScoreDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings // Added
    let breakdown: BodyView.MovoScoreBreakdown
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Score
                    VStack(spacing: 8) {
                        Text("\(breakdown.score)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(breakdown.score))
                        Text(breakdown.status)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)
                    
                    VStack(spacing: 16) {
                        Text(appSettings.localized("score.breakdown")) // "Zusammensetzung"
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        // 1. Sleep
                        scoreRow(
                            title: appSettings.localized("score.sleep"), // "Schlaf"
                            subtitle: appSettings.localized("score.detail.durationQuality"), // "Dauer & Qualität"
                            value: "\(breakdown.sleepPoints)/\(breakdown.sleepMax)",
                            detail: String(format: appSettings.localized("score.detail.slept"), breakdown.sleepValue), // "%.1fh geschlafen"
                            color: .purple
                        )
                        
                        // 2. Activity
                        scoreRow(
                            title: appSettings.localized("score.activity"), // "Aktivität"
                            subtitle: appSettings.localized("score.detail.stepsMovement"), // "Schritte & Bewegung"
                            value: "\(breakdown.activityPoints)/\(breakdown.activityMax)",
                            detail: String(format: appSettings.localized("score.detail.steps"), breakdown.stepsValue), // "%d Schritte"
                            color: .green
                        )
                        
                        // 3. Training
                        scoreRow(
                            title: appSettings.localized("score.training"), // "Training"
                            subtitle: appSettings.localized("score.detail.workouts"), // "Workouts"
                            value: "\(breakdown.trainingPoints)/\(breakdown.trainingMax)",
                            detail: breakdown.hasWorkout ? appSettings.localized("score.detail.trainingDone") : appSettings.localized("score.detail.noTraining"), // "Training absolviert" / "Kein Training"
                            color: .blue
                        )
                        
                        // 4. Recovery
                        scoreRow(
                            title: appSettings.localized("score.recovery") + " (HRV)", // "Erholung (HRV)"
                            subtitle: appSettings.localized("score.detail.stressRegeneration"), // "Stress & Regeneration"
                            value: "\(breakdown.recoveryPoints)/\(breakdown.recoveryMax)",
                            detail: appSettings.localized("score.detail.baseline"), // "Basiswert"
                            color: .orange
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    Text(appSettings.localized("score.detail.description")) // "Dein Movo Score basiert..."
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(appSettings.localized("score.detail.navTitle")) // "Score Details"
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("profile.close")) { dismiss() } // "Schließen"
                }
            }
        }
    }
    
    private func scoreRow(title: String, subtitle: String, value: String, detail: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).bold()
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(value).bold().foregroundStyle(color)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...: return .green
        case 75..<90: return .blue
        case 60..<75: return .orange
        default: return .red
        }
    }
}

struct SleepDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    var sleepHistory: [HealthKitManager.SleepEntry]
    
    var metricHistory: [(date: Date, value: Double, status: String)] {
        sleepHistory.map { entry in
            let status: String
            if entry.hours > 7.5 { status = "Optimal" }
            else if entry.hours > 6.0 { status = "Okay" }
            else { status = "Niedrig" }
            return (entry.date, entry.hours, status)
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        MetricDetailView(
            title: "Schlaf",
            unit: "h",
            color: .purple,
            history: metricHistory
        )
    }
}

// MARK: - Edit Sheet
    // MARK: - Edit Sheet
    struct BodyMetricsEditView: View {
        @Binding var visibleMetricsRaw: String
        @Environment(\.dismiss) var dismiss
        @Environment(\.designTokens) private var t
        @EnvironmentObject var appSettings: AppSettings // Added
        
        // Available metrics mapping
        var allMetrics: [(String, String)] {
            [
                ("weight", appSettings.localized("body.metric.weight")),
                ("bmi", appSettings.localized("body.metric.bmi")),
                ("hr", appSettings.localized("body.metric.hr")),
                ("vo2", appSettings.localized("body.metric.vo2")),
                ("resp", appSettings.localized("body.metric.resp")),
                ("spo2", appSettings.localized("body.metric.spo2")),
                ("temp", appSettings.localized("body.metric.temp")),
                ("fitnessLevel", appSettings.localized("body.metric.fitness"))
            ]
        }
        
        @State private var selection: Set<String> = []
        
        var body: some View {
            NavigationStack {
                List {
                    Section {
                        ForEach(allMetrics, id: \.0) { item in
                            HStack {
                                Text(item.1)
                                Spacer()
                                if selection.contains(item.0) {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selection.contains(item.0) {
                                    selection.remove(item.0)
                                } else {
                                    selection.insert(item.0)
                                }
                            }
                        }
                    } footer: {
                        Text(appSettings.localized("body.edit.description")) // "Wähle die Metriken aus..."
                    }
                }
                .navigationTitle(appSettings.localized("body.edit.title")) // "Bearbeiten"
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(appSettings.localized("body.edit.done")) { // "Fertig"
                            save()
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    selection = Set(visibleMetricsRaw.split(separator: ",").map { String($0) })
                }
            }
        }
        
        private func save() {
            visibleMetricsRaw = selection.joined(separator: ",")
        }
    }

    // MARK: - Redesigned Metric Card with Sparkline
    struct BodyMetricCard: View {
        let title: String
        let value: String
        let unit: String
        let icon: String
        let color: Color
        
        // Status & History
        let status: String
        let statusColor: Color
        let comparisonText: String
        let history: [(Date, Double)]
        var isLocked: Bool = false  // Premium lock indicator
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                            .font(.headline)
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Content Row
                HStack(alignment: .bottom, spacing: 0) {
                    // Left: Value & Status
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(value)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(unit)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Status Badge (Only shows if status is not empty)
                        if !status.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(statusColor)
                                Text(status)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(statusColor)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Right: Sparkline
                    if !history.isEmpty {
                        Chart(history, id: \.0) { item in
                            LineMark(
                                x: .value("Date", item.0),
                                y: .value("Value", item.1)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .foregroundStyle(color)
                            
                            AreaMark(
                                x: .value("Date", item.0),
                                y: .value("Value", item.1)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [color.opacity(0.2), color.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(width: 100, height: 50)
                    }
                }
                
                // Footer: Comparison
                HStack(spacing: 4) {
                    let parts = comparisonText.components(separatedBy: " ")
                    if let arrow = parts.first, ["↑", "↓", "=", "→"].contains(arrow) {
                         Text(arrow).bold() // Make arrow bold
                         Text(parts.dropFirst().joined(separator: " "))
                    } else {
                         Text(comparisonText)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                if isLocked {
                    ZStack {
                        Color.black.opacity(0.4)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            Spacer()
                        }
                        .padding(12)
                    }
                }
            }
            .opacity(isLocked ? 0.7 : 1.0)
        }
    }

// MARK: - Helper Logic (Internal)
struct BodyViewHelper {
    static func filterHistory(_ entries: [TrainingEntry], days: Int) -> [TrainingEntry] {
        let now = Date()
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: now) else { return [] }
        let startOfDay = cal.startOfDay(for: start)
        return entries.filter { $0.date >= startOfDay }
    }
    
    static func filterHistory(_ entries: [TrainingEntry], offsetDays: Int, durationDays: Int) -> [TrainingEntry] {
        let now = Date()
        let cal = Calendar.current
        guard let end = cal.date(byAdding: .day, value: -offsetDays, to: now),
              let start = cal.date(byAdding: .day, value: -durationDays, to: end) else { return [] }
        
        let startOfDay = cal.startOfDay(for: start)
        let endOfDay = cal.startOfDay(for: end)
        
        return entries.filter { $0.date >= startOfDay && $0.date < endOfDay }
    }
    
    static func calculateMuscleLoad(from entries: [TrainingEntry]) -> [MuscleRegion: Double] {
        var acc: [MuscleRegion: Double] = [:]
        for entry in entries {
            for ex in entry.exercises {
                // Reuse existing MuscleMappingHelper if public, otherwise we might need to duplicate parsing logic.
                // Assuming MuscleMappingHelper is public based on previous view_file.
                let name = ex.name.trimmingCharacters(in: .whitespacesAndNewlines)
                // Need sets logic
                let volumeKg = ex.sets.reduce(0.0) { sum, s in
                    sum + (parseKg(s.weight) * Double(parseInt(s.reps)))
                }
                
                for r in MuscleMappingHelper.regions(forExerciseName: name) {
                    acc[r, default: 0] += volumeKg
                }
            }
        }
        return acc
    }
    
    // Parsing helpers duplicated locally to ensure safety if StatisticsView's are private
    private static func parseKg(_ s: String) -> Double {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        if let n = nf.number(from: trimmed) { return n.doubleValue }
        if let d = Double(trimmed.replacingOccurrences(of: ",", with: ".")) { return d }
        return 0
    }
    
    private static func parseInt(_ s: String) -> Int {
        Int(s.filter("0123456789".contains)) ?? 0
    }
}

// MARK: - Manual Data Manager

class ManualBodyDataManager: ObservableObject {
    static let shared = ManualBodyDataManager()
    
    @AppStorage("manual.hydration") var hydrationCount: Int = 0
    @AppStorage("manual.hydration.date") var hydrationDate: Double = Date().timeIntervalSince1970
    
    @AppStorage("manual.checkin.score") var checkInScore: Double = 5.0
    @AppStorage("manual.checkin.date") var checkInDate: Double = Date().timeIntervalSince1970
    
    func getHydration(for date: Date) -> Int {
        if Calendar.current.isDate(Date(timeIntervalSince1970: hydrationDate), inSameDayAs: date) {
            return hydrationCount
        }
        return 0
    }
    
    func addHydration() {
        let now = Date()
        if !Calendar.current.isDate(Date(timeIntervalSince1970: hydrationDate), inSameDayAs: now) {
            hydrationCount = 0
            hydrationDate = now.timeIntervalSince1970
        }
        hydrationCount += 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func getCheckIn(for date: Date) -> Double? {
        if Calendar.current.isDate(Date(timeIntervalSince1970: checkInDate), inSameDayAs: date) {
            return checkInScore
        }
        return nil
    }
    
    func setCheckIn(_ val: Double) {
        checkInScore = val
        checkInDate = Date().timeIntervalSince1970
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // Generic Metrics
    func saveMetric(_ id: String, value: Double) {
        UserDefaults.standard.set(value, forKey: "manual_metric_\(id)")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "manual_date_\(id)")
        // Trigger manual update notification if needed? 
    }
    
    func getMetric(_ id: String) -> (value: Double, date: Date)? {
        guard UserDefaults.standard.object(forKey: "manual_metric_\(id)") != nil else { return nil }
        let val = UserDefaults.standard.double(forKey: "manual_metric_\(id)")
        let dateVal = UserDefaults.standard.double(forKey: "manual_date_\(id)")
        return (val, Date(timeIntervalSince1970: dateVal))
    }
}

// MARK: - New Cards
