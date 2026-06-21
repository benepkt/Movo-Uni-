import SwiftUI

/// Preview-Screen für importierte Trainingsvorlagen
struct TemplateImportView: View {
    @EnvironmentObject var templateStore: TemplateStore

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var exerciseLibrary: ExerciseLibrary
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t
    
    let template: TrainingTemplate
    
    @State private var importSuccess = false
    
    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func L(_ de: String, _ en: String) -> String { isDE ? de : en }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Card
                        headerCard
                        
                        // Exercises List
                        exercisesList
                        
                        // Import Button
                        importButton
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(L("Vorlage importieren", "Import Template"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Abbrechen", "Cancel")) {
                        dismiss()
                    }
                }
            }
            .alert(L("Erfolgreich importiert!", "Import Successful!"), isPresented: $importSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(L(
                    "Die Vorlage '\(template.name)' wurde zu deinen Vorlagen hinzugefügt.",
                    "The template '\(template.name)' has been added to your templates."
                ))
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(t.palette.primary.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(t.palette.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    Text(String(format: L("%d Übungen", "%d Exercises"), template.exercises.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .appElevatedCard()
    }
    
    // MARK: - Exercises List
    
    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Enthaltene Übungen", "Included Exercises"))
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 8) {
                ForEach(Array(template.exercises.enumerated()), id: \.offset) { index, exerciseName in
                    exerciseRow(number: index + 1, name: exerciseName)
                }
            }
        }
    }
    
    private func exerciseRow(number: Int, name: String) -> some View {
        HStack(spacing: 12) {
            // Number Badge
            ZStack {
                Circle()
                    .fill(t.palette.primary.opacity(0.1))
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(t.palette.primary)
            }
            
            // Exercise Name
            Text(name)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Check if exercise exists in library
            if exerciseLibrary.exercises.contains(where: { $0.name == name }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
            } else {
                Image(systemName: "info.circle")
                    .foregroundStyle(.orange)
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Import Button
    
    private var importButton: some View {
        Button {
            handleImport()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                Text(L("Vorlage importieren", "Import Template"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(t.palette.primary)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Import Logic
    
    private func handleImport() {
        // ✅ Alle User können unbegrenzt Templates importieren
        
        // Import template
        templateStore.add(template)
        
        // Show success
        importSuccess = true
        
        // Haptic feedback
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

// MARK: - Preview

#Preview {
    let template = TrainingTemplate(
        id: UUID().uuidString,
        name: "Push Training",
        exercises: [
            "Bench press (Barbell)",
            "Incline Dumbbell Press",
            "Shoulder Press (Dumbbell)",
            "Lateral Raises (Dumbbell)",
            "Triceps Pushdown (Cable)"
        ],
        ownerId: "preview",
        updatedAt: Date()
    )
    
    return TemplateImportView(template: template)
        .environmentObject(TemplateStore(training: TrainingStore()))

        .environmentObject(AppSettings())
        .environmentObject(ExerciseLibrary())
        .environmentObject(DesignSettingsStore())
}
