import SwiftUI

// MARK: - Trainingsverlauf (Design-System)
struct TrainingHistoryView: View {
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var syncService: SyncService   // für Cloud-Delete

    // zentraler State (statt in der Row)
    @State private var deleteCandidate: TrainingEntry?
    @State private var emojiCandidate: TrainingEntry?

    // Stabile Gruppierung nach Monat/Jahr (inkl. korrekter Sortierung)
    private var monthGroups: [MonthGroup] {
        let cal = Calendar.current
        var buckets: [Date: [TrainingEntry]] = [:]

        for e in trainingStore.history {
            let comps = cal.dateComponents([.year, .month], from: e.date)
            let start = cal.date(from: comps)! // Monats-Start
            buckets[start, default: []].append(e)
        }

        let df = DateFormatter(); df.locale = .current; df.dateFormat = "LLLL yyyy"
        return buckets
            .map { start, entries in
                MonthGroup(
                    start: start,
                    title: df.string(from: start).capitalized,
                    entries: entries.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.start > $1.start }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(monthGroups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.title)
                                .font(.title2.bold())
                                .padding(.horizontal)

                            VStack(spacing: 12) {
                                ForEach(group.entries) { entry in
                                    NavigationLink {
                                        TrainingDetailView(training: entry)
                                            .environmentObject(trainingStore)
                                            .environmentObject(appSettings)
                                    } label: {
                                        TrainingHistoryCard(
                                            entry: entry,
                                            onRequestDelete: { deleteCandidate = entry },
                                            onRequestEmoji:  { emojiCandidate  = entry }
                                        )
                                        .environmentObject(trainingStore)
                                        .environmentObject(appSettings)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if monthGroups.isEmpty {
                        Text(appSettings.localized("history.empty") ?? "Noch keine Trainings vorhanden")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .appElevatedCard()
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(appSettings.localized("history.title") ?? "Trainingsverlauf")
            .navigationBarTitleDisplayMode(.inline)
        }

        // ---------- zentraler Alert fürs Löschen ----------
        .alert(
            "Training löschen?",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            actions: {
                Button("Löschen", role: .destructive) {
                    guard let entry = deleteCandidate else { return }
                    Task {
                        await syncService.uiDeleteTraining(id: entry.id)
                    }
                    deleteCandidate = nil
                }

                Button("Abbrechen", role: .cancel) { deleteCandidate = nil }
            },
            message: {
                if let d = deleteCandidate?.date {
                    Text("Eintrag vom \(d.formatted(date: .abbreviated, time: .shortened)) wirklich löschen?")
                }
            }
        )

        // ---------- zentrales Sheet für Emoji-Picker ----------
        .sheet(item: $emojiCandidate, onDismiss: { emojiCandidate = nil }) { entry in
            EmojiGridPicker(selection: Binding(
                get: {
                    trainingStore.history.first(where: { $0.id == entry.id })?.emoji
                },
                set: { newEmoji in
                    if let idx = trainingStore.history.firstIndex(where: { $0.id == entry.id }) {
                        trainingStore.history[idx].emoji = newEmoji
                        trainingStore.update(entry: trainingStore.history[idx])
                    }
                }
            ))
        }

        // Während Dialog/Sheet offen ist: Animationen aus
        .transaction { tx in
            if deleteCandidate != nil || emojiCandidate != nil { tx.disablesAnimations = true }
        }
    }

    private struct MonthGroup: Identifiable {
        let id = UUID()
        let start: Date
        let title: String
        let entries: [TrainingEntry]
    }
}

// MARK: - Verlaufskarte (Design-System)
// MARK: - Verlaufskarte (Design-System)
private struct TrainingHistoryCard: View {
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t

    // 🔁 Einheit aus Settings
    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg

    let entry: TrainingEntry
    var onRequestDelete: () -> Void = {}
    var onRequestEmoji:  () -> Void = {}

    // Lokalisierter Titel (Week/Woche)
    private var displayTitle: String {
        let raw = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return appSettings.localized("history.training.fallback") ?? "Training"
        }
        if let (range, weekNumber) = extractWeekNumberAndRange(from: raw) {
            let localizedWeek = String(format: appSettings.localized("week.number"), weekNumber)
            let unitPart = raw[..<range.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "–—-:•|").union(.whitespaces))
            return unitPart.isEmpty ? localizedWeek : "\(unitPart) – \(localizedWeek)"
        }
        return raw
    }

    private var isWeekStyle: Bool {
        extractWeekNumberAndRange(from: entry.title) != nil
    }

    // 🏃‍♂️ Ist das ein Lauf?
    // Heuristik: keine Übungen + Titel enthält "Joggen" oder Emoji ist Läufer
    private var isRunEntry: Bool {
        entry.exercises.isEmpty &&
        (entry.emoji == "🏃‍♂️"
         || entry.emoji == "🏃‍♀️"
         || entry.title.localizedCaseInsensitiveContains("joggen")
         || entry.title.localizedCaseInsensitiveContains("lauf"))
    }

    // 🔢 Gesamtvolumen intern in kg (inkl. Reps) – nur für Kraft
    private var totalKgDouble: Double {
        entry.exercises
            .flatMap { $0.sets }
            .reduce(0.0) { sum, set in
                let kg = numericKg(set.weight) ?? 0
                let reps = Int(set.reps.filter("0123456789".contains)) ?? 0
                return sum + kg * Double(reps)
            }
    }

    // 📏 Darstellung mit gewählter Einheit – nur für Kraft
    private var volumeText: String? {
        guard totalKgDouble > 0 else { return nil }
        return "Volumen: \(historyTotalString(kg: totalKgDouble, unit: weightUnit))"
    }

    // aktuelles Emoji aus Store (wenn vorhanden)
    private var currentEmoji: String {
        if let idx = trainingStore.history.firstIndex(where: { $0.id == entry.id }) {
            return trainingStore.history[idx].emoji ?? "💪"
        }
        return entry.emoji ?? "💪"
    }

    // MARK: - Lauf-spezifische Werte (aus Titel + Dauer berechnet)

    /// Distanz aus Titel "… – 5.23 km"
    private var runDistanceKm: Double? {
        extractDistanceKm(from: entry.title)
    }

    private var runDistanceText: String? {
        guard let d = runDistanceKm else { return nil }
        return String(format: "%.2f km", d)
    }

    /// Pace = Dauer / Distanz
    private var runPaceText: String? {
        guard let d = runDistanceKm, d > 0 else { return nil }
        let secondsPerKm = entry.duration / d
        let m = Int(secondsPerKm) / 60
        let s = Int(secondsPerKm) % 60
        return String(format: "%d:%02d min/km", m, s)
    }

    
    
    private var runDurationText: String {
        let total = Int(entry.duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Emoji-Button – öffnet Sheet über Callback
            Button(action: onRequestEmoji) {
                ZStack {
                    Circle()
                        .fill(t.palette.primary.opacity(0.12))
                        .overlay(Circle().stroke(t.palette.primary, lineWidth: 1))
                    Text(currentEmoji).font(.system(size: 24))
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Training-Emoji")

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    if isRunEntry {
                        Text("RUN")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(t.palette.primary.opacity(0.16))
                            )
                    }
                }

                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 💡 Für Läufe: Distanz · Pace · Zeit
                if isRunEntry,
                   let dist = runDistanceText,
                   let pace = runPaceText {
                    Text("\(dist) · \(pace) · \(runDurationText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                // 💪 Für Kraft: Volumen anzeigen (wie bisher)
                else if !isWeekStyle, let vt = volumeText {
                    Text(vt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive) { onRequestDelete() } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .appElevatedCard()
        .padding(.horizontal)
    }

    // MARK: - Helper

    private func extractWeekNumberAndRange(from title: String) -> (Range<String.Index>, Int)? {
        let pattern = #"(?i)\b(?:week|woche)\s*(\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = NSRange(title.startIndex..<title.endIndex, in: title)
        guard let m = regex.firstMatch(in: title, options: [], range: ns),
              m.numberOfRanges >= 2,
              let fullR = Range(m.range(at: 0), in: title),
              let numR  = Range(m.range(at: 1), in: title),
              let n     = Int(title[numR]) else { return nil }
        return (fullR, n)
    }

    /// "… 5.23 km" → 5.23
    private func extractDistanceKm(from title: String) -> Double? {
        let pattern = #"([0-9]+(?:[.,][0-9]+)?)\s*km"#   // Zahl vor "km", Komma/Punkt erlaubt
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsRange = NSRange(title.startIndex..<title.endIndex, in: title)
        guard let match = regex.firstMatch(in: title, options: [], range: nsRange),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }
        let numberString = String(title[range])
        let withDot = numberString.replacingOccurrences(of: ",", with: ".")
        return Double(withDot)
    }
}


// ---------- Emoji-Picker ----------
private struct EmojiGridPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: String?

    // Vorschläge
    private let emojis = ["💪","🔥","🦵","🦾","⭐️","🏋️‍♂️","🚴‍♀️","🤸‍♂️","🏃‍♂️","⛰️","🧘‍♂️","🥊","⚡️","🎯","🧱"]
    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 14)]

    @State private var customEmoji: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Eigenes Emoji
                    SectionHeader("Eigenes Emoji").padding(.horizontal, 16)

                    HStack(spacing: 10) {
                        TextField("Emoji einfügen …", text: Binding(
                            get: { customEmoji },
                            set: { customEmoji = String($0.prefix(1)) } // exakt 1 Graphem
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 22))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(scheme == .dark ? Color(.secondarySystemBackground) : .white)
                        )

                        Button {
                            guard !customEmoji.isEmpty else { return }
                            pick(customEmoji)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                        }
                        .disabled(customEmoji.isEmpty)
                        .accessibilityLabel("Dieses Emoji übernehmen")
                    }
                    .padding(.horizontal, 16)

                    // Vorschläge
                    SectionHeader("Vorschläge").padding(.horizontal, 16)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(emojis, id: \.self) { e in
                            Button { pick(e) } label: {
                                Text(e)
                                    .font(.system(size: 30))
                                    .frame(width: 72, height: 72)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.primary.opacity(0.08))
                                    )
                            }
                            .accessibilityLabel("Emoji \(e)")
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Emoji wählen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Entfernen") {
                        selection = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func pick(_ e: String) {
        selection = e
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }
}

// MARK: - Helpers (gleich belassen)

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let runSpacing: CGFloat
    @ViewBuilder var content: Content

    init(spacing: CGFloat = 8, runSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing; self.runSpacing = runSpacing; self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            generate(in: geo.size)
        }
        .frame(minHeight: 0)
    }

    private func generate(in size: CGSize) -> some View {
        var x: CGFloat = 0
        var y: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            content
                .fixedSize()
                .alignmentGuide(.leading) { d in
                    if abs(x - d.width) > size.width {
                        x = 0
                        y -= d.height + runSpacing
                    }
                    let result = x
                    if d.width <= size.width { x -= d.width + spacing }
                    return result
                }
                .alignmentGuide(.top) { _ in y }
        }
    }
}

// MARK: - Parsing + Formatting

private extension Double { var asInt: Int { Int(self) } }

/// Robust Zahlenparser für kg (unterstützt Komma/Punkt)
private func numericKg(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let nf = NumberFormatter(); nf.locale = .current; nf.numberStyle = .decimal
    if let n = nf.number(from: trimmed) { return n.doubleValue }
    if let d = Double(trimmed.replacingOccurrences(of: ",", with: ".")) { return d }
    if let n = nf.number(from: trimmed.replacingOccurrences(of: ".", with: ",")) { return n.doubleValue }
    return nil
}

/// Einheitsabhängige Darstellung des Gesamtvolumens (kg → kg/lb)
private func historyTotalString(kg: Double, unit: WeightUnit) -> String {
    let value = unit.fromKilograms(kg)
    let nf = NumberFormatter()
    nf.locale = .current
    nf.numberStyle = .decimal
    nf.usesGroupingSeparator = true
    nf.minimumFractionDigits = 0
    nf.maximumFractionDigits = 0
    let num = nf.string(from: NSNumber(value: value)) ?? String(Int(round(value)))
    return "\(num) \(unit.symbol)"
}
