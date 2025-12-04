import SwiftUI

struct ExerciseManagementView: View {
    @EnvironmentObject var library: ExerciseLibrary
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings

    @State private var newExercise = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField(appSettings.localized("exerciseManagement.newExercise"), text: $newExercise)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)

                    Button(action: addNewExercise) {
                        Text(appSettings.localized("exerciseManagement.add"))
                    }
                    .disabled(newExercise.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()

                List {
                    ForEach(library.exercises, id: \.self) { exerciseInfo in
                        Text(exerciseInfo.name)
                    }
                    .onDelete(perform: library.deleteExercise)
                }
            }
            .navigationTitle(appSettings.localized("exerciseManagement.title"))
        }
    }

    private func addNewExercise() {
        let trimmed = newExercise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        library.addExercise(trimmed)
        newExercise = ""
    }
}
