import SwiftUI

struct LastTrainingDetailView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    
    let trainingHistory: [TrainingEntry]
    let lastTrainingDate: Date?
    
    // Stats
    private var totalSessions: Int {
        trainingHistory.count
    }
    
    private var thisWeekSessions: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return 0 }
        return trainingHistory.filter { $0.date >= startOfWeek }.count
    }
    
    private var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var checkDate = calendar.startOfDay(for: Date())
        
        while true {
            let hasTraining = trainingHistory.contains { entry in
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
    
    private var recentTrainings: [TrainingEntry] {
        trainingHistory.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }
    
    private var appLocale: Locale {
        let code = appSettings.language.lowercased().hasPrefix("de") ? "de_DE" : "en_US"
        return Locale(identifier: code)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Header / Last Training
                    VStack(spacing: 8) {
                        Text(appSettings.localized("lastTraining.header"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        if let lastDate = lastTrainingDate {
                            VStack(spacing: 4) {
                                Text(formatLastTrainingDate(lastDate))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(.purple)
                                
                                Text(lastDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(appSettings.localized("lastTraining.none"))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // 2. Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatBox(
                            title: appSettings.localized("lastTraining.stat.totalSessions"),
                            value: "\(totalSessions)",
                            icon: "dumbbell.fill",
                            color: .purple
                        )
                        StatBox(
                            title: appSettings.localized("lastTraining.stat.thisWeek"),
                            value: "\(thisWeekSessions)",
                            icon: "calendar",
                            color: .blue
                        )
                        StatBox(
                            title: appSettings.localized("lastTraining.stat.currentStreak"),
                            value: String(
                                format: appSettings.localized("lastTraining.stat.currentStreak.value"),
                                currentStreak
                            ),
                            icon: "flame.fill",
                            color: .orange
                        )
                        StatBox(
                            title: appSettings.localized("lastTraining.stat.avgPerWeek"),
                            value: String(
                                format: appSettings.localized("lastTraining.stat.avgPerWeek.value"),
                                Double(totalSessions) / max(1, Double(weeksActive()))
                            ),
                            icon: "chart.bar.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                    
                    // 3. Recent Trainings
                    VStack(alignment: .leading, spacing: 16) {
                        Text(appSettings.localized("lastTraining.recent.title"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if recentTrainings.isEmpty {
                            ContentUnavailableView(
                                appSettings.localized("lastTraining.empty.title"),
                                systemImage: "dumbbell",
                                description: Text(appSettings.localized("lastTraining.empty.description"))
                            )
                            .frame(height: 200)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(recentTrainings, id: \.id) { training in
                                    TrainingRowView(training: training, appSettings: appSettings, t: t)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // 4. Motivation Section
                    if totalSessions > 0 {
                        VStack(spacing: 12) {
                            Image(systemName: currentStreak >= 7 ? "trophy.fill" : "star.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(currentStreak >= 7 ? .yellow : .purple)
                            
                            Text(getMotivationalMessage())
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                            
                            Text(getMotivationalSubtext())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appSettings.localized("lastTraining.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(appSettings.localized("settings.done")) { dismiss() }
                }
            }
        }
    }
    
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
        guard let firstTraining = trainingHistory.min(by: { $0.date < $1.date })?.date else { return 1 }
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
        isCardio ? "figure.run" : "dumbbell.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .foregroundStyle(.purple)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(training.title.isEmpty ? appSettings.localized("training.training") : training.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(training.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !training.exercises.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(training.exercises.count) \(appSettings.localized("history.exercises"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        let seconds = Int(training.duration)
                        if seconds > 0 {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(formatDuration(seconds))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
