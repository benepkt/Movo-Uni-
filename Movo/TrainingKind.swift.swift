import SwiftUI
import UIKit

struct TrainingStartMenu: View {
    enum TrainingType {
        case strength
        case running
        case manual
    }
    
    let onSelect: (TrainingType) -> Void
    
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    
    var body: some View {
        VStack(spacing: 18) {
            
            // 👇 extra Freiraum oben im Sheet
            Color.clear
                .frame(height: 80)
            
            // — Titel ----------------------------------------------------
            Text(appSettings.localized("startMenu.title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // — Menü-Items ----------------------------------------------
            VStack(spacing: 12) {
                // ✅ Strength: normal aktiv
                menuItem(
                    iconName: "dumbbell.fill",
                    iconColor: .blue,
                    title: appSettings.localized("startMenu.strength.title"),
                    subtitle: appSettings.localized("startMenu.strength.subtitle"),
                    locked: false
                ) {
                    onSelect(.strength)
                    dismiss()
                }
                
                // 🟡 Running: COMING SOON + Lock
                menuItem(
                    iconName: "figure.run",
                    iconColor: .orange,
                    title: appSettings.localized("startMenu.running.title"),
                    subtitle: appSettings.localized("startMenu.comingSoon"),
                    locked: true
                ) {
                    // Aktion wird wegen locked NIE ausgeführt
                    onSelect(.running)
                    dismiss()
                }
                
                // 🟡 Manual: COMING SOON + Lock
                menuItem(
                    iconName: "clipboard.fill",
                    iconColor: .purple,
                    title: appSettings.localized("startMenu.manual.title"),
                    subtitle: appSettings.localized("startMenu.comingSoon"),
                    locked: true
                ) {
                    // Aktion wird wegen locked NIE ausgeführt
                    onSelect(.manual)
                    dismiss()
                }
            }
            
            // — Cancel ---------------------------------------------------
            Button(appSettings.localized("startMenu.cancel")) {
                dismiss()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(t.palette.primary)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
    
    
    // MARK: - Menu Item

    private func menuItem(
        iconName: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        locked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            // Safety: nur ausführen, wenn NICHT gesperrt
            guard !locked else { return }
            action()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(locked ? .secondary : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .opacity(locked ? 0.6 : 1.0)   // leicht ausgegraut bei „Coming soon“
        }
        .buttonStyle(.plain)
        .disabled(locked)                  // System-weit als „disabled“ markiert
    }
}
