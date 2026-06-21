import SwiftUI

struct BodyRecoveryDetailView: View {
    let muscleName: String
    let status: BodyRecoverySection.RecoveryStatus
    let progress: Double // 0.0 to 1.0
    let hoursSince: Int
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings // Added
    
    var body: some View {
        VStack(spacing: 24) {
            // Header with Icon
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: status.icon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(status.color)
                }
                
                VStack(spacing: 4) {
                    Text(muscleName)
                        .font(.title2.bold())
                    
                    Text(status.title(with: appSettings)) // FIXED
                        .font(.headline)
                        .foregroundStyle(status.color)
                }
            }
            .padding(.top, 24)
            
            // Progress Bar
            VStack(spacing: 8) {
                HStack {
                    Text(appSettings.localized("body.recovery.progress")) // "Erholung" -> "Fortschritt" or keep "Erholung"? "Recovery" is better.
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray6))
                            .frame(height: 12)
                        
                        Capsule()
                            .fill(status.color)
                            .frame(width: geo.size.width * progress, height: 12)
                    }
                }
                .frame(height: 12)
            }
            .padding(.horizontal)
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                statBox(title: appSettings.localized("body.recovery.lastTraining"), value: timeString) // "Letztes Training"
                statBox(title: appSettings.localized("body.recovery.statusLabel"), value: status.title(with: appSettings)) // "Status"
            }
            .padding(.horizontal)
            
            // Explanation Text
            VStack(alignment: .leading, spacing: 8) {
                Text(appSettings.localized("body.recovery.infoTitle")) // "Information"
                    .font(.headline)
                
                Text(explanationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .leadingAlignment()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text(appSettings.localized("profile.close")) // "Schließen"
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(14)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }

        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
    }
    
    private func statBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var timeString: String {
        let days = hoursSince / 24
        if days == 0 { return appSettings.localized("common.today") }
        if days == 1 { return appSettings.localized("common.yesterday") }
        return String(format: appSettings.localized("time.daysAgo"), days)
    }
    
    private var explanationText: String {
        switch status {
        case .recovering:
            return appSettings.localized("body.recovery.desc.recovering")
        case .good:
            return appSettings.localized("body.recovery.desc.good")
        case .ready:
            return appSettings.localized("body.recovery.desc.ready")
        case .peak:
            return appSettings.localized("body.recovery.desc.peak")
        case .idle:
            return appSettings.localized("body.recovery.desc.idle")
        }
    }
}

fileprivate extension Text {
    func leadingAlignment() -> some View {
        self.multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true) // Prevents truncation
    }
}
