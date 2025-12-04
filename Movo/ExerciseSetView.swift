import SwiftUI

struct ExerciseSetView: View {
    @Binding var set: ExerciseSet
    @EnvironmentObject var trainingStore: TrainingStore

    var onToggle: () -> Void
    @FocusState private var focusedField: UUID?
    let setID: UUID

    var body: some View {
        HStack(spacing: 12) {
            TextField("kg", text: $set.weight)
                .keyboardType(.decimalPad)
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .frame(width: 80)
                .focused($focusedField, equals: setID)

            TextField("Wdh", text: $set.reps)
                .keyboardType(.numberPad)
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .frame(width: 80)
                .focused($focusedField, equals: setID)

            Spacer()

            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(set.isCompleted ? .green : .gray)
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}
