// Onboarding Screens - Phase 2: Feature Showcases (Iteration 3 & 4 & 5 & 6 Final Polish)
// Screen 15: Easy Logging (Tutorial - Realistic Mock)
// Screen 16: Social Feed Showcase (Restored Scrolling Animation)
// Screen 17: Review Request (Restored Text)

import SwiftUI
import StoreKit
import UIKit
import HealthKit
import Combine

// MARK: - Screen 15: Easy Logging (Realistic Tutorial)
struct EasyLoggingScreen: View {
    var onNext: (() -> Void)? = nil
    
    // Environment objects for template loading
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    // Selected template state
    @State private var selectedTemplate: TrainingTemplate?
    
    // Tutorial State
    enum TutorialState {
        case selectTemplate
        case logSet
        case finished
    }

    // Tutorial Flow Steps
    enum TutorialStep {
        case logFirstSet
        case checkTimer
        case addExercise
        case finish
    }
    
    @State private var tutorialStep: TutorialStep = .logFirstSet
    
    // Mock Data Models
    struct MockSet: Identifiable {
        let id = UUID()
        var weight: String
        var reps: String
        var isCompleted: Bool = false
    }
    
    @State private var state: TutorialState = .selectTemplate
    @State private var sets: [MockSet] = [
        MockSet(weight: "60", reps: "10") // Initial set
    ]
    
    // UI State for Interactivity
    @State private var isTimerRunning = false
    @State private var showInfo = false
    @State private var timerString = "01:00"
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                switch state {
                case .selectTemplate:
                    SelectTemplateStepView(
                        title: titleForState,
                        subtitle: subtitleForState,
                        templates: templateStore.allTemplates,
                        onSelectTemplate: { template in
                            selectedTemplate = template
                            loadTemplateExercises(template)
                            withAnimation(.spring()) { state = .logSet }
                        }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    
                case .logSet:
                    LogSetStepView(onNext: onNext)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    
                case .finished:
                    FinishedStepView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Spacer()
        }
    }
    
    // MARK: - Language helpers
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
     
    private var titleForState: String {
        switch state {
        case .selectTemplate:
            return localizedOnboarding("onboarding.easyLogging.title")
        case .logSet:
            return localizedOnboarding("onboarding.trackIt.title")
        case .finished:
            return localizedOnboarding("onboarding.finished.title")
        }
    }
    
    private var subtitleForState: String {
        switch state {
        case .selectTemplate:
            return localizedOnboarding("onboarding.easyLogging.subtitle")
        case .logSet:
            return localizedOnboarding("onboarding.trackIt.subtitle")
        case .finished:
            return localizedOnboarding("onboarding.finished.subtitle")
        }
    }


// MARK: - Template Loading

    private func loadTemplateExercises(_ template: TrainingTemplate) {
        // Clear existing exercises
        sessionManager.exercises.removeAll()
        
        // Load template exercises
        for exerciseName in template.exercises {
            sessionManager.addExercise(exerciseName)
        }
        
        // Set training title to template name
        sessionManager.trainingTitle = template.name
    }
}

private struct EasyLoggingHeaderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .animation(.none, value: title)
                .padding(.horizontal)
            
            Text(subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .animation(.none, value: subtitle)
        }
    }
}

private struct SelectTemplateStepView: View {
    let title: String
    let subtitle: String
    let templates: [TrainingTemplate]
    let onSelectTemplate: (TrainingTemplate) -> Void
    
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Scrollable Header
                EasyLoggingHeaderView(title: title, subtitle: subtitle)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(localizedOnboarding("templates.section.custom"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    // Display real templates
                    ForEach(templates) { template in
                        TemplateCard(template: template) {
                            onSelectTemplate(template)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// Template Card Component
private struct TemplateCard: View {
    let template: TrainingTemplate
    let onTap: () -> Void
    
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }
    
    private var cardColor: Color {
        // Use primary as default accent; keep some basic mapping by name
        let primary = t.palette.primary
        switch template.name.lowercased() {
        case let name where name.contains("push"):
            return primary
        case let name where name.contains("pull"):
            return .purple
        case let name where name.contains("leg"):
            return .orange
        case let name where name.contains("upper"):
            return .blue
        case let name where name.contains("lower"):
            return .red
        case let name where name.contains("full"):
            return .green
        case let name where name.contains("cardio"), let name where name.contains("core"):
            return .pink
        case let name where name.contains("arm"):
            return .cyan
        default:
            return primary
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3)
                        .foregroundStyle(cardColor)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizedOnboarding(template.name))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 12) {
                        Label("\(template.exercises.count) Exercises", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(cardColor)
            }
            .padding(16)
            .background(Color.dsFieldBG)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Functional Training View (replaces tutorial mock)
private struct LogSetStepView: View {
    var onNext: (() -> Void)? = nil
    
    // Real training functionality
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var healthKit: HealthKitManager
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var syncService: SyncService
    
    @Environment(\.designTokens) private var t
    @Environment(\.dismiss) private var dismiss
    
    // Exercise management
    @State private var showExercisePicker = false
    @State private var exerciseSearchText = ""
    @State private var selectedExerciseInfo: ExerciseInfo?
    
    // Rest timer
    @State private var showPauseTimer = false
    @StateObject private var pauseTimer = OnbPauseTimer()
    @State private var pauseSheetDetent: PresentationDetent = PresentationDetent.fraction(0.6)
    
    // Heart rate
    @State private var showHRInfo = false
    
    // Save/Complete
    @State private var showSummary = false
    @State private var lastSavedEntry: TrainingEntry?
    @State private var rewardMessage: RewardMessage? = nil
    
    // Date
    @State private var date = Date()
    
    // Weight unit
    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg
    @AppStorage("onboarding.language") private var onboardingLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private func localizedOnboarding(_ key: String) -> String {
        let dict = onboardingLanguage == "de" ? LocalizedStrings.de : LocalizedStrings.en
        return dict[key] ?? key
    }

    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            topMeta
                            timerRow
                            actionsRow
                            addExerciseButton
                            exerciseList
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            NavigationStack {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(localizedOnboarding("common.search"), text: $exerciseSearchText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsFieldBG))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dsOutline, lineWidth: 0.5))
                    .padding()

                    List {
                        Section {
                            if exerciseLibrary.exercises.filter({ $0.name.localizedCaseInsensitiveContains(exerciseSearchText) || exerciseSearchText.isEmpty }).isEmpty {
                                if !exerciseSearchText.isEmpty {
                                    Button {
                                        let trimmed = exerciseSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !trimmed.isEmpty else { return }
                                        exerciseLibrary.addExercise(trimmed)
                                        sessionManager.addExercise(trimmed)
                                        showExercisePicker = false
                                        exerciseSearchText = ""
                                    } label: {
                                        Label(String(format: localizedOnboarding("training.addExercise.new"), exerciseSearchText), systemImage: "plus")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                }
                            } else {
                                ForEach(exerciseLibrary.exercises.filter({ $0.name.localizedCaseInsensitiveContains(exerciseSearchText) || exerciseSearchText.isEmpty }), id: \.self) { info in
                                    HStack {
                                        Text(info.localizedName(using: appSettings))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Button {
                                            showExercisePicker = false
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                selectedExerciseInfo = info
                                            }
                                        } label: {
                                            Image(systemName: "info.circle").font(.title3)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.primary)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        sessionManager.addExercise(info.name)
                                        showExercisePicker = false
                                        exerciseSearchText = ""
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                .navigationTitle(localizedOnboarding("training.addExercise"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizedOnboarding("common.cancel")) {
                            showExercisePicker = false
                            exerciseSearchText = ""
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPauseTimer) {
            OnbPauseTimerSheet(timer: pauseTimer, accent: t.palette.primary)
                .presentationDetents([PresentationDetent.fraction(0.72), PresentationDetent.large], selection: $pauseSheetDetent)
                .presentationDragIndicator(SwiftUI.Visibility.visible)
        }
        .sheet(isPresented: $showHRInfo) {
            OnbHeartRateInfoSheet(
                bpm: healthKit.currentHeartRate.map { Int($0) },
                isMonitoring: healthKit.isHeartRateMonitoringActive,
                onStart: {
                    Task {
                        if let type = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                            await healthKit.requestReadAuthorizationIfNeeded(readTypes: [type], forcePrompt: true)
                            healthKit.startHeartRateStreaming(filterToAppleWatch: false)
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedExerciseInfo) { info in
            ExerciseDetailView(exerciseInfo: info)
                .environmentObject(trainingStore)
        }
        .sheet(isPresented: $showSummary) {
            if let entry = lastSavedEntry {
                WorkoutSummaryView(
                    entry: entry,
                    streakWeeks: nil,
                    weekProgress: Array(repeating: false, count: 7)
                ) {
                    showSummary = false
                    dismiss()
                    
                }
            }
        }
        .overlay(alignment: .center) {
            if let msg = rewardMessage {
                RewardPopupInline(text: msg.text, icon: msg.icon, color: msg.color)
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { rewardMessage = nil }
                        }
                    }
            }
        }
    }
    
    private var topMeta: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Training title
            TextField(localizedOnboarding("training.title.placeholder"),
                      text: $sessionManager.trainingTitle)
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dsFieldBG)
            .cornerRadius(12)
            
            HStack(spacing: 12) {
                // Date picker
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                    DatePicker("", selection: $date, displayedComponents: [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .controlSize(.small)
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.dsChipBG)
                .cornerRadius(8)
                .foregroundStyle(.white)
                
                // Elapsed time
                Label(formatTime(sessionManager.elapsedTime), systemImage: "clock")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.dsChipBG)
                    .cornerRadius(8)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return "\(m)m \(s)s"
    }
    
    private var timerRow: some View {
        HStack(spacing: 16) {
            // Rest Timer - functional
            Button {
                showPauseTimer = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: pauseTimer.isRunning ? "pause.circle.fill" : "timer")
                        .foregroundStyle(.white)
                    Text(pauseTimer.isRunning ? formatTimerRemaining(pauseTimer.remaining) : localizedOnboarding("rest"))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .font(.headline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(pauseTimer.isRunning ? t.palette.primary : Color.dsChipBG)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Heart Rate - functional
            Button {
                showHRInfo = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color.red)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                    Text(healthKit.currentHeartRate.map { "\(Int($0))" } ?? "--")
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .font(.headline.bold())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    private func formatTimerRemaining(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private var actionsRow: some View {
        HStack(spacing: 12) {
            Button {
                // Navigate to next onboarding screen (same as "Weiter")
                withAnimation {
                    // Reset session for next time
                    sessionManager.exercises.removeAll()
                    sessionManager.trainingTitle = ""
                }
                // Call onNext to proceed to next onboarding screen
                onNext?()
            } label: {
                Text(localizedOnboarding("training.save"))
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(t.palette.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Button {
                toggleAllCompletion()
            } label: {
                Image(systemName: sessionManager.exercises.flatMap { $0.sets }.allSatisfy { $0.isCompleted } ? "arrow.counterclockwise" : "checkmark.circle.fill")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(Color.dsChipBG)
                    .foregroundStyle(t.palette.primary)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func toggleAllCompletion() {
        let allCompleted = sessionManager.exercises.flatMap { $0.sets }.allSatisfy { $0.isCompleted }
        for i in sessionManager.exercises.indices {
            for j in sessionManager.exercises[i].sets.indices {
                sessionManager.exercises[i].sets[j].isCompleted = !allCompleted
            }
        }
    }
    
    private func toggleAllLabel() -> String {
        let allCompleted = sessionManager.exercises.flatMap { $0.sets }.allSatisfy { $0.isCompleted }
        return localizedOnboarding(allCompleted ? "training.resetAll" : "training.completeAll")
    }
    
    private func save() {
        gm.addXP(80)
        gm.addCoins(10)
        
        let newEntry = TrainingEntry(
            date: date,
            title: sessionManager.trainingTitle.isEmpty
                ? localizedOnboarding("training.training")
                : sessionManager.trainingTitle,
            exercises: sessionManager.exercises,
            duration: sessionManager.elapsedTime,
            totalWeight: calculateTotalWeight(),
            emoji: nil,
            updatedAt: Date()
        )
        
        completeSave(entry: newEntry)
    }
    
    private func completeSave(entry: TrainingEntry) {
        trainingStore.add(entry: entry)
        
        Task { await syncService.saveProfile(level: gm.level, xp: gm.xp, coins: gm.coins) }
        
        withAnimation {
            rewardMessage = RewardMessage(text: "+80 XP & +10 Coins",
                                          icon: "star.fill",
                                          color: t.palette.primary)
        }
        
        gm.unlockBadge(.firstWorkout)
        if gm.streak == 7 { gm.unlockBadge(.streak7) }
        
        sessionManager.reset()
        
        lastSavedEntry = entry
        showSummary = true
    }
    
    private func calculateTotalWeight() -> Double {
        sessionManager.exercises.reduce(0.0) { total, exercise in
            total + exercise.sets.reduce(0.0) { setTotal, set in
                setTotal + parseWeightString(set.weight)
            }
        }
    }
    
    private func parseWeightString(_ text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
            return d
        }
        return 0
    }
    
    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                Text(localizedOnboarding("training.addExercise"))
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(t.palette.primary)
            .background(Color.dsFieldBG)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var exerciseList: some View {
        VStack(spacing: 16) {
            ForEach(Array(sessionManager.exercises.enumerated()), id: \.offset) { index, exercise in
                exerciseCard(for: index, exercise: exercise)
            }
        }
    }
    
    @ViewBuilder
    private func exerciseCard(for index: Int, exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Exercise header
            HStack {
                Text(localizedOnboarding(exercise.name))
                    .font(.headline.bold())
                    .foregroundStyle(t.palette.primary)
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        if let info = exerciseLibrary.exercises.first(where: { $0.name == exercise.name }) {
                            selectedExerciseInfo = info
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: "line.3.horizontal")
                }
                .font(.title3)
                .foregroundStyle(Color.gray)
            }
            
            // Last session suggestion
            if let lastSet = lastSetSuggestion(for: exercise.name) {
                Button {
                    applySuggestion(lastSet, toExerciseIndex: index)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("\(Int(lastSet.kg))kg × \(lastSet.reps)")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.dsChipBG)
                    .foregroundStyle(t.palette.primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Sets list
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, _ in
                setRow(exerciseIndex: index, setIndex: setIndex)
            }
            
            // Add set button
            Button {
                sessionManager.addSet(to: index)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(localizedOnboarding("training.addSet"))
                }
                .font(.subheadline.bold())
                .foregroundStyle(t.palette.primary)
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.dsFieldBG)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func setRow(exerciseIndex: Int, setIndex: Int) -> some View {
        HStack(spacing: 12) {
            // Weight field
            HStack(spacing: 6) {
                TextField("0",
                          text: $sessionManager.exercises[exerciseIndex].sets[setIndex].weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .bold()
                Text(weightUnit.rawValue)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .frame(width: 80, height: 44)
            .background(Color.dsChipBG)
            .cornerRadius(12)
            
            // Reps field
            HStack(spacing: 6) {
                TextField("0",
                          text: $sessionManager.exercises[exerciseIndex].sets[setIndex].reps)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .bold()
                Text("reps")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .frame(width: 80, height: 44)
            .background(Color.dsChipBG)
            .cornerRadius(12)
            
            Spacer()
            
            // Complete button
            Button {
                sessionManager.toggleSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
            } label: {
                Circle()
                    .strokeBorder(
                        sessionManager.exercises[exerciseIndex].sets[setIndex].isCompleted
                            ? t.palette.primary
                            : Color.white.opacity(0.3),
                        lineWidth: 2
                    )
                    .background(
                        Circle().fill(
                            sessionManager.exercises[exerciseIndex].sets[setIndex].isCompleted
                                ? t.palette.primary
                                : Color.clear
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(sessionManager.exercises[exerciseIndex].sets[setIndex].isCompleted ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    // Helper functions for suggestions
    private func lastSetSuggestion(for exerciseName: String) -> (kg: Double, reps: Int, date: Date)? {
        let sorted = trainingStore.history.sorted { $0.date > $1.date }
        for entry in sorted {
            if let ex = entry.exercises.first(where: { $0.name == exerciseName }) {
                for set in ex.sets.reversed() {
                    let kg = parseWeightString(set.weight)
                    let reps = Int(set.reps.filter("0123456789".contains)) ?? 0
                    if kg > 0, reps > 0 {
                        return (kg, reps, entry.date)
                    }
                }
            }
        }
        return nil
    }
    
    private func applySuggestion(_ suggestion: (kg: Double, reps: Int, date: Date), toExerciseIndex index: Int) {
        guard sessionManager.exercises.indices.contains(index) else { return }
        for i in sessionManager.exercises[index].sets.indices {
            let currentWeight = parseWeightString(sessionManager.exercises[index].sets[i].weight)
            let currentReps = sessionManager.exercises[index].sets[i].reps.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if currentWeight == 0 && currentReps.isEmpty {
                sessionManager.exercises[index].sets[i].weight = String(format: "%.1f", suggestion.kg)
                sessionManager.exercises[index].sets[i].reps = "\(suggestion.reps)"
            }
        }
    }
}

private struct TutorialTooltipView: View {
    let text: String
    var arrowUp: Bool = false
    let dismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if arrowUp {
                 Image(systemName: "arrowtriangle.up.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .offset(y: 5)
            }
            
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.blue)
                .cornerRadius(8)
            
            if !arrowUp {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .offset(y: -5)
            }
        }
        .onTapGesture {
            dismiss()
        }
    }
}

private struct SetsListView: View {
    @Binding var sets: [EasyLoggingScreen.MockSet]
    @Binding var tutorialStep: EasyLoggingScreen.TutorialStep
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach($sets) { $set in
                HStack(spacing: 12) {
                    HStack {
                        TextField("0", text: $set.weight)
                            .bold()
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(width: 80, height: 44)
                    .background(Color.dsChipBG)
                    .cornerRadius(12)
                    
                    HStack {
                        TextField("0", text: $set.reps)
                            .bold()
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                        Text("reps")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(width: 80, height: 44)
                    .background(Color.dsChipBG)
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            set.isCompleted.toggle()
                            if set.isCompleted && tutorialStep == .logFirstSet {
                                tutorialStep = .checkTimer
                            }
                        }
                    } label: {
                        Circle()
                            .strokeBorder(set.isCompleted ? .blue : Color.white.opacity(0.3), lineWidth: 2)
                            .background(Circle().fill(set.isCompleted ? .blue : Color.clear))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .opacity(set.isCompleted ? 1 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FinishedStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.yellow)
                .padding(.bottom, 10)
            
            Text("Movo Session Logged")
                .font(.title2.bold())
            
            Text("Simple. Powerful.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}




// MARK: - Screen 17: Reviews (Restored "Support a Solo Developer")
struct ReviewsScreen: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var hasRequested = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "star.bubble.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.yellow)
            
            Text(appSettings.localized("onboarding.reviews.title") != "onboarding.reviews.title" ? appSettings.localized("onboarding.reviews.title") : "Support a Solo Developer")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(appSettings.localized("onboarding.reviews.subtitle") != "onboarding.reviews.subtitle" ? appSettings.localized("onboarding.reviews.subtitle") : "Hi! Your feedback helps us make Movo better every day.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .onAppear {
            // Delay 2.5s before prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if !hasRequested {
                    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                        hasRequested = true
                    }
                }
            }
        }
    }
}

#if canImport(UIKit)
extension UIApplication {
    /// Schließt die Tastatur, indem der First Responder resigniert.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - Helper Components for Training View
// Umbenannte, lokale Varianten, um Kollisionen mit globalen Typen zu vermeiden.

// PauseTimer class for rest timer functionality
private final class OnbPauseTimer: ObservableObject {
    enum State { case idle, running, paused, finished }

    @Published var state: State = .idle
    @Published var total: TimeInterval = 60
    @Published var remaining: TimeInterval = 60
    @Published var progress: CGFloat = 1.0

    var onFinished: (() -> Void)?

    private var cancellable: AnyCancellable?
    private var startDate: Date?
    private var elapsedBeforePause: TimeInterval = 0

    func configure(total seconds: TimeInterval) {
        total = max(1, seconds)
        remaining = total
        progress = 1
        state = .idle
        cancelTimer()
    }

    func start() {
        guard total > 0 else { return }
        remaining = total
        progress = 1
        elapsedBeforePause = 0
        startDate = Date()
        state = .running
        runTimer()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        elapsedBeforePause += Date().timeIntervalSince(startDate ?? Date())
        cancelTimer()
    }

    func resume() {
        guard state == .paused else { return }
        startDate = Date()
        state = .running
        runTimer()
    }

    func add(seconds: TimeInterval) {
        guard state == .running || state == .paused || state == .idle else { return }
        total = max(1, total + seconds)
        remaining = max(0, remaining + seconds)
        progress = total > 0 ? CGFloat(remaining / total) : 0
    }

    func reset() {
        cancelTimer()
        remaining = total
        progress = 1
        elapsedBeforePause = 0
        state = .idle
    }

    private func finish() {
        cancelTimer()
        remaining = 0
        progress = 0
        state = .finished
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        onFinished?()
    }

    private func runTimer() {
        cancelTimer()
        let startRef = startDate ?? Date()
        let baseElapsed = elapsedBeforePause
        cancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.state == .running else { return }
                let elapsed = baseElapsed + Date().timeIntervalSince(startRef)
                let rem = max(0, self.total - elapsed)
                self.remaining = rem
                self.progress = self.total > 0 ? CGFloat(rem / self.total) : 0
                if rem <= 0.0001 { self.finish() }
            }
    }

    private func cancelTimer() {
        cancellable?.cancel(); cancellable = nil
    }
}

private extension OnbPauseTimer {
    var isRunning: Bool { state == .running || state == .paused }
}

// PauseTimerSheet UI
private struct OnbPauseTimerSheet: View {
    @ObservedObject var timer: OnbPauseTimer
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    var accent: Color = .accentColor

    @State private var minutes: Int = 1
    @State private var seconds: Int = 0

    private let presets: [Int] = [30, 45, 60, 90, 120]

    private var clampedProgress: CGFloat {
        max(CGFloat(0.001), min(CGFloat(1), timer.progress))
    }
    
    private var isGerman: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Label(isGerman ? "Pause" : "Rest", systemImage: "pause.circle.fill")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)

            content()
                .padding(.horizontal)

            footer
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .onAppear {
            if timer.state == .idle {
                minutes = max(0, Int(timer.total) / 60)
                seconds = Int(timer.total) % 60
            }
        }
    }

    @ViewBuilder
    private func content() -> some View {
        switch timer.state {
        case .idle:
            idleConfigurator
        case .running, .paused, .finished:
            runningView
        }
    }

    private var idleConfigurator: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { s in
                        Button {
                            minutes = s / 60
                            seconds = s % 60
                            timer.configure(total: TimeInterval(s))
                        } label: {
                            Text(label(for: s))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                        }
                        .dsChip()
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(spacing: 12) {
                Picker(isGerman ? "Minuten" : "Minutes", selection: $minutes) {
                    ForEach(0..<61, id: \.self) { Text("\($0)m").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker(isGerman ? "Sekunden" : "Seconds", selection: $seconds) {
                    ForEach(0..<60, id: \.self) { Text("\($0)s").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 160)
            .dsField(corner: 18)

            Button {
                let total = TimeInterval(minutes * 60 + seconds)
                timer.configure(total: total > 0 ? total : 1)
                timer.start()
            } label: {
                Label(isGerman ? "Start" : "Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var runningView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.25), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [accent, accent.opacity(0.5), accent]),
                                        center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: timer.progress)

                Text(formatMMSS(timer.remaining))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 240, height: 240)
            .padding(.vertical, 4)

            HStack(spacing: 10) {
                addButton("+15s", 15)
                addButton("+30s", 30)
                addButton("+1m", 60)
            }

            HStack(spacing: 12) {
                switch timer.state {
                case .running:
                    Button { timer.pause() } label: {
                        Label(isGerman ? "Pause" : "Pause", systemImage: "pause.fill").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.bordered)
                case .paused:
                    Button { timer.resume() } label: {
                        Label(isGerman ? "Weiter" : "Resume", systemImage: "play.fill").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                case .finished:
                    Button { timer.reset() } label: {
                        Label(isGerman ? "Zurücksetzen" : "Reset", systemImage: "gobackward").frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.bordered)
                case .idle:
                    EmptyView()
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if timer.state == .running || timer.state == .paused {
                Button(role: .destructive) { timer.reset() } label: {
                    Label(appSettings.localized("common.cancel"), systemImage: "xmark")
                }
            }
            Spacer()
            if timer.state == .finished {
                Button {
                    timer.reset()
                    dismiss()
                } label: {
                    Label(appSettings.localized("common.done"), systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func addButton(_ title: String, _ seconds: TimeInterval) -> some View {
        Button(title) { timer.add(seconds: seconds) }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .dsChip()
    }

    private func label(for seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    private func formatMMSS(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// HeartRateInfoSheet (umbenannt)
private struct OnbHeartRateInfoSheet: View {
    let bpm: Int?
    let isMonitoring: Bool
    let onStart: () -> Void

    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.12)).frame(width: 44, height: 44)
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Herzfrequenz")
                            .font(.headline)
                        Text(isMonitoring ? "Live aktiv" : "Inaktiv")
                            .font(.footnote)
                            .foregroundStyle(isMonitoring ? .green : .secondary)
                    }
                    Spacer()
                    Text(bpm.map { "\($0) bpm" } ?? "—")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.horizontal)

                // Kurz erklärt
                VStack(alignment: .leading, spacing: 8) {
                    Text("So funktioniert's")
                        .font(.subheadline.weight(.semibold))
                    Text("Movo liest deine Herzfrequenz aus Apple Health. Mit Apple Watch oder kompatiblen Kopfhörern (z. B. AirPods) erhältst du oft aktuellere Werte.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsFieldBG))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsOutline, lineWidth: 0.5))
                .padding(.horizontal)

                // Aktionen
                VStack(spacing: 10) {
                    Button {
                        onStart()
                    } label: {
                        Label("Live‑HR starten", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showDetails = true
                    } label: {
                        Label("Details anzeigen", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Spacer(minLength: 8)
            }
            .navigationTitle("Herzfrequenz")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDetails) {
                OnbHeartRateDetailView(
                    bpm: bpm,
                    isMonitoring: isMonitoring,
                    onClose: { showDetails = false }
                )
            }
        }
    }
}

// HeartRateDetailView (umbenannt)
private struct OnbHeartRateDetailView: View {
    let bpm: Int?
    let isMonitoring: Bool
    let onClose: () -> Void

    private var zoneText: String {
        guard let bpm else { return "—" }
        let maxHR = 190.0
        let pct = Double(bpm) / maxHR
        switch pct {
        case ..<0.6: return "Zone 1 · Leicht"
        case ..<0.7: return "Zone 2 · Locker"
        case ..<0.8: return "Zone 3 · Mittel"
        case ..<0.9: return "Zone 4 · Hart"
        default:     return "Zone 5 · Maximal"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Große Zahl
                    VStack(spacing: 8) {
                        Text(bpm.map { "\($0)" } ?? "—")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                        Text("bpm")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)

                    // Zone
                    VStack(spacing: 6) {
                        Text(zoneText)
                            .font(.title3.weight(.semibold))
                        Text(isMonitoring ? "Monitoring aktiv" : "Monitoring inaktiv")
                            .font(.footnote)
                            .foregroundStyle(isMonitoring ? .green : .secondary)
                    }

                    // Hinweise
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tipps für genauere Werte")
                            .font(.headline)
                        Text("• Trage die Watch/Kopfhörer korrekt.\n• Starte ein Training in Movo.\n• Erlaube den Health‑Zugriff für Herzfrequenz.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.dsFieldBG))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsOutline, lineWidth: 0.5))
                    .padding(.horizontal)

                    // Troubleshooting
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Kein Puls sichtbar?")
                            .font(.headline)
                        Text("• Prüfe Health‑Zugriff unter Quellen.\n• Aktiviere Bluetooth.\n• Warte einige Sekunden – HealthKit hat oft geringe Verzögerung.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.dsFieldBG))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsOutline, lineWidth: 0.5))
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("HR‑Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { onClose() }
                }
            }
        }
    }
}

// MARK: - Local inline Reward Popup (to avoid cross-file ambiguity)
private struct RewardPopupInline: View {
    let text: String
    let icon: String
    let color: Color
    @Environment(\.designTokens) private var t

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(.headline.bold())
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [t.palette.surfaceA, t.palette.surfaceB],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(t.palette.outline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        .padding()
    }
}
