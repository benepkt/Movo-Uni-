import SwiftUI
import FirebaseAuth

struct AddTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    @EnvironmentObject var appSettings: AppSettings

    @State private var name: String
    @State private var selectedExercises: Set<String>
    @State private var searchText: String = ""

    var onSave: (TrainingTemplate) -> Void
    private var existingTemplate: TrainingTemplate?

    init(existingTemplate: TrainingTemplate? = nil,
         onSave: @escaping (TrainingTemplate) -> Void) {
        self.existingTemplate = existingTemplate
        self.onSave = onSave
        if let template = existingTemplate {
            _name = State(initialValue: template.name)
            _selectedExercises = State(initialValue: Set(template.exercises))
        } else {
            _name = State(initialValue: "")
            _selectedExercises = State(initialValue: [])
        }
    }

    private var filteredExercises: [ExerciseInfo] {
        if searchText.isEmpty {
            return exerciseLibrary.exercises
        } else {
            return exerciseLibrary.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(appSettings.localized("template.section")) {
                    TextField(appSettings.localized("template.name.placeholder"), text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section(appSettings.localized("template.exercises")) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField(appSettings.localized("template.search.placeholder"), text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    ForEach(filteredExercises, id: \.name) { exercise in
                        exerciseRow(exercise.name)
                    }
                }
            }
            .navigationTitle(existingTemplate == nil
                             ? appSettings.localized("template.new")
                             : appSettings.localized("template.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("template.cancel")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    saveTemplate()
                } label: {
                    Text(existingTemplate == nil
                         ? appSettings.localized("template.save")
                         : appSettings.localized("template.save.changes"))
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(name.isEmpty || selectedExercises.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding()
                }
                .disabled(name.isEmpty || selectedExercises.isEmpty)
            }
        }
    }

    private func exerciseRow(_ exerciseName: String) -> some View {
        Button {
            toggleSelection(exerciseName)
        } label: {
            HStack {
                Text(exerciseName)
                Spacer()
                if selectedExercises.contains(exerciseName) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .foregroundColor(.primary)
    }

    private func toggleSelection(_ exerciseName: String) {
        if selectedExercises.contains(exerciseName) {
            selectedExercises.remove(exerciseName)
        } else {
            selectedExercises.insert(exerciseName)
        }
    }

    private func saveTemplate() {
        // ✅ Lokal anlegen/aktualisieren. Keine Cloud-Schreibzugriffe hier!
        let owner = Auth.auth().currentUser?.uid ?? "guest"
        let template = TrainingTemplate(
            id: existingTemplate?.id ?? UUID().uuidString,
            name: name,
            exercises: Array(selectedExercises),
            ownerId: owner,
            updatedAt: Date()                 // <— wichtig: Zeitstempel für späteren Push/Merge
        )
        onSave(template)                      // Parent schreibt in TrainingStore (lokal)
        dismiss()
    }
}

#Preview {
    AddTemplateView { _ in }
        .environmentObject(ExerciseLibrary())
        .environmentObject(AppSettings())
}
