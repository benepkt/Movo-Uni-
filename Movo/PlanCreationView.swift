import SwiftUI

struct PlanCreationView: View {
    private let editingProgram: TrainingProgram?

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var challengeStore: ChallengeStore
    @EnvironmentObject var templateStore: TemplateStore
    @Environment(\.dismiss) var dismiss

    @State private var planTitle = ""
    @State private var durationWeeks = 8
    @State private var isUnlimited = false
    @State private var smartOrderingEnabled = true
    @State private var selectedDays: Set<Int> = [2, 4, 6] // Default Mon, Wed, Fri
    @State private var selectedTemplateIds: [String] = []

    private let durationOptions = [4, 6, 8, 12, 16]

    init(existingProgram: TrainingProgram? = nil) {
        self.editingProgram = existingProgram
        _planTitle = State(initialValue: existingProgram?.title ?? "")
        _durationWeeks = State(initialValue: existingProgram?.durationWeeks ?? 8)
        _isUnlimited = State(initialValue: existingProgram?.isUnlimited ?? false)
        _smartOrderingEnabled = State(initialValue: existingProgram?.smartOrderingEnabled ?? true)
        _selectedDays = State(initialValue: existingProgram.map { Set($0.schedule.keys) } ?? [2, 4, 6])

        let routineIds = existingProgram?.schedule
            .sorted { $0.key < $1.key }
            .map(\.value)
            .reduce(into: [String]()) { result, id in
                if !result.contains(id) { result.append(id) }
            }
        _selectedTemplateIds = State(initialValue: routineIds ?? [])
    }

    private var availableTemplates: [TrainingTemplate] {
        var seen = Set<String>()
        return (templateStore.allTemplates + (editingProgram?.routines ?? [])).filter { template in
            guard !seen.contains(template.id) else { return false }
            seen.insert(template.id)
            return true
        }
    }

    private var selectedTemplates: [TrainingTemplate] {
        selectedTemplateIds.compactMap { id in
            availableTemplates.first(where: { $0.id == id })
        }
    }

    private var ownTemplates: [TrainingTemplate] {
        availableTemplates.filter { !isMovoTemplate($0) }
    }

    private var movoTemplates: [TrainingTemplate] {
        availableTemplates.filter { isMovoTemplate($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PlanBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        titleSection
                        daysSection
                        durationSection
                        smartOrderingSection
                        templateSection
                        schedulePreviewSection
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 18)
                }

                floatingActionButton
            }
            .navigationTitle(editingProgram == nil ? "Plan bauen" : "Plan bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 52, height: 52)
                    .background(Color.cyan)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trainingsplan erstellen")
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Kombiniere mehrere Templates zu einem Plan, den du teilen, bearbeiten und per QR importieren kannst.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var titleSection: some View {
        planSection(title: "Name") {
            TextField("z. B. Push Pull Legs", text: $planTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(16)
                .background(.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var daysSection: some View {
        planSection(title: "Trainingstage") {
            VStack(alignment: .leading, spacing: 12) {
                DayPicker(selectedDays: $selectedDays)
                Text("\(selectedDays.count) Tage pro Woche")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
    }

    private var durationSection: some View {
        planSection(title: "Laufzeit") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(durationOptions, id: \.self) { weeks in
                        Button {
                            withAnimation(.snappy) {
                                isUnlimited = false
                                durationWeeks = weeks
                            }
                        } label: {
                            Text("\(weeks)W")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(!isUnlimited && durationWeeks == weeks ? .black : .white.opacity(0.72))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(!isUnlimited && durationWeeks == weeks ? Color.cyan : .white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    withAnimation(.snappy) { isUnlimited.toggle() }
                } label: {
                    HStack {
                        Image(systemName: isUnlimited ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .bold))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Unbegrenzt")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("Der Plan läuft weiter und zählt einfach die absolvierten Wochen.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isUnlimited ? .black.opacity(0.58) : .white.opacity(0.48))
                        }
                        Spacer()
                    }
                    .foregroundStyle(isUnlimited ? .black : .white.opacity(0.72))
                    .padding(14)
                    .background(isUnlimited ? Color.cyan : .white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var smartOrderingSection: some View {
        planSection(title: "Smart Reihenfolge") {
            Button {
                withAnimation(.snappy) { smartOrderingEnabled.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: smartOrderingEnabled ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(smartOrderingEnabled ? Color.cyan : .white.opacity(0.36))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatisch nächste Einheit wählen")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Wenn Push zuletzt dran war, schlägt Movo als nächstes Pull, Beine oder die nächste passende Plan-Einheit vor.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.48))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(14)
                .background(smartOrderingEnabled ? Color.cyan.opacity(0.16) : Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(smartOrderingEnabled ? Color.cyan.opacity(0.65) : .white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var templateSection: some View {
        planSection(title: "Templates") {
            VStack(alignment: .leading, spacing: 16) {
                if !ownTemplates.isEmpty {
                    templateGroup(title: "Eigene Templates", templates: ownTemplates)
                }

                if !movoTemplates.isEmpty {
                    templateGroup(title: "Movo Templates", templates: movoTemplates)
                }
            }
        }
    }

    private func templateGroup(title: String, templates: [TrainingTemplate]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.52))
                .textCase(.uppercase)

            VStack(spacing: 10) {
                ForEach(templates) { template in
                    templateSelectionRow(template)
                }
            }
        }
    }

    @ViewBuilder
    private var schedulePreviewSection: some View {
        if !selectedTemplates.isEmpty {
            planSection(title: "Vorschau") {
                VStack(spacing: 10) {
                    ForEach(Array(selectedDays.sorted().enumerated()), id: \.element) { index, day in
                        let template = selectedTemplates[index % selectedTemplates.count]
                        HStack {
                            Text(dayName(for: day))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white.opacity(0.58))
                                .frame(width: 34, alignment: .leading)
                            Text(template.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.26))
                        }
                        .padding(12)
                        .background(.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            Button(action: savePlan) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                    Text(editingProgram == nil ? "Plan speichern" : "Änderungen speichern")
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canSave ? Color.cyan : Color.white.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
    }

    private var canSave: Bool {
        !selectedTemplates.isEmpty && !selectedDays.isEmpty
    }

    private func planSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            content()
        }
        .padding(16)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func templateSelectionRow(_ template: TrainingTemplate) -> some View {
        let isSelected = selectedTemplateIds.contains(template.id)
        return Button {
            withAnimation(.snappy) {
                if isSelected {
                    selectedTemplateIds.removeAll { $0 == template.id }
                } else {
                    selectedTemplateIds.append(template.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? Color.cyan : .white.opacity(0.36))

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(template.exercises.count) Übungen\(template.activities.isEmpty ? "" : " · \(template.activities.count) Aktivitäten")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? Color.cyan.opacity(0.16) : Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? Color.cyan.opacity(0.65) : .white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func isMovoTemplate(_ template: TrainingTemplate) -> Bool {
        template.ownerId == "builtin" || template.ownerId == "movo" || templateStore.isDefault(template)
    }

    private func savePlan() {
        guard canSave else { return }

        let templates = selectedTemplates
        let days = selectedDays.sorted()
        var schedule: [Int: String] = [:]
        for (index, day) in days.enumerated() {
            schedule[day] = templates[index % templates.count].id
        }

        let title = planTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let program = TrainingProgram(
            id: editingProgram?.id ?? UUID().uuidString,
            title: title.isEmpty ? "Mein Trainingsplan" : title,
            description: "\(templates.count) Templates · \(days.count) Trainingstage pro Woche · \(isUnlimited ? "unbegrenzt" : "\(durationWeeks) Wochen").",
            difficulty: templates.count >= 4 || days.count >= 5 ? .advanced : (days.count >= 4 ? .intermediate : .beginner),
            durationWeeks: durationWeeks,
            isUnlimited: isUnlimited,
            smartOrderingEnabled: smartOrderingEnabled,
            routines: templates,
            schedule: schedule
        )

        if editingProgram == nil {
            challengeStore.startProgram(program)
        } else {
            challengeStore.upsertProgram(program)
        }
        let movoCount = templates.filter { isMovoTemplate($0) }.count
        AnalyticsService.trackPlanSaved(
            isEditing: editingProgram != nil,
            templateCount: templates.count,
            trainingDaysPerWeek: days.count,
            durationWeeks: durationWeeks,
            isUnlimited: isUnlimited,
            smartOrderingEnabled: smartOrderingEnabled,
            movoTemplateCount: movoCount,
            ownTemplateCount: templates.count - movoCount
        )
        dismiss()
    }

    private func dayName(for day: Int) -> String {
        switch day {
        case 1: return "So"
        case 2: return "Mo"
        case 3: return "Di"
        case 4: return "Mi"
        case 5: return "Do"
        case 6: return "Fr"
        case 7: return "Sa"
        default: return "\(day)"
        }
    }
}

struct PlanBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.03, blue: 0.05),
                Color(red: 0.04, green: 0.07, blue: 0.10),
                Color(red: 0.01, green: 0.02, blue: 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Components

struct PlanGoalCard: View {
    let goal: PlanGoal
    let isSelected: Bool
    
    var body: some View {
        VStack {
            Image(systemName: icon(for: goal))
                .font(.largeTitle)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.bottom, 4)
            
            Text(goal.rawValue)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
    }
    
    func icon(for goal: PlanGoal) -> String {
        switch goal {
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .strength: return "dumbbell.fill"
        case .endurance: return "figure.run"
        case .weightLoss: return "flame.fill"
        }
    }
}

struct DayPicker: View {
    @Binding var selectedDays: Set<Int>
    
    // 2=Mon ... 7=Sat, 1=Sun
    // Order: Mon, Tue, Wed, Thu, Fri, Sat, Sun
    let days = [2, 3, 4, 5, 6, 7, 1]
    let dayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { pair in
                let index = pair.offset
                let day = pair.element
                let isSelected = selectedDays.contains(day)
                
                Button(action: {
                    withAnimation(.spring()) {
                        if isSelected {
                            selectedDays.remove(day)
                        } else {
                            if selectedDays.count < 6 { // Max limit
                                selectedDays.insert(day)
                            }
                        }
                    }
                }) {
                    VStack {
                        Text(String(dayLabels[index].prefix(1)))
                            .font(.headline)
                        Text(String(dayLabels[index].dropFirst())) // Hidden but keeps layout if needed
                            .font(.caption2)
                            .opacity(0.0)
                            .frame(height: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isSelected ? Color.cyan : Color.white.opacity(0.08))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.72))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }
}
