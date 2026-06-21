import SwiftUI

struct NewExerciseSheet: View {
    @Binding var newExercise: String
    var onAdd: () -> Void

    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    @Environment(\.designTokens) private var t

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [t.palette.primary.opacity(0.34), Color.cyan.opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 380
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appSettings.localized("newExercise.title"))
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(isDE ? "Füge eine eigene Übung zu deiner Bibliothek hinzu." : "Add a custom exercise to your library.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(isDE ? "Name" : "Name")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))

                        HStack(spacing: 10) {
                            Image(systemName: "dumbbell.fill")
                                .foregroundStyle(t.palette.primary)
                            TextField(appSettings.localized("newExercise.placeholder"), text: $newExercise)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                    }

                    Button(action: onAdd) {
                        Label(appSettings.localized("newExercise.add"), systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(t.palette.primary)
                            )
                            .foregroundColor(.white)
                    }
                    .disabled(newExercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newExercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("newExercise.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
