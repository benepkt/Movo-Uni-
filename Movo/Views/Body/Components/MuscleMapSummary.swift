import SwiftUI

struct MuscleMapSummary: View {
    @Environment(\.designTokens) private var t
    @EnvironmentObject var appSettings: AppSettings

    let loadThisWeek: [MuscleRegion: Double]
    let loadLastWeek: [MuscleRegion: Double]
    
    @State private var showLastWeek = false

    private var activeLoad: [MuscleRegion: Double] {
        showLastWeek ? loadLastWeek : loadThisWeek
    }
    
    private var maxLoad: Double { max(activeLoad.values.max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        // Header with Segmented Control
            HStack {
                Text(appSettings.localized("statistics.musclemap.title"))
                    .font(.headline)
                
                Spacer()
                
                // Custom Toggle / Switch
                HStack(spacing: 0) {
                    toggleButton(
                        title: appSettings.localized("statistics.musclemap.current"),
                        isSelected: !showLastWeek
                    ) { showLastWeek = false }
                    toggleButton(
                        title: appSettings.localized("statistics.musclemap.previous"),
                        isSelected: showLastWeek
                    ) { showLastWeek = true }
                }
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Subtitle
            Text(showLastWeek
                 ? appSettings.localized("statistics.musclemap.last7.prevWeek")
                 : appSettings.localized("statistics.musclemap.thisweek"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                MuscleFigure(side: .front, tint: t.palette.primary, load: activeLoad, maxLoad: maxLoad)
                MuscleFigure(side: .back,  tint: t.palette.primary, load: activeLoad, maxLoad: maxLoad)
            }
            .frame(maxWidth: .infinity)
            .id(showLastWeek) // Force redraw animation if needed
            .animation(.easeInOut, value: showLastWeek)
        }
        .appElevatedCard()
    }
    
    private func toggleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? t.palette.primary : Color.clear)
                )
        }
    }
}
