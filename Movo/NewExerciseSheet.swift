import SwiftUI

struct NewExerciseSheet: View {
    @Binding var newExercise: String
    var onAdd: () -> Void

    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField(appSettings.localized("newExercise.placeholder"), text: $newExercise)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Button(action: onAdd) {
                    Label(appSettings.localized("newExercise.add"), systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appSettings.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(newExercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle(appSettings.localized("newExercise.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("newExercise.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
