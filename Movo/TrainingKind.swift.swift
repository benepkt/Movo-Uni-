import SwiftUI

struct TrainingStartMenu: View {
    /// Verschachtelter Typ, kollidiert nicht mit anderen Enums
    enum Kind: String {
        case strength
        case running
    }

    let onSelect: (Kind) -> Void

    @Environment(\.designTokens) private var t
    @Environment(\.dismiss) private var dismiss

    // System-adaptive Farben
    private let sheetBackground = Color(uiColor: .systemBackground)
    private let cardBackground  = Color(uiColor: .secondarySystemBackground)
    private let cardStroke      = Color(uiColor: .separator)

    var body: some View {
        VStack(spacing: 16) {
            // Grabber
            Capsule()
                .frame(width: 40, height: 4)
                .foregroundStyle(.secondary.opacity(0.4))
                .padding(.top, 8)

            // Titel
            Text("Training starten")
                .font(.headline)
                .padding(.top, 4)

            // Optionen
            VStack(spacing: 12) {
                button(
                    kind: .strength,
                    title: "Krafttraining",
                    subtitle: "Sätze, Gewichte & Pausen",
                    icon: "dumbbell.fill"
                )

                button(
                    kind: .running,
                    title: "Joggen",
                    subtitle: "Distanz & Dauer tracken",
                    icon: "figure.run"
                )
            }
            .padding(.horizontal)

            // Abbrechen
            Button(role: .cancel) {
                dismiss()
            } label: {
                Text("Abbrechen")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(t.palette.primary)
            }
            .padding(.horizontal)

            Spacer(minLength: 8)
        }
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(sheetBackground)
                .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: -6)
        )
    }

    // MARK: - Button-Baustein

    private func button(
        kind: Kind,
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        Button {
            onSelect(kind)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(t.palette.primary.opacity(0.12))
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(t.palette.primary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStroke.opacity(0.6), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
