import SwiftUI
import Charts

struct MuscleDistributionChart: View {
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t
    
    // Zeitfilter
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Woche"
        case month = "Monat"
        case all = "Gesamt"
        var id: String { rawValue }
        
        var localizedKey: String {
            switch self {
            case .week: return "range.7days"
            case .month: return "range.30days"
            case .all: return "range.allTime"
            }
        }
    }
    
    @State private var selection: TimeRange = .month
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(appSettings.localized("stats.muscleDistribution")) // "Muskelverteilung"
                    .font(.headline)
                Spacer()
                
                Picker("", selection: $selection) {
                    ForEach(TimeRange.allCases) { range in
                        Text(appSettings.localized(range.localizedKey)).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
            .padding(.horizontal)
            
            if dataPoints.isEmpty {
                ContentUnavailableView(
                    appSettings.localized("stats.noData"),
                    systemImage: "chart.pie",
                    description: Text(appSettings.localized("stats.noDataDesc"))
                )
                .frame(height: 250)
            } else {
                Chart(dataPoints, id: \.region) { item in
                    SectorMark(
                        angle: .value("Reps", item.reps),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Region", localizedRegionName(item.region)))
                    .cornerRadius(5)
                }
                .chartLegend(position: .bottom, spacing: 20)
                .frame(height: 250)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Data Calculation
    
    private struct DataPoint {
        let region: MuscleRegion
        let reps: Int
    }
    
    private var dataPoints: [DataPoint] {
        let cutoff: Date? = {
            switch selection {
            case .week: return Calendar.current.date(byAdding: .day, value: -7, to: Date())
            case .month: return Calendar.current.date(byAdding: .day, value: -30, to: Date())
            case .all: return nil
            }
        }()
        
        // 1. Filter History
        let filtered = trainingStore.history.filter {
            if let c = cutoff { return $0.date >= c }
            return true
        }
        
        // 2. Aggregate Reps per Region
        var map: [MuscleRegion: Int] = [:]
        
        for entry in filtered {
            for ex in entry.exercises {
                // Determine Region
                // Use Library or Name fallback?
                // The implementation in BodyRecovery uses standard lookup.
                let region = resolveRegion(for: ex.name)
                
                // Sum reps (Parse String to Int)
                let reps = ex.sets.reduce(0) { sum, set in
                    let val = Int(set.reps.filter("0123456789".contains)) ?? 0
                    return sum + val
                }
                map[region, default: 0] += reps
            }
        }
        
        // 3. Convert to Sorted List & Limit
        let sorted = map.sorted { $0.value > $1.value }
        // Maybe prefix(6) + "Other"? For now show all, usually distinct regions are few (Chest, Back, Legs...)
        
        return sorted.map { DataPoint(region: $0.key, reps: $0.value) }
    }
    
    private func resolveRegion(for name: String) -> MuscleRegion {
        if let info = exerciseLibrary.exerciseInfo(for: name) {
            return mapLibraryMuscleToRegion(info.muscleGroup)
        }
        return mapRefinedMuscle(for: name) ?? .chest // Fallback? Or create .unknown?
        // Let's use BodyRecovery logic if accessible, or replicate minimal logic.
    }
    
    // Helper Copy from BodyRecoverySection (since it's private there likely)
    // Ideally this should be Shared Helper.
    private func mapLibraryMuscleToRegion(_ muscle: String) -> MuscleRegion {
        switch muscle {
        case "Chest": return .chest
        case "Back": return .lats // "Back" is broad, mapping to lats as primary
        case "Legs": return .quads // "Legs" -> Quads as approximation
        case "Shoulders": return .shoulders
        case "Biceps": return .biceps
        case "Triceps": return .triceps
        case "Abs", "Core": return .abs
        case "Full Body": return .abs // Best fit?
        case "Lower Back": return .lowerBack
        case "Glutes": return .glutes
        case "Hamstrings": return .hamstrings
        case "Calves": return .calves
        case "Traps": return .traps
        case "Forearms": return .forearms
        case "Rear Delts": return .shoulders
        default: return .chest // Fallback
        }
    }
    
    private func mapRefinedMuscle(for name: String) -> MuscleRegion? {
        let n = name.lowercased()
        if n.contains("bank") || n.contains("bench") || n.contains("chest") || n.contains("brust") { return .chest }
        if n.contains("lat") || n.contains("row") || n.contains("ruder") || n.contains("pull") || n.contains("back") { return .lats }
        if n.contains("squat") || n.contains("knie") || n.contains("leg") || n.contains("bein") { return .quads }
        if n.contains("shoulder") || n.contains("schulter") || n.contains("overhead") || n.contains("press") { return .shoulders }
        if n.contains("curl") || n.contains("bizeps") { return .biceps }
        if n.contains("trizeps") || n.contains("tricep") { return .triceps }
        return nil
    }
    
    private func localizedRegionName(_ region: MuscleRegion) -> String {
        let key = "muscle.region.\(region.rawValue)"
        let val = appSettings.localized(key)
        if val != key { return val }
        return region.rawValue.capitalized
    }
}
