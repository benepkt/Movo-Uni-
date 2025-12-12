import SwiftUI

struct WeeklyProgressCard: View {
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings
    
    // Data
    let streak: Int
    let trainingHistory: [TrainingEntry]
    let steps: Int
    let stepsGoal: Int
    
    // Actions
    var onOpenSteps: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    
    // Computed
    private var progress: Double {
        guard stepsGoal > 0 else { return 0 }
        return min(Double(steps) / Double(stepsGoal), 1.0)
    }
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Find start of current week (Monday)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        guard let startOfWeek = calendar.date(from: components) else { return [] }
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 1. Top: Weekly Checkmarks (Moved up)
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    DayStatusView(date: date, history: trainingHistory)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
            

            
            // 3. Bottom: Steps
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(appSettings.localized("home.steps.title"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(steps)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("/ \(stepsGoal)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(t.palette.primary) // Green usually
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onOpenSteps?()
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
    }
}

// Helper View for Day Status
struct DayStatusView: View {
    let date: Date
    let history: [TrainingEntry]
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var isFuture: Bool {
        date > Date()
    }
    
    private var hasTraining: Bool {
        history.contains { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: date)
        }
    }
    
    private var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "E" // Mon, Tue...
        return f.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Circle Indicator
            ZStack {
                if hasTraining {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    // Empty state
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    if isToday {
                        // Highlight today if no training yet
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            
            // Day Name
            Text(dayName.prefix(1)) // M, T, W...
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isToday ? .primary : .secondary)
        }
    }
}
