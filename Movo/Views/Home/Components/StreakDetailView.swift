import SwiftUI

struct StreakDetailView: View {
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    // Semantic Colors
    private var cardBg: Color { Color(.secondarySystemGroupedBackground) }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground).ignoresSafeArea()
            
            VStack {
                // Card
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Top Row: Flame + "Streak 32 Days" + Icon
                    HStack(alignment: .top) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appSettings.localized("streak.title").uppercased()) // "STREAK"
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            let s = trainingStore.smartStreakDays(reference: Date(), maxGap: 2)
                            Text("\(s) \(appSettings.localized("streak.days").uppercased())") // "DAYS" / "TAGE"
                                .font(.title.bold())
                                .foregroundStyle(.primary)
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                        
                        Image(systemName: "figure.step.training") // Similar to footprint icon
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Week Row (Checkmarks)
                    HStack(spacing: 0) {
                        ForEach(0..<7) { index in
                            // Day logic
                            let dayLabel = orderedWeekdaySymbols[index] // Mon, Tue...
                            let isCompleted = isDayCompleted(offsetOverride: index)
                            
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .stroke(isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                                        .frame(width: 36, height: 36)
                                    
                                    if isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white) // Checkmark on green circle -> white
                                            .background(Circle().fill(Color.green).frame(width: 32, height: 32))
                                    }
                                }
                                
                                Text(dayLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Steps Section removed as requested
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(cardBg)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(appSettings.localized("profile.close")) { dismiss() } // "Close" / "Schließen"
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(.top, 40)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible) // Standard indicator
    }
    
    // MARK: - Helpers
    
    // Auto-localized weekdays
    private var orderedWeekdaySymbols: [String] {
        var cal = Calendar.current
        cal.locale = Locale(identifier: appSettings.language)
        // Shift so Monday is first (if needed, or just follow calendar)
        // We want Mon..Sun fixed for visual consistency? 
        // Better: Use user's calendar short symbols but rotated to start on Monday if the view design forces Mon-Sun.
        // Let's assume Mon-Sun fixed.
        let symbols = cal.shortWeekdaySymbols
        let firstDay = cal.firstWeekday // usually 1 (Sun) or 2 (Mon)
        
        // If we want fixed Mon->Sun:
        // symbols usually ["Sun", "Mon", ...]
        // We want ["Mon", ..., "Sun"]
        if symbols.count == 7 {
            let sun = symbols[0]
            let others = symbols.dropFirst()
            return Array(others) + [sun]
        }
        return symbols
    }
    
    private func isDayCompleted(offsetOverride: Int) -> Bool {
        let cal = Calendar.current
        let today = Date()
        
        // "This Week" logic: Start from Monday of current week
        // We want to map offsetOverride (0..6) to (Mon..Sun)
        
        // Find the Monday of the current week
        // 1. Get components for year/week
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let startOfWeek = cal.date(from: comps) else { return false }
        
        // 2. Adjust to Monday (if startOfWeek is Sunday)
        // Note: This depends on Locale. In US, startOfWeek is Sunday.
        // We want Monday to be index 0 of our UI.
        // So we need to find the Monday that belongs to this week.
        
        var mondayDate = startOfWeek
        if cal.firstWeekday == 1 { // Sunday is start
             // check if today is Sunday, then Monday was 6 days ago? No, week starts Sunday.
             // If we display Mon-Sun, we want the Monday of *this* week representation.
             mondayDate = cal.date(byAdding: .day, value: 1, to: startOfWeek)!
        }
        
        // Calculate target date
        guard let targetDate = cal.date(byAdding: .day, value: offsetOverride, to: mondayDate) else { return false }
        
        // Check history
        return trainingStore.history.contains { entry in
            cal.isDate(entry.date, inSameDayAs: targetDate)
        }
    }
}
