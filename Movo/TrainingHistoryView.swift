import SwiftUI
import HealthKit

// MARK: - Trainingsverlauf (Design-System)
struct TrainingHistoryView: View {
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var authService: AuthService

    // zentraler State
    @State private var deleteCandidate: TrainingEntry?
    @State private var emojiCandidate: TrainingEntry?

    // Navigation zu „Neues Training“ (für Wiederholen)
    @State private var showNewTraining = false

    // Paywall / Limit
    @State private var showLimitAlert = false
    @State private var showPaywall = false
    private let freeTemplateLimit = 3
    private var isPremium: Bool { purchaseManager.hasUnlockedStatistics }
    private var userTemplateCount: Int { templateStore.userTemplates.count }

    // Apple Health Integration
    @State private var healthKitWorkouts: [HKWorkout] = []
    @State private var filter: HistoryFilter = .movo
    @StateObject private var healthManager = HealthKitManager()
    @Environment(\.designTokens) private var t

    // Date Filter
    @State private var selectedDate: Date? = nil
    @State private var showDatePicker = false

    enum HistoryFilter: String, CaseIterable, Identifiable {
        case movo = "Movo"
        case appleHealth = "Apple Health"
        case all = "Alle"
        var id: String { rawValue }
    }

    // Gruppierung nach Monat
    private var monthGroups: [MonthGroup] {
        let cal = Calendar.current
        var buckets: [Date: [TrainingEntry]] = [:]

        if filter == .all || filter == .movo {
            for e in trainingStore.history {
                if let date = selectedDate, !cal.isDate(e.date, inSameDayAs: date) { continue }
                let comps = cal.dateComponents([.year, .month], from: e.date)
                let start = cal.date(from: comps)!
                buckets[start, default: []].append(e)
            }
        }

        if filter == .all || filter == .appleHealth {
            let hkEntries = healthKitWorkouts.map { convert($0) }
            for e in hkEntries {
                if let date = selectedDate, !cal.isDate(e.date, inSameDayAs: date) { continue }
                let comps = cal.dateComponents([.year, .month], from: e.date)
                let start = cal.date(from: comps)!
                buckets[start, default: []].append(e)
            }
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
                    // Filter-Zeile
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            Menu {
                                ForEach(HistoryFilter.allCases) { f in
                                    Button {
                                        filter = f
                                    } label: {
                                        filter == f ? AnyView(Label(f.rawValue, systemImage: "checkmark")) : AnyView(Text(f.rawValue))
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(filter.rawValue)
                                    Image(systemName: "chevron.down").font(.caption2)
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation { showDatePicker.toggle() }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(selectedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Datum")
                                    if selectedDate == nil {
                                        Image(systemName: "chevron.down").font(.caption2)
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .onTapGesture { selectedDate = nil }
                                    }
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedDate != nil ? t.palette.primary.opacity(0.15) : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedDate != nil ? t.palette.primary : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    if showDatePicker {
                        DatePicker(
                            "Datum wählen",
                            selection: Binding(
                                get: { selectedDate ?? Date() },
                                set: { selectedDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Gruppen + Karten
                    ForEach(monthGroups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.title)
                                .font(.title2.bold())
                                .padding(.horizontal)

                            VStack(spacing: 12) {
                                ForEach(group.entries) { entry in
                                    // Container: ZStack, damit wir das Menü über die Karte legen können
                                    ZStack(alignment: .trailing) {
                                        // NavigationLink: die Karte als Label (wie vorher)
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

                                        // Overlay: „…“-Menü – außerhalb des NavigationLink,
                                        // aber optisch am gleichen Platz. Kein Link-Highlight mehr.
                                        Menu {
                                            Button {
                                                repeatWorkout(entry)
                                            } label: {
                                                Label("Wiederholen", systemImage: "gobackward")
                                            }
                                            Button {
                                                saveAsTemplate(entry)
                                            } label: {
                                                Label("Als Vorlage speichern", systemImage: "doc.on.doc")
                                            }
                                            Button(role: .destructive) {
                                                deleteCandidate = entry
                                            } label: {
                                                Label("Löschen", systemImage: "trash")
                                            }
                                        } label: {
                                            ZStack {
                                                // Unsichtbare, große Tap-Fläche (44×44)
                                                Rectangle()
                                                    .fill(Color.clear)
                                                    .frame(width: 44, height: 44)
                                                    .contentShape(Rectangle())
                                                Image(systemName: "ellipsis")
                                                    .font(.title3)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .buttonStyle(.borderless)
                                        .padding(.trailing, 24)   // optische Ausrichtung in der Karte
                                        .padding(.top, 4)         // leicht nach unten, wie vorher
                                    }
                                    // Swipe-Actions auf der ganzen Zeile
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteCandidate = entry
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            repeatWorkout(entry)
                                        } label: {
                                            Label("Wiederholen", systemImage: "gobackward")
                                        }
                                        .tint(.blue)

                                        Button {
                                            saveAsTemplate(entry)
                                        } label: {
                                            Label("Als Vorlage", systemImage: "doc.on.doc")
                                        }
                                        .tint(.purple)
                                    }
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
            .background(navigationLinks()) // <<— versteckter NavigationLink für "Wiederholen"
            .navigationTitle(appSettings.localized("history.title") ?? "Trainingsverlauf")
            .navigationBarTitleDisplayMode(.inline)
            // Lazy: HealthKit erst laden, wenn wirklich benötigt
            .onAppear {
                ensureHKAuthAndFetchIfNeeded()
            }
            .onChange(of: filter) { _ in
                ensureHKAuthAndFetchIfNeeded()
            }
        }

        // ---------- Löschen ----------
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

        // ---------- Limit-Alert + Paywall ----------
        .alert("Limit erreicht", isPresented: $showLimitAlert) {
            Button("Später", role: .cancel) { }
            Button("Upgrade") { showPaywall = true }
        } message: {
            Text("In der kostenlosen Version kannst du bis zu 3 eigene Vorlagen erstellen. Für unbegrenzt viele Vorlagen wechsle bitte auf Premium.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(appSettings)
                .environmentObject(purchaseManager)
        }

        // ---------- Emoji-Picker ----------
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
        // Keine unerwünschten Animationsnebenwirkungen während Modals
        .transaction { tx in
            if deleteCandidate != nil || emojiCandidate != nil { tx.disablesAnimations = true }
        }
    }

    // MARK: - Navigation helper (versteckter Link)
    @ViewBuilder
    private func navigationLinks() -> some View {
        ZStack {
            NavigationLink(isActive: $showNewTraining) {
                NewTrainingView()
                    .environmentObject(sessionManager)
                    .environmentObject(appSettings)
                    .environmentObject(exerciseLibrary)
                    .environmentObject(trainingStore)
                    .environmentObject(gm)
                    .environmentObject(authService)
                    .environmentObject(syncService)
                    .environmentObject(purchaseManager)
                    .environmentObject(healthManager) // denselben HealthKitManager weiterreichen
            } label: { EmptyView() }
        }
        .frame(width: 0, height: 0)
    }

    // MARK: - Actions

    private func repeatWorkout(_ entry: TrainingEntry) {
        sessionManager.startTraining(title: entry.title)
        for ex in entry.exercises { sessionManager.addExercise(ex.name) }
        showNewTraining = true
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func saveAsTemplate(_ entry: TrainingEntry) {
        let exercises = entry.exercises.map { $0.name }
        guard !exercises.isEmpty else { return }

        if !isPremium && userTemplateCount >= freeTemplateLimit {
            showLimitAlert = true
            return
        }

        let t = TrainingTemplate(
            name: entry.title.isEmpty ? "Vorlage vom \(entry.date.formatted(date: .abbreviated, time: .omitted))" : entry.title,
            exercises: exercises,
            ownerId: "local"
        )
        templateStore.add(t)
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    // MARK: - Health (Lazy)

    private func ensureHKAuthAndFetchIfNeeded() {
        // Nur laden, wenn Filter Apple Health enthält
        guard filter == .appleHealth || filter == .all else { return }

        // Wenn schon geladen, nichts tun
        if !healthKitWorkouts.isEmpty { return }

        Task {
            await healthManager.requestReadAuthorizationIfNeeded(
                readTypes: [HKObjectType.workoutType()],
                forcePrompt: true
            )
            fetchHealthKitWorkouts()
        }
    }

    private func fetchHealthKitWorkouts() {
        healthManager.fetchWorkouts { workouts in
            self.healthKitWorkouts = workouts
        }
    }

    private func convert(_ workout: HKWorkout) -> TrainingEntry {
        let title: String
        let emoji: String

        switch workout.workoutActivityType {
        case .running:
            title = "Outdoor Run"; emoji = "🏃‍♂️"
        case .walking:
            title = "Outdoor Walk"; emoji = "🚶"
        case .cycling:
            title = "Cycling"; emoji = "🚴"
        case .swimming:
            title = "Swimming"; emoji = "🏊"
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            title = "Strength Training"; emoji = "🏋️‍♂️"
        case .yoga:
            title = "Yoga"; emoji = "🧘‍♂️"
        case .hiking:
            title = "Hiking"; emoji = "🥾"
        default:
            title = "Workout"; emoji = "💪"
        }

        let duration = workout.duration

        var titleWithStats = title
        if let distance = workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)) {
            titleWithStats += String(format: " – %.2f km", distance)
        }

        return TrainingEntry(
            id: workout.uuid,
            date: workout.startDate,
            title: titleWithStats,
            exercises: [],
            duration: duration,
            totalWeight: 0,
            emoji: emoji,
            updatedAt: workout.endDate,
            routePolyline: nil,
            cardioType: title
        )
    }

    private struct MonthGroup: Identifiable {
        // Stabil: der Monatsbeginn ist eine perfekte, deterministische ID
        var id: Date { start }
        let start: Date
        let title: String
        let entries: [TrainingEntry]
    }
}

// MARK: - Verlaufskarte (Design-System)
private struct TrainingHistoryCard: View {
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t

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

    private var isRunEntry: Bool {
        entry.exercises.isEmpty &&
        (entry.emoji == "🏃‍♂️"
         || entry.emoji == "🏃‍♀️"
         || entry.title.localizedCaseInsensitiveContains("joggen")
         || entry.title.localizedCaseInsensitiveContains("lauf"))
    }

    private var totalKgDouble: Double {
        entry.exercises
            .flatMap { $0.sets }
            .reduce(0.0) { sum, set in
                let kg = numericKg(set.weight) ?? 0
                let reps = Int(set.reps.filter("0123456789".contains)) ?? 0
                return sum + kg * Double(reps)
            }
    }

    private var volumeText: String? {
        guard totalKgDouble > 0 else { return nil }
        return "Volumen: \(historyTotalString(kg: totalKgDouble, unit: weightUnit))"
    }

    private var currentEmoji: String {
        if let idx = trainingStore.history.firstIndex(where: { $0.id == entry.id }) {
            return trainingStore.history[idx].emoji ?? "💪"
        }
        return entry.emoji ?? "💪"
    }

    private var runDistanceKm: Double? { extractDistanceKm(from: entry.title) }

    private var runDistanceText: String? {
        guard let d = runDistanceKm else { return nil }
        return String(format: "%.2f km", d)
    }

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
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onRequestEmoji) {
                ZStack {
                    Circle()
                        .fill(t.palette.primary.opacity(0.12))
                        .overlay(Circle().stroke(t.palette.primary, lineWidth: 1))
                    Text(currentEmoji).font(.system(size: 24))
                }
                .frame(width: 56, height: 56)
                .contentShape(Circle())
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

                if isRunEntry,
                   let dist = runDistanceText,
                   let pace = runPaceText {
                    Text("\(dist) · \(pace) · \(runDurationText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if !isWeekStyle, let vt = volumeText {
                    Text(vt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            // … Menü wird über Overlay im Parent-ZStack gelegt (hier nichts)
        }
        .appElevatedCard()
        .padding(.horizontal)
        .contentShape(Rectangle())
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

    private func extractDistanceKm(from title: String) -> Double? {
        let pattern = #"([0-9]+(?:[.,][0-9]+)?)\s*km"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsRange = NSRange(title.startIndex..<title.endIndex, in: title)
        guard let match = regex.firstMatch(in: title, options: [], range: nsRange),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: title) else { return nil }
        let numberString = String(title[range]).replacingOccurrences(of: ",", with: ".")
        return Double(numberString)
    }
}

// ---------- Emoji-Picker ----------
private struct EmojiGridPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: String?

    private let emojis = ["💪","🔥","🦵","🦾","⭐️","🏋️‍♂️","🚴‍♀️","🤸‍♂️","🏃‍♂️","⛰️","🧘‍♂️","🥊","⚡️","🎯","🧱"]
    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 14)]

    @State private var customEmoji: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader("Eigenes Emoji").padding(.horizontal, 16)

                    HStack(spacing: 10) {
                        TextField("Emoji einfügen …", text: Binding(
                            get: { customEmoji },
                            set: { customEmoji = String($0.prefix(1)) }
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
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
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
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        dismiss()
    }
}

// MARK: - Helpers

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

private extension Double { var asInt: Int { Int(self) } }

private func numericKg(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let nf = NumberFormatter(); nf.locale = .current; nf.numberStyle = .decimal
    if let n = nf.number(from: trimmed) { return n.doubleValue }
    if let d = Double(trimmed.replacingOccurrences(of: ",", with: ".")) { return d }
    if let n = nf.number(from: trimmed.replacingOccurrences(of: ".", with: ",")) { return n.doubleValue }
    return nil
}

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
