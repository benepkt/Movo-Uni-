import SwiftUI
import Foundation
import CloudKit
#if os(iOS) || os(visionOS)
import UIKit
#endif

// MARK: - Haupt-View (Exercises)

struct ExercisesView: View {
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var trainingStore: TrainingStore
    @Environment(\.designTokens) private var t
    @Environment(\.colorScheme)   private var scheme

    @State private var newExercise = ""
    @State private var selectedExerciseInfo: ExerciseInfo?
    @State private var showNewExerciseSheet = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    // Request-States
    @State private var showRequestSheet = false
    @State private var requestName = ""
    @State private var requestDetails = ""

    // Feedback
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // NEW: UI State
    @State private var selectedCategory: String = "Strength" // "Strength" (Exercises) vs "Activity" (Activities)
    @State private var selectedMuscleFilter: String? = nil
    @State private var selectedEquipmentFilter: String? = nil
    @State private var selectedClassificationFilter: String? = nil
    
    // Filter Arrays
    private let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Biceps", "Triceps", "Abs", "Glutes", "Full Body", "Forearms", "Cardio"]
    private let equipmentTypes = ["Barbell", "Dumbbell", "Machine", "Cable", "Bodyweight", "Kettlebell", "Smith Machine", "Band", "Plate"]
    private let classifications = ["Compound", "Isolation", "Bilateral", "Unilateral", "Cardio", "Mobility"]

    // Filter Logic
    private var filteredExercises: [ExerciseInfo] {
        let all = exerciseLibrary.exercises
        
        return all.filter { ex in
            // 1. Category Filter
            var categoryMatch = false
            if selectedCategory == "Strength" {
                categoryMatch = (ex.category == "Strength")
            } else {
                // "Activity" tab shows Cardio + Activity
                categoryMatch = (ex.category == "Cardio" || ex.category == "Activity")
            }
            if !categoryMatch { return false }
            
            // 2. Text Search
            if !searchText.isEmpty {
                if !ex.name.localizedCaseInsensitiveContains(searchText) &&
                   !ex.muscleGroup.localizedCaseInsensitiveContains(searchText) {
                    return false
                }
            }
            
            // 3. Chip Filters
            if let muscle = selectedMuscleFilter {
                // Flexible check: primary, secondary, or legacy string
                let p = ex.primaryMuscle ?? ""
                let s = ex.secondaryMuscles ?? []
                let legacy = ex.muscleGroup
                let matchesMuscle = p.contains(muscle) || s.contains(muscle) || legacy.contains(muscle)
                if !matchesMuscle { return false }
            }
            
            if let eq = selectedEquipmentFilter {
                if ex.equipment != eq { return false }
            }
            
            if let cls = selectedClassificationFilter {
                if ex.classification != cls { return false }
            }
            
            return true
        }
    }
    
    // Grouping for Sectioned List
    private var groupedExercises: [String: [ExerciseInfo]] {
        let exercises = filteredExercises.sorted { $0.name < $1.name }
        var groups = [String: [ExerciseInfo]]()
        
        for exercise in exercises {
            let firstLetter = String(exercise.name.prefix(1)).uppercased()
            if groups[firstLetter] == nil {
                groups[firstLetter] = []
            }
            groups[firstLetter]?.append(exercise)
        }
        return groups
    }
    
    private var sortedKeys: [String] {
        groupedExercises.keys.sorted()
    }

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    private var strengthCount: Int {
        exerciseLibrary.exercises.filter { $0.category == "Strength" }.count
    }

    private var activityCount: Int {
        exerciseLibrary.exercises.filter { $0.category == "Activity" || $0.category == "Cardio" }.count
    }

    private var equipmentCount: Int {
        Set(exerciseLibrary.exercises.compactMap(\.equipment)).count
    }

    private var activitySuggestions: [ActivitySuggestion] {
        [
            .init(title: isDE ? "Laufen" : "Running", subtitle: isDE ? "Pace, Distanz und Ausdauer" : "Pace, distance and endurance", icon: "figure.run", tint: .blue),
            .init(title: isDE ? "Gehen" : "Walking", subtitle: isDE ? "Leichte Bewegung und Erholung" : "Light movement and recovery", icon: "figure.walk", tint: .mint),
            .init(title: isDE ? "Radfahren" : "Cycling", subtitle: isDE ? "Cardio ohne große Gelenkbelastung" : "Low-impact cardio work", icon: "figure.outdoor.cycle", tint: .cyan),
            .init(title: isDE ? "Mobility" : "Mobility", subtitle: isDE ? "Beweglichkeit, Warm-up und Reset" : "Mobility, warm-up and reset", icon: "figure.cooldown", tint: .indigo)
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                exerciseBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroHeader
                        filterPanel

                        if selectedCategory == "Activity" {
                            activitiesSection
                        } else {
                            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                                if filteredExercises.isEmpty {
                                    if searchText.isEmpty {
                                        emptyState.padding(.top, 12)
                                    } else {
                                        noResultsState.padding(.top, 12)
                                    }
                                } else {
                                    ForEach(sortedKeys, id: \.self) { key in
                                        Section(header: SectionHeaderView(text: key)) {
                                            ForEach(groupedExercises[key]!) { info in
                                                Button {
                                                    selectedExerciseInfo = info
                                                } label: {
                                                    ExerciseRowItem(info: info)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }

                                Spacer(minLength: 90)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                }

                fabButton
            }
            .navigationBarHidden(true)
            .navigationTitle(isDE ? "Übungen" : "Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .sheet(item: $selectedExerciseInfo) { info in
                ExerciseDetailView(exerciseInfo: info)
                    .environmentObject(trainingStore)
            }
            .sheet(isPresented: $showNewExerciseSheet) {
                NewExerciseSheet(newExercise: $newExercise, onAdd: addExercise)
                    .presentationDetents([.medium])
            }
            // Request-Sheet
            .sheet(isPresented: $showRequestSheet) {
                ExerciseRequestSheet(
                    name: $requestName,
                    details: $requestDetails,
                    onSend: { name, details in
                        guard !isSending else { return }
                        isSending = true
                        Task {
                            do {
                                try await CloudKitExerciseRequestService.shared.submit(
                                    name: name,
                                    details: details,
                                    query: searchText
                                )
                                #if os(iOS)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                #endif
                                showRequestSheet = false
                                requestName = ""
                                requestDetails = ""
                                showSuccessAlert = true
                            } catch {
                                #if os(iOS)
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                #endif
                                errorMessage = error.localizedDescription
                                showErrorAlert = true
                            }
                            isSending = false
                        }
                    }
                )
                .environmentObject(appSettings)
                .presentationDetents([.medium])
            }
            // Erfolg
            .alert(appSettings.localized("exercises.request.alert.success.title"), isPresented: $showSuccessAlert) {
                Button(appSettings.localized("common.ok")) { }
            } message: {
                Text(appSettings.localized("exercises.request.alert.success.message"))
            }
            // Fehler
            .alert(appSettings.localized("exercises.request.alert.error.title"), isPresented: $showErrorAlert) {
                Button(appSettings.localized("common.ok")) { }
            } message: {
                Text(errorMessage)
            }
        }
        // 👉 harter View-Neuaufbau beim Scheme-Wechsel (kein Ruckeln)
        .id(scheme)
        // 👉 in dieser View: keine Animation auf Scheme-Changes
        .animation(nil, value: scheme)
        .transaction { tx in tx.animation = nil }
    }

    // MARK: - Teil-Views

    private var exerciseBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [t.palette.primary.opacity(0.36), Color.cyan.opacity(0.15), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 470
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color.blue.opacity(0.18), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isDE ? "Übungen" : "Exercises")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(isDE ? "Bibliothek, Technik und Verlauf an einem Ort." : "Library, technique and history in one place.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Button {
                    showNewExerciseSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(.white.opacity(0.12)))
                        .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(appSettings.localized("exercises.addNew"))
            }

            HStack(spacing: 10) {
                summaryPill(value: "\(strengthCount)", label: isDE ? "Strength" : "Strength", icon: "dumbbell.fill")
                summaryPill(value: "\(equipmentCount)", label: isDE ? "Geräte" : "Equipment", icon: "slider.horizontal.3")
                summaryPill(value: "\(activityCount)", label: isDE ? "Aktivitäten" : "Activities", icon: "figure.run")
            }
        }
    }

    private func summaryPill(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(t.palette.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var filterPanel: some View {
        VStack(spacing: 12) {
            Picker("Category", selection: $selectedCategory) {
                Text(isDE ? "Übungen" : "Exercises").tag("Strength")
                Text(isDE ? "Aktivitäten" : "Activities").tag("Activity")
            }
            .pickerStyle(.segmented)

            searchBar

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation { selectedMuscleFilter = nil }
                    } label: {
                        ChipView(title: isDE ? "Alle" : "All", isActive: selectedMuscleFilter == nil)
                    }

                    ForEach(muscleGroups, id: \.self) { muscle in
                        Button {
                            withAnimation {
                                selectedMuscleFilter = selectedMuscleFilter == muscle ? nil : muscle
                            }
                        } label: {
                            let key = "muscle." + muscle.lowercased().replacingOccurrences(of: " ", with: "")
                            let localizedName = appSettings.localized(key)
                            let title = (localizedName == key) ? muscle : localizedName
                            ChipView(title: title, isActive: selectedMuscleFilter == muscle)
                        }
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 4)

                    Menu {
                        Button(isDE ? "Alle Geräte" : "All Equipment") { selectedEquipmentFilter = nil }
                        ForEach(equipmentTypes, id: \.self) { e in
                            Button(e) { selectedEquipmentFilter = e }
                        }
                    } label: {
                        ChipView(title: selectedEquipmentFilter ?? (isDE ? "Gerät" : "Equipment"), isActive: selectedEquipmentFilter != nil, isMenu: true)
                    }

                    Menu {
                        Button(isDE ? "Alle Arten" : "All Types") { selectedClassificationFilter = nil }
                        ForEach(classifications, id: \.self) { c in
                            Button(c) { selectedClassificationFilter = c }
                        }
                    } label: {
                        ChipView(title: selectedClassificationFilter ?? (isDE ? "Art" : "Type"), isActive: selectedClassificationFilter != nil, isMenu: true)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isDE ? "Activities" : "Activities")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(isDE ? "Schnelle Cardio- und Bewegungsmodi für später." : "Quick cardio and movement modes for later.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(activitySuggestions) { item in
                    ActivitySuggestionCard(item: item)
                }
            }

            if !filteredExercises.isEmpty {
                Text(isDE ? "Gespeicherte Activities" : "Saved Activities")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                ForEach(filteredExercises) { info in
                    Button {
                        selectedExerciseInfo = info
                    } label: {
                        ExerciseRowItem(info: info)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 90)
        }
    }

    private var searchBar: some View {
        let isDark = (scheme == .dark)

        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(appSettings.localized("exercises.search"), text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(appSettings.localized("search.clear"))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(appSettings.localized("settings.done")) { searchFocused = false }
            }
        }
    }

    private var fabButton: some View {
        let isDark = (scheme == .dark)

        return Button {
            showNewExerciseSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .padding(18)
                .background(
                    Circle()
                        .fill(t.palette.primary)
                        .shadow(color: isDark ? .black.opacity(0.25) : .black.opacity(0.18),
                                radius: isDark ? 8 : 12, x: 0, y: 6)
                )
                .foregroundStyle(.white)
        }
        .padding()
        .accessibilityLabel(appSettings.localized("exercises.addNew"))
        .animation(nil, value: scheme)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(appSettings.localized("exercises.empty.subtitle") + " or no filter match")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(scheme == .dark ? 0.06 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(scheme == .dark ? Color.white.opacity(0.12) : t.palette.outline, lineWidth: 1)
        )
    }

    // No-Results-State mit lokalisierten Strings
    private var noResultsState: some View {
        let isDark = (scheme == .dark)
        return VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(String(format: appSettings.localized("exercises.noResults.title"), searchText))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(appSettings.localized("exercises.noResults.subtitle"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                requestName = searchText
                requestDetails = ""
                showRequestSheet = true
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            } label: {
                Label {
                    Text(appSettings.localized("exercises.request.button"))
                        .font(.callout.weight(.semibold))
                } icon: {
                    Image(systemName: "paperplane.fill")
                        .imageScale(.medium)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule(style: .continuous).fill(.thinMaterial))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: isDark ? .black.opacity(0.22) : .black.opacity(0.08), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appSettings.localized("exercises.request.button"))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isDark ? 0.06 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.12) : t.palette.outline, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func addExercise() {
        let trimmed = newExercise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            exerciseLibrary.addExercise(trimmed)
            newExercise = ""
            showNewExerciseSheet = false
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            #endif
        }
    }
}

// MARK: - Components

struct ChipView: View {
    let title: String
    let isActive: Bool
    var isMenu: Bool = false
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if isMenu {
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isActive ? Color.blue.opacity(0.9) : Color.white.opacity(0.09))
        )
        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.78))
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(isActive ? 0.0 : 0.14), lineWidth: 1)
        )
    }
}

struct SectionHeaderView: View {
    let text: String
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        HStack {
            Text(text)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.66))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color.clear)
    }
}

private struct ActivitySuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
}

private struct ActivitySuggestionCard: View {
    let item: ActivitySuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: item.icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(item.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        )
    }
}

struct ExerciseRowItem: View {
    let info: ExerciseInfo
    @Environment(\.colorScheme) var scheme
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(info.localizedName(using: appSettings))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                
                // Show muscles or equipment as subtitle
                if let muscles = info.secondaryMuscles, !muscles.isEmpty {
                    let main = info.localizedMuscle(info.primaryMuscle ?? info.muscleGroup, using: appSettings)
                    let sec = muscles.map { info.localizedMuscle($0, using: appSettings) }.joined(separator: ", ")
                     Text(main + " • " + sec)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Text(info.localizedMuscle(info.primaryMuscle ?? info.muscleGroup, using: appSettings))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Request-Sheet (UI)

struct ExerciseRequestSheet: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @Binding var name: String
    @Binding var details: String
    var onSend: (_ name: String, _ details: String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(appSettings.localized("exercises.request.form.exercise"))) {
                    TextField(appSettings.localized("exercises.request.form.namePlaceholder"), text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section(header: Text(appSettings.localized("exercises.request.form.detailsHeader"))) {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
                Section(footer: Text(appSettings.localized("exercises.request.form.footer"))) {
                    EmptyView()
                }
            }
            .navigationTitle(appSettings.localized("exercises.request.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("common.send")) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSend(trimmed, details.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - CloudKit Service

final class CloudKitExerciseRequestService {
    static let shared = CloudKitExerciseRequestService()
    private init() {}

    private let container = CKContainer(identifier: "iCloud.com.benepkt.Movo")
    private var db: CKDatabase { container.publicCloudDatabase }

    func submit(name: String, details: String, query: String) async throws {
        let status = try await container.accountStatus()
        switch status {
        case .available: break
        case .noAccount: throw NSError(domain: "CloudKit", code: 1,
              userInfo: [NSLocalizedDescriptionKey: "iCloud ist auf diesem Gerät nicht eingerichtet."])
        case .restricted: throw NSError(domain: "CloudKit", code: 2,
              userInfo: [NSLocalizedDescriptionKey: "iCloud ist eingeschränkt (Screen Time/MDM?)."])
        case .couldNotDetermine: fallthrough
        @unknown default: throw NSError(domain: "CloudKit", code: 3,
              userInfo: [NSLocalizedDescriptionKey: "iCloud-Status konnte nicht ermittelt werden."])
        }

        let rec = CKRecord(recordType: "ExerciseRequest")
        rec["name"]    = name as CKRecordValue
        rec["details"] = (details.isEmpty ? "—" : details) as CKRecordValue
        rec["query"]   = (query.isEmpty ? "—" : query) as CKRecordValue
        rec["createdAt"] = Date() as CKRecordValue
        try await db.save(rec)
    }
}
