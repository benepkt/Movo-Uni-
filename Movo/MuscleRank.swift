import SwiftUI


public enum MuscleRank: Int, CaseIterable, Codable {
    case wood = 0
    case stone
    case iron
    case bronze
    case silver
    case gold
    case sapphire
    case emerald
    case ruby
    case platinum
    case obsidian
    case diamond
    case master
    case grandmaster
    case champion
    case elite
    case legend
    case titan
    case mythic
    case olympian

    public var title: String {
        switch self {
        case .wood: return "Wood"
        case .stone: return "Stone"
        case .iron: return "Iron"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .sapphire: return "Sapphire"
        case .emerald: return "Emerald"
        case .ruby: return "Ruby"
        case .platinum: return "Platinum"
        case .obsidian: return "Obsidian"
        case .diamond: return "Diamond"
        case .master: return "Master"
        case .grandmaster: return "Grandmaster"
        case .champion: return "Champion"
        case .elite: return "Elite"
        case .legend: return "Legend"
        case .titan: return "Titan"
        case .mythic: return "Mythic"
        case .olympian: return "Olympian"
        }
    }

    public var color: Color {
        switch self {
        case .wood: return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .stone: return .gray
        case .iron: return Color(red: 0.55, green: 0.58, blue: 0.62)
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.78, blue: 0.82)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .sapphire: return .blue
        case .emerald: return .green
        case .ruby: return .pink
        case .platinum: return Color(red: 0.8, green: 0.8, blue: 0.9) // Silver-ish
        case .obsidian: return Color(red: 0.18, green: 0.16, blue: 0.22)
        case .diamond: return Color.cyan
        case .master: return .indigo
        case .grandmaster: return .purple
        case .champion: return Color.purple
        case .elite: return .orange
        case .legend: return .yellow
        case .titan: return Color.red
        case .mythic: return .mint
        case .olympian: return Color.white // Glowing white
        }
    }

    public var threshold: Double {
        switch self {
        case .wood: return 0
        case .stone: return 2
        case .iron: return 5
        case .bronze: return 9
        case .silver: return 14
        case .gold: return 20
        case .sapphire: return 28
        case .emerald: return 38
        case .ruby: return 50
        case .platinum: return 65
        case .obsidian: return 84
        case .diamond: return 108
        case .master: return 138
        case .grandmaster: return 174
        case .champion: return 216
        case .elite: return 265
        case .legend: return 322
        case .titan: return 388
        case .mythic: return 464
        case .olympian: return 550
        }
    }
    
    public static func rank(for score: Double) -> MuscleRank {
        // Find the highest rank where count >= threshold
        return allCases.sorted(by: { $0.rawValue > $1.rawValue }).first { score >= $0.threshold } ?? .wood
    }
}

public struct MuscleRankingHelper {
    static func calculateMuscleRanks(from history: [TrainingEntry]) -> [MuscleRegion: MuscleRank] {
        let scores = calculateMuscleScores(from: history)
        var ranks: [MuscleRegion: MuscleRank] = [:]
        for region in MuscleRegion.allCases {
            ranks[region] = MuscleRank.rank(for: scores[region] ?? 0)
        }
        return ranks
    }

    static func calculateMuscleScores(from history: [TrainingEntry]) -> [MuscleRegion: Double] {
        var scores: [MuscleRegion: Double] = [:]
        
        for entry in history {
            for exercise in entry.exercises {
                let regions = MuscleMappingHelper.regions(forExerciseName: exercise.name)
                guard !regions.isEmpty else { continue }
                let volumeKg = exercise.sets.reduce(0.0) { $0 + parseKg($1.weight) * Double(parseReps($1.reps)) }
                let reps = exercise.sets.reduce(0) { $0 + parseReps($1.reps) }
                let completedMultiplier = exercise.sets.contains(where: { $0.isCompleted }) ? 1.0 : 0.72
                let exerciseScore = ((volumeKg / 100.0) + (Double(reps) / 35.0)) * completedMultiplier / Double(regions.count)
                for region in regions {
                    scores[region, default: 0] += exerciseScore
                }
            }
        }
        return scores
    }
    
    static func calculateOverallLevel(from ranks: [MuscleRegion: MuscleRank]) -> String {
        let totalScore = ranks.values.reduce(0) { $0 + $1.rawValue }
        // Simple mapping from total score to an overall title or level
        // This is arbitrary for now
        if totalScore > 100 { return "Olympian God" }
        if totalScore > 70 { return "Titan" }
        if totalScore > 50 { return "Champion" }
        if totalScore > 30 { return "Diamond" }
        if totalScore > 20 { return "Platinum" }
        if totalScore > 10 { return "Gold" }
        if totalScore > 5 { return "Bronze" }
        return "Beginner"
    }
    /// Returns the muscle region that is closest to the next rank, along with the trainings needed.
       static func findClosestNextRank(from history: [TrainingEntry]) -> (region: MuscleRegion, needed: Int, nextRank: MuscleRank)? {
           let scores = calculateMuscleScores(from: history)
           
           var candidates: [(region: MuscleRegion, needed: Int, nextRank: MuscleRank)] = []
           
           for region in MuscleRegion.allCases {
               let currentScore = scores[region] ?? 0
               let currentRank = MuscleRank.rank(for: currentScore)
               
               // Find next rank
               // Sort ranks by threshold
               let sortedRanks = MuscleRank.allCases.sorted { $0.threshold < $1.threshold }
               if let next = sortedRanks.first(where: { $0.threshold > currentScore }) {
                   let needed = Int(ceil(next.threshold - currentScore))
                   candidates.append((region, needed, next))
               }
           }
           
           // Sort by needed (smallest first), then by region name for stability
           candidates.sort {
               if $0.needed != $1.needed { return $0.needed < $1.needed }
               return $0.region.rawValue < $1.region.rawValue
           }
           
           return candidates.first
       }

    private static func parseKg(_ raw: String) -> Double {
        Double(raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private static func parseReps(_ raw: String) -> Int {
        Int(raw.filter(\.isNumber)) ?? 0
    }
   }



import SwiftUI

struct MuscleRankView: View {
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var trainingStore: TrainingStore
    
    @State private var showLegend = false
    @State private var showComparison = false

    // Computed ranks based on history (Now)
    private var muscleRanksNow: [MuscleRegion: MuscleRank] {
        MuscleRankingHelper.calculateMuscleRanks(from: trainingStore.history)
    }
    
    // For single view compatibility/convenience
    private var regionColorsNow: [MuscleRegion: Color] {
        muscleRanksNow.mapValues { $0.color }
    }

    // Computed ranks based on history (Start - First 7 Days)
    private var muscleRanksStart: [MuscleRegion: MuscleRank] {
        guard let firstDate = trainingStore.history.map(\.date).min() else { return [:] }
        let cal = Calendar.current
        let cutOff = cal.date(byAdding: .day, value: 7, to: firstDate)!
        // Filter history for entries before cutoff
        let startHistory = trainingStore.history.filter { $0.date <= cutOff }
        return MuscleRankingHelper.calculateMuscleRanks(from: startHistory)
    }
    
    // Check if we have enough history to show a meaningful comparison
    private var hasComparisonData: Bool {
        !trainingStore.history.isEmpty
    }
    
    private var overallLevel: String {
        MuscleRankingHelper.calculateOverallLevel(from: muscleRanksNow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appSettings.localized("statistics.level.yours"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(overallLevel)
                        .font(.title2.bold())
                        .foregroundStyle(t.palette.primary)
                }
                Spacer()
                
                // Toggle Comparison Button
                if hasComparisonData {
                    Button {
                        withAnimation(.spring()) {
                            showComparison.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showComparison ? appSettings.localized("statistics.compare.hide") : appSettings.localized("statistics.compare"))
                                .font(.caption.bold())
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption)
                        }
                        .foregroundStyle(showComparison ? t.palette.primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(showComparison ? t.palette.primary.opacity(0.1) : Color.clear)
                        )
                    }
                }
                
                // Legend or Info Button
                Button {
                    showLegend = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showLegend) {
                NavigationStack {
                    List {
                        Section {
                            Text(appSettings.localized("statistics.legend.info"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }

                        ForEach(MuscleRank.allCases, id: \.self) { rank in
                            HStack {
                                Circle()
                                    .fill(rank.color)
                                    .frame(width: 12, height: 12)
                                
                                Text(localizedRankTitle(rank))
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text(rank.threshold == 0
                                     ? appSettings.localized("statistics.rank.start")
                                     : String(format: appSettings.localized("statistics.rank.threshold"), Int(rank.threshold))
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Capsule())
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle(appSettings.localized("statistics.legend.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(appSettings.localized("statistics.legend.close")) {
                                showLegend = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .fraction(0.6)])
            }

            // Body Map Content
            Group {
                if showComparison && hasComparisonData {
                    // Comparison View
                    VStack(spacing: 20) {
                        // Labels Header
                        HStack {
                            Text(appSettings.localized("statistics.compare.start"))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                            
                            Spacer().frame(width: 30) // Space for arrow
                            
                            Text(appSettings.localized("statistics.compare.now"))
                                .font(.caption.bold())
                                .foregroundStyle(t.palette.primary)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Row 1: Front
                        HStack(spacing: 0) {
                            MuscleFigure(side: .front, regionColors: regionColors(for: muscleRanksStart))
                                .frame(maxWidth: .infinity)
                            
                            Image(systemName: "arrow.right")
                                .font(.title2.bold())
                                .foregroundStyle(.secondary.opacity(0.3))
                                .frame(width: 30)
                            
                            MuscleFigure(side: .front, regionColors: regionColors(for: muscleRanksNow))
                                .frame(maxWidth: .infinity)
                        }
                        .frame(height: 180)
                        
                        // Row 2: Back
                        HStack(spacing: 0) {
                            MuscleFigure(side: .back, regionColors: regionColors(for: muscleRanksStart))
                                .frame(maxWidth: .infinity)
                            
                            Image(systemName: "arrow.right")
                                .font(.title2.bold())
                                .foregroundStyle(.secondary.opacity(0.3))
                                .frame(width: 30)
                            
                            MuscleFigure(side: .back, regionColors: regionColors(for: muscleRanksNow))
                                .frame(maxWidth: .infinity)
                        }
                        .frame(height: 180)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                } else {
                    // Standard Single View
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            MuscleFigure(side: .front, regionColors: regionColorsNow)
                            MuscleFigure(side: .back, regionColors: regionColorsNow)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        
                        // Progress Chips Script
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(MuscleRank.allCases.reversed(), id: \.self) { rank in
                                    let count = muscleRanksNow.values.filter { $0 == rank }.count
                                    if count > 0 {
                                        HStack(spacing: 6) {
                                            Circle().fill(rank.color).frame(width: 8, height: 8)
                                            Text("\(localizedRankTitle(rank)): \(count)")
                                                .font(.caption.bold())
                                                .foregroundStyle(.primary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
        }
        .appElevatedCard()
    }
    
    // Helper to map ranks to colors
    private func regionColors(for ranks: [MuscleRegion: MuscleRank]) -> [MuscleRegion: Color] {
        ranks.mapValues { $0.color }
    }
    
    private func localizedRankTitle(_ rank: MuscleRank) -> String {
        let key = "rank.\(rank.rawValue)"
        let v = appSettings.localized(key)
        return (v == key) ? rank.title : v
    }
}


import SwiftUI

public struct MuscleFigure: View {
    @Environment(\.colorScheme) private var scheme

    let side: MuscleSide
    // Mode 1: Uniform tint with variable opacity (Statistics Style)
    var tint: Color? = nil
    var load: [MuscleRegion: Double]? = nil
    var maxLoad: Double? = nil
    
    // Mode 2: Dictionary of colors per region (Ranking Style)
    var regionColors: [MuscleRegion: Color]? = nil

    public init(side: MuscleSide, tint: Color, load: [MuscleRegion: Double], maxLoad: Double) {
        self.side = side
        self.tint = tint
        self.load = load
        self.maxLoad = maxLoad
        self.regionColors = nil
    }
    
    public init(side: MuscleSide, regionColors: [MuscleRegion: Color]) {
        self.side = side
        self.regionColors = regionColors
        self.tint = nil
        self.load = nil
        self.maxLoad = nil
    }

    public var body: some View {
        let outlineColor: Color =
            (scheme == .dark) ? .white.opacity(0.85) : .black.opacity(0.18)

        let regionBlend: BlendMode =
            (scheme == .dark) ? .screen : .multiply

        ZStack {
            Image(side == .front ? "muscle_front_outline" : "muscle_back_outline")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(outlineColor)

            ForEach(MuscleRegion.allCases.filter { $0.side == side }, id: \.self) { region in
                if let name = region.resolvedAssetName {
                    // Logic for Color & Opacity
                    if let regionColors = regionColors, let color = regionColors[region] {
                        // Ranking Mode
                        Image(name)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundStyle(color)
                            .opacity(1.0)
                            .blendMode(regionBlend)
                    } else if let load = load, let maxLoad = maxLoad, let tint = tint {
                        // Statistics/Load Mode
                        let v = load[region, default: 0]
                        let opacity = opacityFor(value: v, maxValue: maxLoad)
                        
                        if opacity > 0.001 {
                            Image(name)
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .foregroundStyle(tint)
                                .opacity(opacity)
                                .blendMode(regionBlend)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func opacityFor(value: Double, maxValue: Double) -> Double {
        guard value > 0, maxValue > 0 else { return 0 }
        let n = min(max(value / maxValue, 0), 1)
        return 0.18 + 0.82 * sqrt(n)
    }
}
