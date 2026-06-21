import SwiftUI

struct MovoScoreView: View {
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings // Added
    
    let score: Int
    let status: String
    
    // Bottom Metrics
    let recoveryValue: String
    let loadValue: String
    let sleepValue: String
    
    // Detailed Breakdown & State
    let breakdown: BodyView.MovoScoreBreakdown
    let isLoading: Bool
    
    // MARK: - Computed Status
    private var displayStatus: String {
        if isLoading {
            return "Laden..."
        }
        if sleepValue.contains("--") || sleepValue == "0h 0m" {
            // Check key existence or fallback
            return appSettings.localized("score.enterSleep") != "score.enterSleep" 
                ? appSettings.localized("score.enterSleep") 
                : "Schlaf bitte eintragen"
        }
        return status
    }
    
    var body: some View {
        VStack(spacing: 20) { // Increased spacing to prevent overlap
            // Header
            HStack {
                Text(appSettings.localized("score.title")) // "Movo Score"
                    .font(.title2.weight(.bold)) // Larger Headline
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Gauge Content
            ZStack {
                // Background Track
                ArcShape(startAngle: .degrees(135), endAngle: .degrees(405))
                    .stroke(Color.secondary.opacity(0.1), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .padding(30)
                
                // Progress Arcs (Stacked)
                // 1. Sleep (Purple) - Max 40
                let sleepAngleAmount = Double(breakdown.sleepPoints) / 100.0 * 270.0
                let sleepEnd = 135.0 + sleepAngleAmount
                
                if sleepAngleAmount > 0 {
                    ArcShape(startAngle: .degrees(135), endAngle: .degrees(sleepEnd))
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .padding(30)
                }
                
                // 2. Activity (Green) - Max 30
                let activityAngleAmount = Double(breakdown.activityPoints) / 100.0 * 270.0
                let activityStart = sleepEnd // stack
                let activityEnd = activityStart + activityAngleAmount
                
                if activityAngleAmount > 0 {
                    ArcShape(startAngle: .degrees(activityStart), endAngle: .degrees(activityEnd))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .padding(30)
                }
                
                // 3. Training (Orange) - Max 20
                let trainingAngleAmount = Double(breakdown.trainingPoints) / 100.0 * 270.0
                let trainingStart = activityEnd
                let trainingEnd = trainingStart + trainingAngleAmount
                
                if trainingAngleAmount > 0 {
                    ArcShape(startAngle: .degrees(trainingStart), endAngle: .degrees(trainingEnd))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .padding(30)
                }
                
                // 4. Recovery (Blue) - Max 10
                let recoveryAngleAmount = Double(breakdown.recoveryPoints) / 100.0 * 270.0
                let recoveryStart = trainingEnd
                let recoveryEnd = recoveryStart + recoveryAngleAmount
                
                if recoveryAngleAmount > 0 {
                    ArcShape(startAngle: .degrees(recoveryStart), endAngle: .degrees(recoveryEnd))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .padding(30)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 0) // Shadow on last element
                }
                
                // Text Info (Center)
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(value: Double(score)))
                    
                    Text(displayStatus) // Uses logic for missing sleep
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                // Soft Ticks
                TicksShape()
                    .stroke(Color.primary.opacity(0.05), lineWidth: 2) // Softer
                    .padding(10)
            }
            .frame(height: 280) // Slightly more compact
            .animation(.easeOut(duration: 1.0), value: score)
            
            // Bottom Info (Pills Style)
            HStack(spacing: 12) {
                ScoreMetricPill(title: appSettings.localized("score.recovery"), value: recoveryValue, color: .blue, icon: "wind")
                ScoreMetricPill(title: appSettings.localized("score.load"), value: loadValue, color: .green, icon: "flame.fill")
                ScoreMetricPill(title: appSettings.localized("score.sleep"), value: sleepValue, color: .purple, icon: "moon.fill")
            }
            .padding(.bottom, 24)
            .padding(.horizontal, 16)
        }
    }
}

// Subview for bottom metrics (Pill Style)
struct ScoreMetricPill: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title.uplocalized)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(color)
            
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension String {
    var uplocalized: String {
        // Simple helper to uppercase localized strings if needed, or keeping normal
        // For pills uppercase looks good:
        self.uppercased()
    }
}

// Helper Shapes
struct ArcShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: min(rect.width, rect.height) / 2, // Use min to fit frame
                 startAngle: startAngle,
                 endAngle: endAngle,
                 clockwise: false)
        return p
    }
}

struct TicksShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 // Fix radius to fit frame
        
        // Draw ticks every 15 degrees from 135 to 405
        for angle in stride(from: 135, to: 406, by: 15) {
            let a = Angle(degrees: Double(angle))
            // Inner point (start of tick)
            let innerR = radius - 45
            let x1 = center.x + innerR * cos(a.radians)
            let y1 = center.y + innerR * sin(a.radians)
            
            // Outer point
            let outerR = radius - 35
            let x2 = center.x + outerR * cos(a.radians)
            let y2 = center.y + outerR * sin(a.radians)
            
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
        }
        return p
    }
}
