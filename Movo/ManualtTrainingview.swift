import SwiftUI

struct ManualTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var gm: GamificationManager
    
    @State private var title: String = ""
    @State private var durationMinutes: Int = 30
    @State private var trainingDate: Date = Date()
    @State private var notes: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Training Details") {
                    TextField("Trainingstitel", text: $title)
                        .autocorrectionDisabled()
                    
                    Picker("Dauer", selection: $durationMinutes) {
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    
                    DatePicker("Datum", selection: $trainingDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Notizen (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Manuell eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveTraining()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .alert("Fehler", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    private func saveTraining() {
        guard !title.isEmpty else {
            alertMessage = "Bitte gib einen Titel ein"
            showingAlert = true
            return
        }
        
        let entry = TrainingEntry(
            id: UUID(),
            date: trainingDate,
            title: title,
            exercises: [],  // Manual entries have no exercises
            duration: TimeInterval(durationMinutes * 60),
            emoji: "📝",
            routePolyline: nil
        )
        
        trainingStore.add(entry: entry)
        
        // Add XP reward
        gm.addXP(10)

        dismiss()
    }
}

