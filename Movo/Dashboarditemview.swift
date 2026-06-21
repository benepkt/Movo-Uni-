import SwiftUI

enum DashboardItem: String, CaseIterable, Identifiable, Codable {
    case steps
    case sleep
    case calories
    case water
    case weight
    case lastTraining

    var id: String { rawValue }

    static var defaultHomeItems: [DashboardItem] {
        [.steps, .calories, .weight, .lastTraining]
    }

    var isHomeVisible: Bool {
        switch self {
        case .water, .sleep:
            return false
        case .steps, .calories, .weight, .lastTraining:
            return true
        }
    }

    func title(using settings: AppSettings) -> String {
        switch self {
        case .steps:       return settings.localized("steps.unit")
        case .sleep:       return settings.localized("common.sleep")
        case .calories:    return settings.localized("common.calories")
        case .water:       return settings.localized("common.water")
        case .weight:      return settings.localized("common.weight")
        case .lastTraining:return settings.localized("dashboard.lastTraining")
        }
    }

    var icon: String {
        switch self {
        case .steps:       return "figure.walk"
        case .sleep:       return "moon.fill"
        case .calories:    return "flame.fill"
        case .water:       return "drop.fill"
        case .weight:      return "scalemass.fill"
        case .lastTraining:return "dumbbell.fill"
        }
    }

    var color: Color {
        switch self {
        case .steps:       return .green
        case .sleep:       return .indigo
        case .calories:    return .orange
        case .water:       return .cyan
        case .weight:      return .blue
        case .lastTraining:return .purple
        }
    }
}

// MARK: - Edit Dashboard



struct EditDashboardView: View {
    @Binding var activeItems: [DashboardItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings

    // Ziele
    @AppStorage("goals.workoutsPerWeek") private var weeklyGoal: Int = 3
    @AppStorage("profile.hasGoalWeight") private var hasGoalWeight: Bool = false
    @AppStorage("profile.goalWeightKg")  private var goalWeightKg: Double = 75.0

    // Items, die NICHT aktiv sind
    private var availableItems: [DashboardItem] {
        DashboardItem.allCases.filter { $0.isHomeVisible && !activeItems.contains($0) }
    }

    private var appLocale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Ziele
                    goalSettingsSection

                    // MARK: Mein Dashboard
                    VStack(alignment: .leading, spacing: 12) {
                        Text(appSettings.localized("dashboard.myDashboard"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(activeItems) { item in
                                HBoxItem(item: item, isAdded: true) {
                                    withAnimation {
                                        if let idx = activeItems.firstIndex(of: item) {
                                            activeItems.remove(at: idx)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .id(activeItems.map { $0.id }.joined())
                    }

                    // MARK: Weitere Statistiken
                    if !availableItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(appSettings.localized("dashboard.additionalStats"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            VStack(spacing: 12) {
                                ForEach(availableItems) { item in
                                    HBoxItem(item: item, isAdded: false) {
                                        withAnimation {
                                            activeItems.append(item)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .id(availableItems.map { $0.id }.joined())
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appSettings.localized("dashboard.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                activeItems = activeItems.filter { $0.isHomeVisible }
                if activeItems.isEmpty {
                    activeItems = DashboardItem.defaultHomeItems
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                        .font(.headline)
                }
            }
        }
    }

    // MARK: Ziel-Section

    private var goalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appSettings.localized("dashboard.goalSettings.title"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Weekly workouts
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "figure.run")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appSettings.localized("dashboard.goalSettings.weeklyWorkouts"))
                            .font(.body.weight(.semibold))
                        Text(
                            String(
                                format: appSettings.localized("dashboard.goalSettings.weeklyWorkouts.value"),
                                weeklyGoal
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Stepper("", value: $weeklyGoal, in: 1...14)
                        .labelsHidden()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Weight goal
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appSettings.localized("dashboard.goalSettings.weight"))
                            .font(.body.weight(.semibold))

                        Text(hasGoalWeight ? "\(formatWeight(goalWeightKg)) kg" : "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Stepper(
                        "",
                        onIncrement: {
                            hasGoalWeight = true
                            goalWeightKg = min(goalWeightKg + 0.5, 300)
                        },
                        onDecrement: {
                            hasGoalWeight = true
                            goalWeightKg = max(goalWeightKg - 0.5, 30)
                        }
                    )
                    .labelsHidden()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            }
            .padding(.horizontal)
        }
    }

    private func formatWeight(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = appLocale
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    // MARK: - List Item

    struct HBoxItem: View {
        let item: DashboardItem
        let isAdded: Bool
        let action: () -> Void

        @EnvironmentObject var appSettings: AppSettings
        @Environment(\.designTokens) private var t

        var body: some View {
            HStack(spacing: 16) {
                Button(action: action) {
                    Image(systemName: isAdded ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isAdded ? .red : .green)
                }

                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundStyle(item.color)
                    .frame(width: 30)

                Text(item.title(using: appSettings))
                    .font(.body.weight(.semibold))

                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct GoalSettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    // Wochenziel (Workouts/Woche)
    @AppStorage("goals.workoutsPerWeek") private var workoutsPerWeek: Int = 3

    // Gewichtsziele
    @AppStorage("profile.weightGoalKg") private var weightGoalKg: Double = 75
    @AppStorage("profile.weightKg") private var currentWeightKg: Double = 0

    private var locale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }

    var body: some View {
        NavigationStack {
            Form {
                // WEEKLY GOAL
                Section(header: Text(appSettings.localized("home.weeklyGoal.title"))) {
                    Stepper(
                        value: $workoutsPerWeek,
                        in: 1...14
                    ) {
                        Text(
                            String(
                                format: appSettings.localized("home.weeklyGoal.targetFormat"),
                                workoutsPerWeek
                            )
                        )
                    }

                    Text(appSettings.localized("home.weeklyGoal.description"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // WEIGHT GOAL
                Section(header: Text(appSettings.localized("weight.goal.title"))) {
                    HStack {
                        Text(appSettings.localized("weight.current"))
                        Spacer()
                        Text(currentWeightKg > 0 ? "\(formatWeight(currentWeightKg)) kg" : "—")
                            .foregroundStyle(.secondary)
                    }

                    Stepper(
                        value: $weightGoalKg,
                        in: 30...250,
                        step: 0.5
                    ) {
                        Text("\(formatWeight(weightGoalKg)) kg")
                    }

                    Text(appSettings.localized("weight.goal.hint"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .environment(\.locale, locale)
            .navigationTitle(appSettings.localized("dashboard.goalSettings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                }
            }
        }
    }

    private func formatWeight(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
