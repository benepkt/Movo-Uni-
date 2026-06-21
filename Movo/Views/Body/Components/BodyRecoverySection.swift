import SwiftUI

struct BodyRecoverySection: View {
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var appSettings: AppSettings // Added
    @Environment(\.designTokens) private var t
    
    // View State
    @State private var useMapView = false
    @State private var selectedMuscle: MuscleStatus? = nil
    
    // Recovery Status Enum
    enum RecoveryStatus {
        case recovering // 0-24h
        case good       // 24-48h
        case ready      // 48-72h
        case peak       // 72-96h
        case idle       // > 96h
        
        func title(with appSettings: AppSettings) -> String {
            switch self {
            case .recovering: return appSettings.localized("body.recovery.status.recovering")
            case .good: return appSettings.localized("body.recovery.status.good")
            case .ready: return appSettings.localized("body.recovery.status.ready")
            case .peak: return appSettings.localized("body.recovery.status.peak")
            case .idle: return appSettings.localized("body.recovery.status.idle")
            }
        }
        
        var color: Color {
            switch self {
            case .recovering: return .red
            case .good: return .orange
            case .ready: return Color(hex: 0x32ADE6) // Teal-ish
            case .peak: return .green
            case .idle: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .recovering: return "battery.25"
            case .good: return "battery.50"
            case .ready: return "battery.75"
            case .peak: return "battery.100"
            case .idle: return "figure.run"
            }
        }
    }
    
    struct MuscleStatus: Identifiable {
        let id = UUID()
        let name: String
        let region: MuscleRegion? // Optional, nil implies no direct mapping to figure
        let status: RecoveryStatus
        let daysSince: Int
        let hoursSince: Int
        
        // Progress 0.0 to 1.0 (Full recovery at 96h)
        var recoveryProgress: Double {
            let p = Double(hoursSince) / 96.0
            return min(p, 1.0)
        }
    }
    
    // Computed Recovery Data
    private var muscleStatuses: [MuscleStatus] {
        var lastTrainedName: [String: Date] = [:]
        var lastTrainedRegion: [MuscleRegion: Date] = [:]
        
        // Iterate through history to find last training date for each muscle
        for entry in trainingStore.history {
            for exercise in entry.exercises {
                // 1. Try ExerciseLibrary Lookup
                let muscleName: String
                var region: MuscleRegion? = nil
                
                if let info = exerciseLibrary.exerciseInfo(for: exercise.name) {
                    muscleName = mapLibraryMuscleToDisplay(info.muscleGroup)
                    region = mapLibraryMuscleToRegion(info.muscleGroup)
                } else {
                    // 2. Fallback to Name Check
                    muscleName = mainMuscle(for: exercise.name)
                    region = mapRefinedMuscle(for: exercise.name)
                }
                
                // Only track main groups for cleanliness
                if !["Ganzkörper", "Unbekannt"].contains(muscleName) {
                    if let currentLast = lastTrainedName[muscleName] {
                        if entry.date > currentLast {
                            lastTrainedName[muscleName] = entry.date
                        }
                    } else {
                        lastTrainedName[muscleName] = entry.date
                    }
                    
                    if let r = region {
                        if let currentLast = lastTrainedRegion[r] {
                            if entry.date > currentLast {
                                lastTrainedRegion[r] = entry.date
                            }
                        } else {
                            lastTrainedRegion[r] = entry.date
                        }
                    }
                }
            }
        }
        
        let now = Date()
        
        // Map Name-Based Statuses (For List View)
        let listStatuses = lastTrainedName.map { (muscle, date) in
            createStatus(name: muscle, date: date, now: now, region: nil) // Region mostly irrelevant for list, but name is crucial
        }
        
        // Map Region-Based Statuses (For Map View Visualization)
        // We use this to return "complete" statuses where region is populated
        // But to avoid duplicates in the LIST, we might need to be careful.
        // Actually, for the simplified architecture:
        // We will return statuses based on region if possible, else name.
        
        // BETTER APPROACH: Return strict list for Cards, and compute Map Colors separately in view.
        // But to use `ForEach` cleanly, let's just return the list-friendly statuses (Name based),
        // and attach the `region` if we can back-map it or if we saved it.
        // The `lastTrainedName` loop above captures the display name.
        // Let's deduce the region from the display name for the map.
        
        return listStatuses.map { s in
             // Try to back-fill region from display name if missing
            var copy = s
            // This is a bit "fuzzy", but sufficient for the map coloring
            if copy.region == nil {
                // Re-map display name to region?
                // Or easier: use the dictionary approach directly in the View.
            }
            return copy
        }.sorted { $0.hoursSince < $1.hoursSince }
    }
    
    // Computed Map Colors
    private var mapRegionColors: [MuscleRegion: Color] {
        var colors: [MuscleRegion: Color] = [:]
        // We need to re-scan history or use `muscleStatuses`.
        // Ideally we used the `lastTrainedRegion` logic.
        
        var lastTrainedRegion: [MuscleRegion: Date] = [:]
        for entry in trainingStore.history {
            for exercise in entry.exercises {
                var region: MuscleRegion? = nil
                if let info = exerciseLibrary.exerciseInfo(for: exercise.name) {
                    region = mapLibraryMuscleToRegion(info.muscleGroup)
                } else {
                    region = mapRefinedMuscle(for: exercise.name)
                }
                
                if let r = region {
                    if let currentLast = lastTrainedRegion[r] {
                        if entry.date > currentLast { lastTrainedRegion[r] = entry.date }
                    } else {
                        lastTrainedRegion[r] = entry.date
                    }
                }
            }
        }
        
        let now = Date()
        for (region, date) in lastTrainedRegion {
             let status = createStatus(name: "", date: date, now: now, region: region)
             colors[region] = status.status.color
            
            
        }
        
        return colors
    }

    private func createStatus(name: String, date: Date, now: Date, region: MuscleRegion?) -> MuscleStatus {
        let hours = Int(now.timeIntervalSince(date) / 3600)
        let days = hours / 24
        
        let status: RecoveryStatus
        if hours < 24 { status = .recovering }
        else if hours < 48 { status = .good }
        else if hours < 72 { status = .ready }
        else if hours < 96 { status = .peak }
        else { status = .idle }
        
        return MuscleStatus(name: name, region: region, status: status, daysSince: days, hoursSince: hours)
    }

    // Map Library Muscle Group (English/German mix) to Display Name (German)
    // Map Library Muscle Group (English/German mix) to Display Name (Localized)
    // Map Library Muscle Group (English/German mix) to Display Name (Localized)
    private func mapLibraryMuscleToDisplay(_ libGroup: String) -> String {
        let g = libGroup.lowercased()
        
        // English mappings from ExerciseLibrary
        if g.contains("chest") || g.contains("brust") || g.contains("pec") { return appSettings.localized("muscle.chest") }
        if g.contains("back") || g.contains("rücken") || g.contains("lat") || g.contains("trap") || g.contains("neck") || g.contains("nacken") { return appSettings.localized("muscle.back") } // Summarize Back/Traps/Neck
        if g.contains("leg") || g.contains("bein") || g.contains("quad") || g.contains("hamstring") || g.contains("glu") || g.contains("calf") || g.contains("waden") || g.contains("adduc") || g.contains("abduc") { return appSettings.localized("muscle.legs") }
        if g.contains("shoulder") || g.contains("schulter") || g.contains("delt") { return appSettings.localized("muscle.shoulders") }
        if g.contains("bicep") || g.contains("bizeps") { return appSettings.localized("muscle.biceps") }
        if g.contains("tricep") || g.contains("trizeps") { return appSettings.localized("muscle.triceps") }
        if g.contains("abs") || g.contains("core") || g.contains("bauch") { return appSettings.localized("muscle.abs") }
        if g.contains("forearm") || g.contains("unterarm") { return appSettings.localized("muscle.forearms") }
        
        // Specific checks if not caught above
        if g == "traps" || g == "nacken" { return appSettings.localized("muscle.traps") }
        
        return appSettings.localized("muscle.unknown")
    }

    // New: Map to MuscleRegion Enum for Figure
    private func mapLibraryMuscleToRegion(_ libGroup: String) -> MuscleRegion? {
        let g = libGroup.lowercased()
        if g == "chest" || g.contains("brust") { return .chest }
        if g == "shoulders" || g.contains("schulter") { return .shoulders }
        if g == "biceps" || g.contains("bizeps") { return .biceps }
        if g == "triceps" || g.contains("trizeps") { return .triceps }
        if g == "lats" || g.contains("latissimus") { return .lats }
        if g.contains("rücken") || g.contains("back") { return .lowerBack } // Slight simplification
        if g.contains("abs") || g.contains("bauch") || g.contains("core") { return .abs }
        if g.contains("quads") || g.contains("beinstrecker") { return .quads }
        if g.contains("hamstring") || g.contains("beinbeuger") { return .hamstrings }
        if g.contains("glutes") || g.contains("gesäß") { return .glutes }
        if g.contains("calves") || g.contains("waden") { return .calves }
        if g.contains("forearm") || g.contains("unterarm") { return .forearms }
        if g.contains("trap") || g.contains("nacken") { return .traps }
        // Generic "Legs" -> Quads default
        if g == "legs" || g.contains("beine") { return .quads }
        return nil
    }

    // Simple mapper (Fallback Name -> Name)
    private func mainMuscle(for exerciseName: String) -> String {
        let n = exerciseName.lowercased()
        if n.contains("bank") || n.contains("chest") || n.contains("push") || n.contains("brust") { return "Brust" }
        if n.contains("rudern") || n.contains("back") || n.contains("pull") || n.contains("lat") || n.contains("rücken") { return "Rücken" }
        if n.contains("squat") || n.contains("bein") || n.contains("leg") { return "Beine" }
        if n.contains("curl") || n.contains("bizeps") { return "Bizeps" }
        if n.contains("tri") || n.contains("trizeps") { return "Trizeps" }
        if n.contains("shoulder") || n.contains("schulter") { return "Schultern" }
        if n.contains("bauch") || n.contains("abs") { return "Bauch" }
        return "Unbekannt"
    }
    
    // Fallback Name -> Region
    private func mapRefinedMuscle(for exerciseName: String) -> MuscleRegion? {
        // Re-use the existing logic from StatisticsView via helper?
        // Or duplicate simple logic here for safety
        let n = exerciseName.lowercased()
        if n.contains("bench") || n.contains("chest") { return .chest }
        if n.contains("curl") { return .biceps }
        if n.contains("squat") { return .quads }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Switch
            HStack {
                Label("Body Recovery", systemImage: "figure.mind.and.body")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Custom Toggle (List / Body)
                HStack(spacing: 0) {
                    toggleBtn(icon: "list.bullet", isMap: false)
                    toggleBtn(icon: "figure.stand", isMap: true)
                }
                .padding(2)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            
            if muscleStatuses.isEmpty {
                Text(appSettings.localized("body.recovery.noData")) // "Keine Trainingsdaten gefunden."
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                if useMapView {
                    // MAP VIEW
                    HStack(spacing: 12) {
                        MuscleFigure(side: .front, regionColors: mapRegionColors)
                        
                        // Divider
                        Rectangle().fill(Color.secondary.opacity(0.1)).frame(width: 1)
                        
                        MuscleFigure(side: .back, regionColors: mapRegionColors)
                    }
                    .frame(height: 220)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    
                    // Simple legend/interaction hint
                    Text(appSettings.localized("body.recovery.info")) // "Tippe auf die Liste für Details"
                         .font(.caption2)
                         .foregroundStyle(.secondary)
                         .padding(.leading)
                         .opacity(0.6)
                    
                } else {
                    // LIST VIEW (Cards)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(muscleStatuses) { item in
                                RecoveryCard(item: item)
                                    .onTapGesture {
                                        selectedMuscle = item
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(item: $selectedMuscle) { item in
            BodyRecoveryDetailView(
                muscleName: item.name,
                status: item.status,
                progress: item.recoveryProgress,
                hoursSince: item.hoursSince
            )
        }
        .animation(.spring(), value: useMapView)
    }
    
    private func toggleBtn(icon: String, isMap: Bool) -> some View {
        Button {
            useMapView = isMap
        } label: {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(useMapView == isMap ? t.palette.onSurface : .secondary)
                .frame(width: 32, height: 28)
                .background(useMapView == isMap ? t.palette.surfaceA : Color.clear)
                .clipShape(Circle())
                .shadow(color: useMapView == isMap ? .black.opacity(0.1) : .clear, radius: 2, y: 1)
        }
    }
}

// Subcomponent for the Card
struct RecoveryCard: View {
    @EnvironmentObject var appSettings: AppSettings // Added
    let item: BodyRecoverySection.MuscleStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(item.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: item.status.icon)
                    .font(.caption)
                    .foregroundStyle(item.status.color)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(item.status.color)
                        .frame(width: geo.size.width * item.recoveryProgress, height: 6)
                }
            }
            .frame(height: 6)
            
            // Stats
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(item.status.title(with: appSettings)) // Use title(with:)
                        .font(.caption2.bold())
                        .foregroundStyle(item.status.color)
                }
                Spacer()
                
                Text("\(Int(item.recoveryProgress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var timeString: String {
        if item.daysSince == 0 {
            return appSettings.localized("common.today") // "Heute"
        } else if item.daysSince == 1 {
            return appSettings.localized("common.yesterday") // "Gestern"
        } else {
            return String(format: appSettings.localized("time.daysAgo"), item.daysSince) // "Vor %d Tagen"
        }
    }
}
