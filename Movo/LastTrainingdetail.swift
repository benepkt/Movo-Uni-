import SwiftUI
import HealthKit

struct LastTrainingDetailView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var sessionManager: TrainingSessionManager

    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var authService: AuthService
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    
    let trainingHistory: [TrainingEntry]
    let lastTrainingDate: Date?
    
    // NEW: State for filters and actions
    @State private var deleteCandidate: TrainingEntry?
    @State private var emojiCandidate: TrainingEntry?
    @State private var showNewTraining = false
    @State private var healthKitWorkouts: [HKWorkout] = []
    @State private var filter: HistoryFilter = .movo
    @StateObject private var healthManager = HealthKitManager()
    @State private var selectedDate: Date? = nil
    @State private var showDatePicker = false
    
    enum HistoryFilter: String, CaseIterable, Identifiable {
        case movo = "Movo"
        case appleHealth = "Apple Health"
        case all = "Alle"
        var id: String { rawValue }
    }
    
    // Stats
    private var totalSessions: Int {
        filteredHistory.count
    }
    
    private var thisWeekSessions: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return 0 }
        return filteredHistory.filter { $0.date >= startOfWeek }.count
    }
    
    private var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var checkDate = calendar.startOfDay(for: Date())
        
        while true {
            let hasTraining = filteredHistory.contains { entry in
                calendar.isDate(entry.date, inSameDayAs: checkDate)
            }
            
            if hasTraining {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }
    
    // NEW: Filtered history based on filter and date
    private var filteredHistory: [TrainingEntry] {
        let cal = Calendar.current
        var entries: [TrainingEntry] = []
        
        if filter == .all || filter == .movo {
            entries.append(contentsOf: trainingHistory)
        }
        
        if filter == .all || filter == .appleHealth {
            let hkEntries = healthKitWorkouts.map { convert($0) }
            entries.append(contentsOf: hkEntries)
        }
        
        if let date = selectedDate {
            entries = entries.filter { cal.isDate($0.date, inSameDayAs: date) }
        }
        
        return entries
    }
    
    private var recentTrainings: [TrainingEntry] {
        filteredHistory.sorted { $0.date > $1.date }
    }
    
    private var appLocale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }
    
    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func localizedOrDefault(_ key: String, de: String, en: String) -> String {
        let v = appSettings.localized(key)
        if v == key { return isDE ? de : en }
        return v
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                lastTrainingBackground

                ScrollView {
                    VStack(spacing: 22) {
                    lastTrainingHero
                    
                    // 2. Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        HistoryStatCard(
                            title: appSettings.localized("lastTraining.stat.totalSessions"),
                            value: "\(totalSessions)",
                            icon: "dumbbell.fill",
                            color: .purple
                        )
                        HistoryStatCard(
                            title: appSettings.localized("lastTraining.stat.thisWeek"),
                            value: "\(thisWeekSessions)",
                            icon: "calendar",
                            color: .blue
                        )
                        HistoryStatCard(
                            title: appSettings.localized("lastTraining.stat.currentStreak"),
                            value: String(
                                format: appSettings.localized("lastTraining.stat.currentStreak.value"),
                                currentStreak
                            ),
                            icon: "flame.fill",
                            color: .orange
                        )
                        HistoryStatCard(
                            title: appSettings.localized("lastTraining.stat.avgPerWeek"),
                            value: String(
                                format: appSettings.localized("lastTraining.stat.avgPerWeek.value"),
                                Double(totalSessions) / max(1, Double(weeksActive()))
                            ),
                            icon: "chart.bar.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // NEW: Filter Bar
                    filterBar
                    
                    if showDatePicker {
                        datePickerSection
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // 3. Recent Trainings (with swipe actions)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(appSettings.localized("lastTraining.recent.title"))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                        
                        if recentTrainings.isEmpty {
                            ContentUnavailableView(
                                appSettings.localized("lastTraining.empty.title"),
                                systemImage: "dumbbell",
                                description: Text(appSettings.localized("lastTraining.empty.description"))
                            )
                            .frame(height: 200)
                            .foregroundStyle(.white)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(recentTrainings, id: \.id) { training in
                                    NavigationLink {
                                        TrainingDetailView(training: training)
                                            .environmentObject(trainingStore)
                                            .environmentObject(appSettings)
                                    } label: {
                                        TrainingRowView(training: training, appSettings: appSettings, t: t)
                                    }
                                    .buttonStyle(.plain)
                                    // NEW: Swipe Actions
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteCandidate = training
                                        } label: {
                                            Label(localizedOrDefault("history.menu.delete", de: "Löschen", en: "Delete"), systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            repeatWorkout(training)
                                        } label: {
                                            Label(localizedOrDefault("history.menu.repeat", de: "Wiederholen", en: "Repeat"), systemImage: "gobackward")
                                        }
                                        .tint(.blue)
                                        
                                        Button {
                                            saveAsTemplate(training)
                                        } label: {
                                            Label(localizedOrDefault("history.menu.saveTemplate", de: "Als Vorlage", en: "Save as template"), systemImage: "doc.on.doc")
                                        }
                                        .tint(.purple)
                                    }
                                    // NEW: Context Menu
                                    .contextMenu {
                                        Button {
                                            repeatWorkout(training)
                                        } label: {
                                            Label(localizedOrDefault("history.menu.repeat", de: "Wiederholen", en: "Repeat"), systemImage: "gobackward")
                                        }
                                        Button {
                                            saveAsTemplate(training)
                                        } label: {
                                            Label(localizedOrDefault("history.menu.saveTemplate", de: "Als Vorlage speichern", en: "Save as template"), systemImage: "doc.on.doc")
                                        }
                                        Button(role: .destructive) {
                                            deleteCandidate = training
                                        } label: {
                                            Label(localizedOrDefault("history.menu.delete", de: "Löschen", en: "Delete"), systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // 4. Motivation Section
                    if totalSessions > 0 {
                        VStack(spacing: 12) {
                            Image(systemName: currentStreak >= 7 ? "trophy.fill" : "star.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(currentStreak >= 7 ? .yellow : t.palette.primary)
                            
                            Text(getMotivationalMessage())
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                            
                            Text(getMotivationalSubtext())
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.58))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            Color.white.opacity(0.08)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 30)
                .padding(.top, 18)
                }
            }
            .background(navigationLinks())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                ensureHKAuthAndFetchIfNeeded()
            }
            .onChange(of: filter) { _ in
                ensureHKAuthAndFetchIfNeeded()
            }
        }
        
        // NEW: Delete Alert
        .alert(
            localizedOrDefault("history.alert.delete.title", de: "Training löschen?", en: "Delete workout?"),
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            actions: {
                Button(localizedOrDefault("common.delete", de: "Löschen", en: "Delete"), role: .destructive) {
                    guard let entry = deleteCandidate else { return }
                    Task {
                        await syncService.uiDeleteTraining(id: entry.id)
                    }
                    deleteCandidate = nil
                }
                Button(localizedOrDefault("common.cancel", de: "Abbrechen", en: "Cancel"), role: .cancel) {
                    deleteCandidate = nil
                }
            },
            message: {
                Text({
                    let f = DateFormatter()
                    f.locale = appLocale
                    f.dateStyle = .medium
                    f.timeStyle = .short
                    let msg = localizedOrDefault("history.alert.delete.message",
                                                 de: "Eintrag vom %@ wirklich löschen?",
                                                 en: "Really delete entry from %@?")
                    let date = deleteCandidate?.date ?? Date()
                    return String(format: msg, f.string(from: date))
                }())
            }
        )
        
        // NEW: Emoji Picker (optional - can be added later if needed)
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
        .transaction { tx in
            if deleteCandidate != nil || emojiCandidate != nil { tx.disablesAnimations = true }
        }
    }

    private var lastTrainingBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [t.palette.primary.opacity(0.36), Color.blue.opacity(0.15), .clear],
                center: .topLeading,
                startRadius: 24,
                endRadius: 460
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color.cyan.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    private var lastTrainingHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(appSettings.localized("lastTraining.title"))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(lastTrainingSubtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(t.palette.primary)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(.white.opacity(0.1)))
                    .overlay(Circle().stroke(.white.opacity(0.13), lineWidth: 1))
            }

            if let lastDate = lastTrainingDate {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatLastTrainingDate(lastDate))
                            .font(.system(size: 25, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(lastDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer()
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }

    private var lastTrainingSubtitle: String {
        if lastTrainingDate == nil {
            return appSettings.localized("lastTraining.none")
        }
        return isDE ? "Deine letzten Einheiten und schnellen Aktionen." : "Your recent sessions and quick actions."
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(HistoryFilter.allCases) { f in
                        Button {
                            filter = f
                        } label: {
                            HStack {
                                Text({
                                    switch f {
                                    case .movo:
                                        return localizedOrDefault("history.filter.movo", de: "Movo", en: "Movo")
                                    case .appleHealth:
                                        return localizedOrDefault("history.filter.health", de: "Apple Health", en: "Apple Health")
                                    case .all:
                                        return localizedOrDefault("history.filter.all", de: "Alle", en: "All")
                                    }
                                }())
                                if filter == f {
                                    Spacer(minLength: 8)
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text({
                            switch filter {
                            case .movo:
                                return localizedOrDefault("history.filter.movo", de: "Movo", en: "Movo")
                            case .appleHealth:
                                return localizedOrDefault("history.filter.health", de: "Apple Health", en: "Apple Health")
                            case .all:
                                return localizedOrDefault("history.filter.all", de: "Alle", en: "All")
                            }
                        }())
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.09))
                    .foregroundStyle(.white)
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation { showDatePicker.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        let placeholder = localizedOrDefault("history.datePicker.placeholder", de: "Datum", en: "Date")
                        Text(selectedDate?.formatted(date: .abbreviated, time: .omitted) ?? placeholder)
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
                    .background(selectedDate != nil ? t.palette.primary.opacity(0.22) : Color.white.opacity(0.09))
                    .foregroundStyle(selectedDate != nil ? t.palette.primary : .white)
                    .overlay(Capsule().stroke(selectedDate != nil ? t.palette.primary.opacity(0.5) : .white.opacity(0.12), lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    
    private var datePickerSection: some View {
        DatePicker(
            localizedOrDefault("history.datePicker.title", de: "Datum wählen", en: "Choose date"),
            selection: Binding(
                get: { selectedDate ?? Date() },
                set: { selectedDate = $0 }
            ),
            displayedComponents: .date
        )
        .environment(\.locale, appLocale)
        .datePickerStyle(.graphical)
        .padding()
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        .tint(t.palette.primary)
        .colorScheme(.dark)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Navigation Links
    
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

                    .environmentObject(healthManager)
            } label: { EmptyView() }
        }
        .frame(width: 0, height: 0)
    }
    
    // MARK: - Actions
    
    private func repeatWorkout(_ entry: TrainingEntry) {
        sessionManager.startTraining(title: entry.title, source: "last_training_repeat")
        for ex in entry.exercises { sessionManager.addExercise(ex.name) }
        sessionManager.activities = entry.activities
        sessionManager.persistSnapshotIfNeeded()
        AnalyticsService.trackWorkoutStarted(source: "last_training_repeat")
        showNewTraining = true
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    
    private func saveAsTemplate(_ entry: TrainingEntry) {
        let exercises = entry.exercises.map { $0.name }
        guard !exercises.isEmpty || !entry.activities.isEmpty else { return }
        
        let t = TrainingTemplate(
            name: entry.title.isEmpty
                ? String(format: localizedOrDefault("history.template.fromDate", de: "Vorlage vom %@", en: "Template from %@"),
                         entry.date.formatted(date: .abbreviated, time: .omitted))
                : entry.title,
            exercises: exercises,
            activities: entry.activities,
            ownerId: "local"
        )
        templateStore.add(t)
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    
    // MARK: - HealthKit
    
    private func ensureHKAuthAndFetchIfNeeded() {
        guard filter == .appleHealth || filter == .all else { return }
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
            title = localizedOrDefault("workout.type.run.outdoor", de: "Laufen draußen", en: "Outdoor Run"); emoji = "🏃‍♂️"
        case .walking:
            title = localizedOrDefault("workout.type.walk.outdoor", de: "Gehen draußen", en: "Outdoor Walk"); emoji = "🚶"
        case .cycling:
            title = localizedOrDefault("workout.type.cycling", de: "Radfahren", en: "Cycling"); emoji = "🚴"
        case .swimming:
            title = localizedOrDefault("workout.type.swimming", de: "Schwimmen", en: "Swimming"); emoji = "🏊"
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            title = localizedOrDefault("workout.type.strength", de: "Krafttraining", en: "Strength Training"); emoji = "🏋️‍♂️"
        case .yoga:
            title = localizedOrDefault("workout.type.yoga", de: "Yoga", en: "Yoga"); emoji = "🧘‍♂️"
        case .hiking:
            title = localizedOrDefault("workout.type.hiking", de: "Wandern", en: "Hiking"); emoji = "🥾"
        default:
            title = localizedOrDefault("workout.type.generic", de: "Workout", en: "Workout"); emoji = "💪"
        }
        
        let duration = workout.duration
        
        let distanceKm = healthDistanceKm(for: workout)
        let calories = healthCalories(for: workout)
        let avgHeartRate = healthAverageHeartRate(for: workout)
        let elevation = healthElevationGain(for: workout)
        let isIndoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
        
        return TrainingEntry(
            id: workout.uuid,
            date: workout.startDate,
            title: title,
            exercises: [],
            duration: duration,
            totalWeight: 0,
            emoji: emoji,
            updatedAt: workout.endDate,
            routePolyline: nil,
            cardioType: title,
            distanceKm: distanceKm,
            activeCalories: calories,
            averageHeartRate: avgHeartRate,
            elevationGainM: elevation,
            activityNote: healthActivityNote(for: workout),
            healthSourceName: workout.sourceRevision.source.name,
            healthDeviceName: workout.device?.name,
            healthWorkoutActivityRaw: workout.workoutActivityType.rawValue,
            isIndoorWorkout: isIndoor
        )
    }

    private func healthDistanceKm(for workout: HKWorkout) -> Double? {
        let identifiers: [HKQuantityTypeIdentifier]
        switch workout.workoutActivityType {
        case .cycling:
            identifiers = [.distanceCycling]
        case .swimming:
            identifiers = [.distanceSwimming]
        case .running, .walking, .hiking:
            identifiers = [.distanceWalkingRunning]
        default:
            return nil
        }

        for identifier in identifiers {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier),
                  let quantity = workout.statistics(for: type)?.sumQuantity() else { continue }
            let value = quantity.doubleValue(for: .meterUnit(with: .kilo))
            if value > 0 { return value }
        }

        if let distance = workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)), distance > 0 {
            return distance
        }
        return nil
    }

    private func healthCalories(for workout: HKWorkout) -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let quantity = workout.statistics(for: type)?.sumQuantity() else {
            return workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        }
        let value = quantity.doubleValue(for: .kilocalorie())
        return value > 0 ? value : nil
    }

    private func healthAverageHeartRate(for workout: HKWorkout) -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let quantity = workout.statistics(for: type)?.averageQuantity() else { return nil }
        let value = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        return value > 0 ? value : nil
    }

    private func healthElevationGain(for workout: HKWorkout) -> Double? {
        if let quantity = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            let value = quantity.doubleValue(for: .meter())
            return value > 0 ? value : nil
        }
        return nil
    }

    private func healthActivityNote(for workout: HKWorkout) -> String? {
        var parts: [String] = []
        parts.append("Apple Health")
        parts.append(workout.sourceRevision.source.name)
        if let device = workout.device?.name, !device.isEmpty {
            parts.append(device)
        }
        if let indoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool {
            parts.append(indoor ? localizedOrDefault("workout.location.indoor", de: "Indoor", en: "Indoor") : localizedOrDefault("workout.location.outdoor", de: "Outdoor", en: "Outdoor"))
        }
        return parts.joined(separator: " · ")
    }
    
    // MARK: - Original Helper Functions
    
    private func formatLastTrainingDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return appSettings.localized("date.today")
        } else if calendar.isDateInYesterday(date) {
            return appSettings.localized("date.yesterday")
        } else {
            let days = calendar.dateComponents([.day],
                                               from: calendar.startOfDay(for: date),
                                               to: calendar.startOfDay(for: Date())).day ?? 0
            if days < 7 {
                return String(format: appSettings.localized("date.daysAgo"), days)
            } else {
                let weeks = max(1, days / 7)
                if weeks == 1 {
                    return appSettings.localized("date.oneWeekAgo")
                } else {
                    return String(format: appSettings.localized("date.weeksAgo"), weeks)
                }
            }
        }
    }
    
    private func weeksActive() -> Int {
        guard let firstTraining = filteredHistory.min(by: { $0.date < $1.date })?.date else { return 1 }
        let calendar = Calendar.current
        let weeks = calendar.dateComponents([.weekOfYear], from: firstTraining, to: Date()).weekOfYear ?? 1
        return max(1, weeks)
    }
    
    private func getMotivationalMessage() -> String {
        if currentStreak >= 30 {
            return appSettings.localized("lastTraining.motivation.30")
        } else if currentStreak >= 14 {
            return appSettings.localized("lastTraining.motivation.14")
        } else if currentStreak >= 7 {
            return appSettings.localized("lastTraining.motivation.7")
        } else if totalSessions >= 50 {
            return appSettings.localized("lastTraining.motivation.50")
        } else if totalSessions >= 20 {
            return appSettings.localized("lastTraining.motivation.20")
        } else {
            return appSettings.localized("lastTraining.motivation.default")
        }
    }
    
    private func getMotivationalSubtext() -> String {
        if currentStreak >= 7 {
            return appSettings.localized("lastTraining.motivation.sub.streak7")
        } else if thisWeekSessions >= 3 {
            return appSettings.localized("lastTraining.motivation.sub.weekGood")
        } else {
            return appSettings.localized("lastTraining.motivation.sub.default")
        }
    }
}

// MARK: - History Stat Card

private struct HistoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(color.opacity(0.17)))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Training Row

struct TrainingRowView: View {
    let training: TrainingEntry
    let appSettings: AppSettings
    let t: DesignTokens

    private var isCardio: Bool {
        if let ct = training.cardioType, !ct.isEmpty {
            return true
        }
        return training.exercises.isEmpty
    }

    private var iconName: String {
        guard isCardio else { return "dumbbell.fill" }
        let type = (training.cardioType ?? training.title).lowercased()
        if type.contains("walk") || type.contains("gehen") { return "figure.walk" }
        if type.contains("cycle") || type.contains("rad") { return "figure.outdoor.cycle" }
        if type.contains("swim") || type.contains("schwimm") { return "figure.pool.swim" }
        if type.contains("hike") || type.contains("wander") { return "figure.hiking" }
        if type.contains("yoga") { return "figure.yoga" }
        if type.contains("hiit") { return "flame.fill" }
        return "figure.run"
    }

    private var accent: Color {
        isCardio ? t.palette.primary : .purple
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 48, height: 48)
                if let emoji = training.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(training.title.isEmpty ? appSettings.localized("training.training") : training.title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(training.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))

                    if !training.exercises.isEmpty {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.36))
                        Text("\(training.exercises.count) \(appSettings.localized("history.exercises"))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                    } else {
                        let seconds = Int(training.duration)
                        if seconds > 0 {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.36))
                            Text(formatDuration(seconds))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.52))
                        }
                    }
                }

                if !metricChips.isEmpty {
                    FlowChipRow(items: metricChips, tint: accent)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.28))
                .padding(.top, 17)
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var metricChips: [String] {
        if isCardio {
            var chips: [String] = []
            if let distance = training.loggedDistanceKm, distance > 0 {
                chips.append(String(format: "%.2f km", distance))
            }
            if let calories = training.activeCalories {
                chips.append("\(Int(calories.rounded())) kcal")
            }
            if let heartRate = training.averageHeartRate {
                chips.append("\(Int(heartRate.rounded())) bpm")
            }
            if let elevation = training.elevationGainM {
                chips.append("+\(Int(elevation.rounded())) m")
            }
            if let effort = training.perceivedEffort {
                chips.append("\(effort)/10")
            }
            return chips
        }

        var chips = [formatDuration(Int(training.duration))]
        if training.totalWeight > 0 {
            chips.append("\(Int(training.totalWeight.rounded())) kg")
        }
        return chips
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 60 {
            return String(
                format: appSettings.localized("time.minutes.short"),
                minutes
            )
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(
                format: appSettings.localized("time.hoursMinutes.short"),
                hours,
                mins
            )
        }
    }
}

private struct FlowChipRow: View {
    let items: [String]
    let tint: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                chips
            }

            VStack(alignment: .leading, spacing: 7) {
                chips
            }
        }
    }

    private var chips: some View {
        ForEach(items.prefix(5), id: \.self) { item in
            Text(item)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(Capsule().fill(tint.opacity(0.16)))
                .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 1))
        }
    }
}

// MARK: - Emoji Picker (reused from TrainingHistoryDetailView)
private struct EmojiGridPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appSettings: AppSettings
    @Binding var selection: String?
    
    private let emojis = ["💪","🔥","🦵","🦾","⭐️","🏋️‍♂️","🚴‍♀️","🤸‍♂️","🏃‍♂️","⛰️","🧘‍♂️","🥊","⚡️","🎯","🧱"]
    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 14)]
    
    @State private var customEmoji: String = ""
    
    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func localizedOrDefault(_ key: String, de: String, en: String) -> String {
        let v = appSettings.localized(key)
        if v == key { return isDE ? de : en }
        return v
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(localizedOrDefault("emoji.custom.title", de: "Eigenes Emoji", en: "Custom emoji"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    
                    HStack(spacing: 10) {
                        TextField(localizedOrDefault("emoji.custom.placeholder", de: "Emoji einfügen …", en: "Paste emoji …"), text: Binding(
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
                        .accessibilityLabel(localizedOrDefault("emoji.custom.accept", de: "Dieses Emoji übernehmen", en: "Use this emoji"))
                    }
                    .padding(.horizontal, 16)
                    
                    Text(localizedOrDefault("emoji.suggestions", de: "Vorschläge", en: "Suggestions"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    
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
            .navigationTitle(localizedOrDefault("emoji.title", de: "Emoji wählen", en: "Choose emoji"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizedOrDefault("common.remove", de: "Entfernen", en: "Remove")) {
                        selection = nil
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedOrDefault("common.done", de: "Fertig", en: "Done")) { dismiss() }
                }
            }
        }
    }
    
    private func pick(_ e: String) {
        selection = e
        #if os(iOS)
        UIImpactFeedbackGenerator().impactOccurred()
        #endif
        dismiss()
    }
}
