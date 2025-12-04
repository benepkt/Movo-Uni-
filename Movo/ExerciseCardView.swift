import SwiftUI

struct ExerciseCardView: View {
    @EnvironmentObject var appSettings: AppSettings

    var info: ExerciseInfo
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Wenn du später einen nameKey hast, kannst du hier auf appSettings.localized(nameKey) umstellen.
                    Text(info.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(appSettings.localized("exercise.tapForDetails"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(info.name)")
        .accessibilityHint(appSettings.localized("exercise.tapForDetails"))
    }
}
