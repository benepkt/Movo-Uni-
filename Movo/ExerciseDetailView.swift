import SwiftUI
import Charts

// MARK: - Chart-Datenpunkt
struct WeightChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let avgKg: Double
}

// MARK: - Letzte-Sätze Row (muss öffentlich sein, wird extern genutzt)
struct RecentRow: Identifiable, Hashable {
    let id: UUID
    let dateText: String
    let lines: [Line]
    struct Line: Hashable { let title: String; let weight: String? }
}

// MARK: - Haupt-View
struct ExerciseDetailView: View {
    var exerciseInfo: ExerciseInfo
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t
    @Environment(\.colorScheme)  private var scheme

    @AppStorage("units.weight") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    // MARK: Daten
    private var filteredEntries: [TrainingEntry] {
        let name = exerciseInfo.name
        return trainingStore.history
            .filter { $0.exercises.contains(where: { $0.name == name }) }
            .sorted { $0.date > $1.date }
    }

    private var bestSet: (kg: Double, reps: Int)? {
        var best: (Double, Int) = (0, 0)
        let name = exerciseInfo.name
        for entry in filteredEntries {
            for ex in entry.exercises where ex.name == name {
                for s in ex.sets {
                    let wKg = parseKgString(s.weight)
                    let r = Int(s.reps) ?? 0
                    guard wKg > 0 else { continue }
                    if wKg > best.0 || (wKg == best.0 && r > best.1) { best = (wKg, r) }
                }
            }
        }
        return best.0 > 0 ? best : nil
    }

    private var totalVolumeKgLast30: Double {
        let cutoff = Date().addingTimeInterval(-30*24*60*60)
        let name = exerciseInfo.name
        return filteredEntries
            .filter { $0.date >= cutoff }
            .flatMap(\.exercises)
            .filter { $0.name == name }
            .flatMap(\.sets)
            .reduce(0) { $0 + parseKgString($1.weight) * Double(Int($1.reps) ?? 0) }
    }

    private var trainingCount: Int { filteredEntries.count }
    private var lastTrainingDate: Date? { filteredEntries.first?.date }

    private var chartPoints: [WeightChartPoint] {
        let name = exerciseInfo.name
        return filteredEntries.map { e in
            let weightsKg = e.exercises
                .filter { $0.name == name }
                .flatMap(\.sets)
                .map { parseKgString($0.weight) }
                .filter { $0 > 0 }
            let avgKg = weightsKg.isEmpty ? 0 : weightsKg.reduce(0, +) / Double(weightsKg.count)
            return WeightChartPoint(id: e.id, date: e.date, avgKg: avgKg)
        }
    }

    // Karten-Fill (klar getypt)
    private var cardFill: LinearGradient {
        if scheme == .dark {
            return LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color.white, Color.white.opacity(0.96)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - UI
    var body: some View {
        let titleStats     = appSettings.localized("statistics.title")
        let titleBadges    = appSettings.localized("profile.badges")
        let titleNotes     = appSettings.localized("notes.title")
        let titleProgress  = appSettings.localized("statistics.progress")
        let titleRecent    = appSettings.localized("exercise.recentSets")
        let titleGroups    = appSettings.localized("exercise.muscleGroups")
        let titleHowTo     = appSettings.localized("exercise.instructions")

        let statMaxWeight  = appSettings.localized("statistics.max.weight")
        let statTrainings  = appSettings.localized("statistics.trainings")
        let statLast       = appSettings.localized("exercise.lastTraining")
        let statVol30      = appSettings.localized("exercise.volume.30d")

        let axisDateLabel  = appSettings.localized("statistics.date")
        let axisYLabel     = "\(appSettings.localized("statistics.avg.weight")) (\(weightUnit.symbol))"

        ZStack {
            detailBackground

            ScrollView {
                VStack(spacing: 16) {

                    HeroHeader(title: exerciseInfo.localizedName(using: appSettings), icon: "dumbbell.fill")
                        .padding(.top, 8)

                    InfoCard(title: titleGroups, icon: "figure.strengthtraining.traditional") {
                        FlexibleTagView(tags: exerciseInfo.muscleGroups.map { exerciseInfo.localizedMuscle($0, using: appSettings) })
                    }

                    InfoCard(title: titleHowTo, icon: "text.book.closed") {
                        Text(exerciseInfo.localizedInstructions(using: appSettings))
                            .foregroundStyle(.white.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    InfoCard(title: titleStats, icon: "chart.bar") {
                        StatsGrid(statMaxWeight: statMaxWeight,
                                  statTrainings: statTrainings,
                                  statLast: statLast,
                                  statVol30: statVol30,
                                  bestSet: bestSet,
                                  trainingCount: trainingCount,
                                  lastTrainingDate: lastTrainingDate,
                                  totalVolumeKgLast30: totalVolumeKgLast30,
                                  weightUnit: weightUnit)
                    }

                    InfoCard(title: titleBadges, icon: "rosette") {
                        HStack(spacing: 12) {
                            BadgeView(name: appSettings.localized("exercise.badge.10trainings"),
                                      achieved: trainingCount >= 10)
                            BadgeView(name: appSettings.localized("exercise.badge.newMax"),
                                      achieved: bestSet != nil)
                        }
                    }

                    InfoCard(title: titleNotes, icon: "note.text") {
                        ExerciseNotes(exerciseId: exerciseInfo.id)
                            .environmentObject(appSettings)
                    }

                    InfoCard(title: titleProgress, icon: "chart.line.uptrend.xyaxis") {
                        if chartPoints.isEmpty {
                            EmptyPill(text: appSettings.localized("exercise.chart.empty"))
                        } else if #available(iOS 16.0, *) {
                            ExerciseWeightChart(points: chartPoints,
                                                unit: weightUnit,
                                                dateLabel: axisDateLabel,
                                                yLabel: axisYLabel,
                                                primary: t.palette.primary)
                                .frame(height: 220)
                        }
                    }

                    InfoCard(title: titleRecent, icon: "list.bullet.rectangle") {
                        let rows = makeRecentRows(entries: Array(filteredEntries.prefix(5)),
                                                  exerciseName: exerciseInfo.name)
                        RecentSetsList(rows: rows,
                                       outline: scheme == .dark ? Color.white.opacity(0.12) : t.palette.outline,
                                       fill: cardFill)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var detailBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [t.palette.primary.opacity(0.34), Color.cyan.opacity(0.12), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 440
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color.blue.opacity(0.16), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Helpers

    private var inputFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.locale = .current
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 6
        return f
    }
    private func parseKgString(_ text: String) -> Double {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let n = inputFormatter.number(from: s) { return n.doubleValue }
        if let d = Double(s.replacingOccurrences(of: ",", with: ".")) { return d }
        if let n = inputFormatter.number(from: s.replacingOccurrences(of: ".", with: ",")) { return n.doubleValue }
        return 0
    }

    private func makeRecentRows(entries: [TrainingEntry], exerciseName: String) -> [RecentRow] {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none

        return entries.map { entry in
            var out: [RecentRow.Line] = []
            for ex in entry.exercises where ex.name == exerciseName {
                for (idx, set) in ex.sets.enumerated() {
                    let reps = Int(set.reps) ?? 0
                    let label = String(format: appSettings.localized("exercise.set.item"), idx + 1, reps)
                    let kg = parseKgString(set.weight)
                    let wt = kg > 0 ? weightUnit.format(kg: kg, decimals: 0) : nil
                    out.append(.init(title: label, weight: wt))
                }
            }
            return RecentRow(id: entry.id, dateText: df.string(from: entry.date), lines: out)
        }
    }
}

// MARK: - Teil-Views

private struct StatsGrid: View {
    let statMaxWeight: String
    let statTrainings: String
    let statLast: String
    let statVol30: String
    let bestSet: (kg: Double, reps: Int)?
    let trainingCount: Int
    let lastTrainingDate: Date?
    let totalVolumeKgLast30: Double
    let weightUnit: WeightUnit

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                let maxText = bestSet.map { "\(weightUnit.format(kg: $0.kg, decimals: 0)) × \($0.reps)" } ?? "–"
                StatItem(title: statMaxWeight, value: maxText)
                StatItem(title: statTrainings, value: "\(trainingCount)")
            }
            HStack(spacing: 12) {
                let last = lastTrainingDate.map {
                    DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .none)
                } ?? "–"
                StatItem(title: statLast, value: last)

                let vol = totalVolumeKgLast30 > 0
                    ? weightUnit.format(kg: totalVolumeKgLast30, decimals: 0)
                    : "–"
                StatItem(title: statVol30, value: vol)
            }
        }
    }
}

private struct RecentSetsList: View {
    let rows: [RecentRow]
    let outline: Color
    let fill: LinearGradient

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 12) {
                ForEach(rows, id: \.id) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(row.dateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(row.lines, id: \.self) { line in
                            HStack {
                                Text(line.title).fontWeight(.semibold)
                                if let wt = line.weight {
                                    Text("– \(wt)").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(outline, lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Chart
@available(iOS 16.0, *)
private struct ExerciseWeightChart: View {
    @Environment(\.colorScheme) private var scheme

    let points: [WeightChartPoint]
    let unit: WeightUnit
    let dateLabel: String
    let yLabel: String
    let primary: Color

    var body: some View {
        Chart {
            ForEach(points) { p in
                let y = unit.fromKilograms(p.avgKg)
                LineMark(x: .value(dateLabel, p.date), y: .value(yLabel, y))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(primary)
                PointMark(x: .value(dateLabel, p.date), y: .value(yLabel, y))
                    .foregroundStyle(primary)
            }
        }
        .chartPlotStyle { plot in
            let plotBg: Color = scheme == .dark ? .white.opacity(0.05) : .black.opacity(0.03)
            let plotStroke: Color = scheme == .dark ? .white.opacity(0.10) : .black.opacity(0.06)
            plot
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(plotBg))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(plotStroke, lineWidth: 1))
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(scheme == .dark ? 0.18 : 0.22))
                AxisTick().foregroundStyle(.secondary.opacity(0.4))
                AxisValueLabel().foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(scheme == .dark ? 0.18 : 0.22))
                AxisTick().foregroundStyle(.secondary.opacity(0.4))
                AxisValueLabel().foregroundStyle(.secondary)
            }
        }
        .chartYAxisLabel(position: .automatic) { Text(yLabel) }
    }
}

// MARK: - Hero
private struct HeroHeader: View {
    let title: String
    let icon: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.designTokens) private var t

    var body: some View {
        let bubble: Color = scheme == .dark ? .white.opacity(0.18) : .white.opacity(0.35)
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(bubble)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 80, height: 80)

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer()
        }
        .modifier(HeroCardModifier(primary: t.palette.primary))
    }
}

// MARK: - InfoCard
private struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            content
        }
        .modifier(ElevatedCardModifier())
    }
}

// MARK: - Kleinteile
private struct StatItem: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundStyle(.white)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyPill: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        let bg: Color = scheme == .dark ? .white.opacity(0.07) : .black.opacity(0.04)
        let stroke: Color = scheme == .dark ? .white.opacity(0.12) : .black.opacity(0.06)
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(stroke, lineWidth: 1))
    }
}

private struct FlexibleTagView: View {
    @Environment(\.designTokens) private var t
    @Environment(\.colorScheme)  private var scheme
    let tags: [String]
    private let cols = [GridItem(.adaptive(minimum: 80), spacing: 8)]

    var body: some View {
        let bgLight = t.palette.primary.opacity(0.12)
        let bgDark  = t.palette.primary.opacity(0.22)
        let textDark: Color = .white
        let textLight: Color = t.palette.primary

        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(scheme == .dark ? bgDark : bgLight))
                    .foregroundStyle(scheme == .dark ? textDark : textLight)
            }
        }
    }
}

private struct BadgeView: View {
    var name: String
    var achieved: Bool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: achieved ? "star.fill" : "star")
                .font(.title2)
                .foregroundStyle(achieved ? .yellow : .secondary)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
        .padding(6)
    }
}

// MARK: - Notes
private struct ExerciseNotes: View {
    @Environment(\.colorScheme)  private var scheme
    @EnvironmentObject var library: ExerciseLibrary
    @EnvironmentObject var appSettings: AppSettings
    let exerciseId: UUID

    @State private var editingNoteId: UUID?
    @State private var draftText = ""

    private var notes: [Note] {
        library.exercises.first(where: { $0.id == exerciseId })?.notes ?? []
    }

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    library.addNote(for: exerciseId, text: "")
                    DispatchQueue.main.async {
                        if let last = notes.last { editingNoteId = last.id; draftText = "" }
                    }
                } label: {
                    Label(appSettings.localized("notes.new"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }

            if notes.isEmpty {
                EmptyPill(text: appSettings.localized("notes.empty"))
            } else {
                VStack(spacing: 12) {
                    ForEach(notes) { note in
                        NoteCard(note: note,
                                 isEditing: editingNoteId == note.id,
                                 draftText: editingNoteId == note.id ? $draftText : .constant(""),
                                 startEdit: { editingNoteId = note.id; draftText = note.text },
                                 cancelEdit: { editingNoteId = nil; draftText = "" },
                                 deleteNote: {
                                    library.deleteNote(for: exerciseId, noteId: note.id)
                                    editingNoteId = nil; draftText = ""
                                 },
                                 save: {
                                    var updated = note
                                    updated.text = draftText
                                    updated.date = Date()
                                    library.updateNote(for: exerciseId, note: updated)
                                    editingNoteId = nil; draftText = ""
                                 },
                                 dateText: df.string(from: note.date),
                                 scheme: scheme)
                    }
                }
            }
        }
    }
}

private struct NoteCard: View {
    let note: Note
    let isEditing: Bool
    @Binding var draftText: String
    let startEdit: () -> Void
    let cancelEdit: () -> Void
    let deleteNote: () -> Void
    let save: () -> Void
    let dateText: String
    let scheme: ColorScheme

    var body: some View {
        let fill = scheme == .dark
        ? LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
        : LinearGradient(colors: [Color.white, Color.white.opacity(0.96)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
        let stroke: Color = scheme == .dark ? .white.opacity(0.12) : .black.opacity(0.06)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if isEditing {
                    Button(role: .cancel, action: cancelEdit) { Image(systemName: "xmark.circle").foregroundStyle(.secondary) }
                } else {
                    Button(action: startEdit) { Image(systemName: "pencil").foregroundStyle(.secondary) }
                }
            }

            if isEditing {
                TextField("Notiz", text: $draftText)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fill))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(stroke, lineWidth: 1))

                HStack {
                    Button(role: .destructive, action: deleteNote) {
                        Label("Löschen", systemImage: "trash")
                    }
                    Spacer()
                    Button("Speichern", action: save).buttonStyle(.borderedProminent)
                }
            } else {
                Text(note.text.isEmpty ? "Leere Notiz" : note.text)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fill))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(stroke, lineWidth: 1))
            }
        }
        .modifier(ElevatedCardModifier())
    }
}

// MARK: - Modifiers
private struct ElevatedCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let bgDark  = LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
        let stroke: Color = .white.opacity(0.12)
        let shadow: Color = .black.opacity(0.45)

        content
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(bgDark))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(stroke, lineWidth: 1))
            .shadow(color: shadow, radius: 10, x: 0, y: 6)
    }
}

private struct HeroCardModifier: ViewModifier {
    let primary: Color
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let top: Color = scheme == .dark ? primary.opacity(0.35) : primary.opacity(0.25)
        let bot: Color = scheme == .dark ? primary.opacity(0.20) : primary.opacity(0.12)
        let bg = LinearGradient(colors: [top, bot], startPoint: .topLeading, endPoint: .bottomTrailing)
        let stroke: Color = scheme == .dark ? .white.opacity(0.10) : .black.opacity(0.05)
        let shadow: Color = scheme == .dark ? .black.opacity(0.50) : .black.opacity(0.12)

        content
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(stroke, lineWidth: 1))
            .shadow(color: shadow, radius: scheme == .dark ? 16 : 12, x: 0, y: scheme == .dark ? 10 : 8)
    }
}
