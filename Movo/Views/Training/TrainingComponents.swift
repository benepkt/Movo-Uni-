import SwiftUI

// MARK: - SetRowView (Performance Optimized)
struct SetRowView: View {
    let exerciseIndex: Int
    let setIndex: Int
    @Binding var set: ExerciseSet
    let weightUnit: String
    
    // Callbacks to avoid passing full environment objects
    let onCommitWeight: () -> Void
    let onToggleComplete: () -> Void
    let onRemove: () -> Void
    let onValuesChanged: (String, String) -> Void
    let weightPrompt: String
    let repsPrompt: String
    
    @FocusState var focusedField: UUID?
    @Environment(\.designTokens) private var t
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var pendingCommit: DispatchWorkItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Weight Field
                HStack(spacing: 6) {
                    TextField("",
                              text: $weightText,
                              prompt: Text(weightPrompt)
                                .foregroundStyle(.secondary)
                    )
                    .keyboardType(.decimalPad)
                    .padding(8)
                    .dsField()
                    .frame(width: 90)
                    .focused($focusedField, equals: set.id)
                    .onSubmit {
                        commitValues()
                    }
                    .onChange(of: weightText) { _ in
                        scheduleCommit()
                    }
                    
                    Text(weightUnit)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                // Reps Field
                TextField("",
                          text: $repsText,
                          prompt: Text(repsPrompt)
                            .foregroundStyle(.secondary)
                )
                .keyboardType(.decimalPad)
                .padding(8)
                .dsField()
                .frame(width: 80)
                .focused($focusedField, equals: set.id)
                .onChange(of: repsText) { _ in
                    scheduleCommit()
                }
                
                Spacer()
                
                // Complete Button
                Button {
                    commitValues()
                    onToggleComplete()
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(set.isCompleted ? t.palette.positive : .secondary)
                }
                
                // Delete Button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(t.palette.warning)
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear(perform: syncLocalText)
        .onChange(of: set.id) { _ in syncLocalText() }
        .onChange(of: set.weight) { newValue in
            if newValue != weightText { weightText = newValue }
        }
        .onChange(of: set.reps) { newValue in
            if newValue != repsText { repsText = newValue }
        }
        .onDisappear {
            pendingCommit?.cancel()
        }
    }

    private func syncLocalText() {
        weightText = set.weight
        repsText = set.reps
    }

    private func scheduleCommit() {
        pendingCommit?.cancel()
        let work = DispatchWorkItem {
            commitValues()
        }
        pendingCommit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func commitValues() {
        pendingCommit?.cancel()
        pendingCommit = nil
        guard weightText != set.weight || repsText != set.reps else { return }
        onValuesChanged(weightText, repsText)
        onCommitWeight()
    }
}

// MARK: - ExerciseSectionView (Performance Optimized)
struct ExerciseSectionView: View {
    let index: Int
    @Binding var exercise: Exercise
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.designTokens) private var t
    
    // Callbacks
    let onOpenDetail: () -> Void
    let onAddSet: () -> Void
    let onRemoveSet: (Int) -> Void
    let onToggleSet: (Int) -> Void
    let onSetValuesChanged: (Int, String, String) -> Void
    
    // Suggestions
    let suggestion: (kg: Double, reps: Int, date: Date)?
    let onApplySuggestion: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appSettings.localized(exercise.name))
                    .font(.headline)
                    .foregroundStyle(t.palette.primary)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenDetail() }
                
                Spacer()
                
                Button { onOpenDetail() } label: {
                    Image(systemName: "info.circle").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(t.palette.primary)
                .accessibilityLabel("Übungsdetails")
                
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
            }
            
            // Suggestion Pill
            if let sugg = suggestion {
                // Inline implementation of lastTimePill for cleaner separate file
                Button(action: onApplySuggestion) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("\(Int(sugg.kg))kg × \(sugg.reps)")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(t.palette.primary.opacity(0.1))
                    .foregroundStyle(t.palette.primary)
                    .clipShape(Capsule())
                }
            }
            
            VStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, _ in
                    // We bind to the array element using index to allow mutation
                    SetRowView(
                        exerciseIndex: index,
                        setIndex: setIndex,
                        set: $exercise.sets[setIndex],
                        weightUnit: "kg", // Pass unit
                        onCommitWeight: {}, // Weight draft handling needs logic from parent if complex
                        onToggleComplete: { onToggleSet(setIndex) },
                        onRemove: { onRemoveSet(setIndex) },
                        onValuesChanged: { weight, reps in onSetValuesChanged(setIndex, weight, reps) },
                        weightPrompt: "kg", // Simplified for now, can inject
                        repsPrompt: "8"     // Simplified
                    )
                }
            }
            .appElevatedCard()
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.dsChipBG))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.dsOutline, lineWidth: 0.5))
            
            Button {
                onAddSet()
            } label: {
                Label(appSettings.localized("training.addSet"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(t.palette.primary)
            }
            .padding(.top, 4)
        }
        .appElevatedCard()
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.dsFieldBG))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.dsOutline, lineWidth: 0.5))
    }
}
