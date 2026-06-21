import SwiftUI
import HealthKit

struct AddMetricSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var healthKit: HealthKitManager
    
    @EnvironmentObject var appSettings: AppSettings
    
    let metric: BodyView.MetricType
    
    @State private var valueString: String = ""
    @State private var date: Date = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Auto-focus logic
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("\(appSettings.localized("addMetric.value")) (\(metric.unit))") // "Wert (kg)"
                        Spacer()
                        TextField("0.0", text: $valueString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputFocused)
                    }
                    
                    DatePicker(appSettings.localized("addMetric.date"), selection: $date, displayedComponents: [.date, .hourAndMinute]) // "Datum"
                } header: {
                    Text(appSettings.localized("addMetric.newEntry")) // "Neuer Eintrag"
                } footer: {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("\(metric.title(with: appSettings)) \(appSettings.localized("addMetric.add"))") // "Gewicht hinzufügen"
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appSettings.localized("common.cancel")) { dismiss() } // "Abbrechen"
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.localized("common.save")) { // "Speichern"
                        save()
                    }
                    .bold()
                    .disabled(valueString.isEmpty || isLoading)
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
    }
    
    private func save() {
        guard let value = Double(valueString.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = appSettings.localized("addMetric.invalidNumber") // "Bitte gültige Zahl eingeben"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Save locally via ManualBodyDataManager
        // Use MetricType.idKey logic mapping
        let idKey: String? = {
             switch metric {
             case .weight: return "weight"
             case .bmi: return "bmi"
             case .heartRate: return "hr"
             case .bodyFat: return "bodyFat"
             case .leanMass: return "leanMass"
             case .vo2: return "vo2"
             case .resp: return "resp"
             case .spo2: return "spo2"
             case .bodyTemp: return "temp"
             case .fitnessLevel: return "fitness"
             default: return nil
             }
        }()
        
        if let id = idKey {
            ManualBodyDataManager.shared.saveMetric(id, value: value)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } else {
            errorMessage = appSettings.localized("addMetric.errorSave") // "Speichern für diesen Typ nicht unterstützt."
            isLoading = false
        }
        
        // Legacy HealthKit code removed as requested ("ohne in HealthKit zu schreiben")
    }
}
