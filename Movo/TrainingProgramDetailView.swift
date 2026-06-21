import SwiftUI

struct TrainingProgramDetailView: View {
    let program: TrainingProgram
    @EnvironmentObject var challengeStore: ChallengeStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    private func copy(de: String, en: String) -> String {
        isDE ? de : en
    }

    private var programDurationText: String {
        program.isUnlimited ? copy(de: "Unbegrenzt", en: "Unlimited") : "\(program.durationWeeks) \(copy(de: "Wochen", en: "weeks"))"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                ZStack(alignment: .bottomLeading) {
                    Color.black
                    LinearGradient(colors: [.cyan.opacity(0.72), .blue.opacity(0.56)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(program.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.78)
                        
                        HStack {
                            Label(programDurationText, systemImage: "calendar")
                            Spacer()
                            Label(program.smartOrderingEnabled ? "Smart" : program.difficulty.rawValue, systemImage: "arrow.triangle.2.circlepath")
                        }
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding()
                }
                .frame(height: 250)

                Button {
                    challengeStore.startProgram(program)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isActiveProgram ? "checkmark.circle.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(isActiveProgram ? copy(de: "Aktiver Plan", en: "Active plan") : copy(de: "Zum aktiven Plan machen", en: "Make active plan"))
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isActiveProgram ? Color.white.opacity(0.58) : Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                .disabled(isActiveProgram)
                
                // Description
                VStack(alignment: .leading, spacing: 16) {
                    Text(copy(de: "Über diesen Plan", en: "About this plan"))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Text(program.description)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineSpacing(4)
                    
                    Divider()
                        .overlay(.white.opacity(0.16))

                    Text(copy(de: "Betroffene Muskelgruppen", en: "Target muscle groups"))
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    if affectedMuscleGroups.isEmpty {
                        Text(copy(de: "Noch keine Muskelgruppen erkannt.", en: "No muscle groups detected yet."))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.46))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                            ForEach(affectedMuscleGroups, id: \.self) { group in
                                HStack(spacing: 7) {
                                    Image(systemName: icon(for: group))
                                        .font(.caption.weight(.bold))
                                    Text(localizedMuscleGroup(group))
                                        .font(.caption.weight(.bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                }
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                .frame(maxWidth: .infinity)
                                .background(Color.cyan)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }

                    Divider()
                        .overlay(.white.opacity(0.16))
                    
                    Text(copy(de: "Wochenrhythmus", en: "Weekly rhythm"))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(1...7, id: \.self) { day in
                            HStack {
                                Text(dayName(for: day))
                                    .fontWeight(.medium)
                                    .frame(width: 100, alignment: .leading)
                                    .foregroundStyle(.white.opacity(0.58))
                                
                                if let templateId = program.schedule[day],
                                   let template = program.routines.first(where: { $0.id == templateId }) {
                                    Text(template.name)
                                        .foregroundStyle(.white)
                                } else {
                                    Text(copy(de: "Ruhetag", en: "Rest day"))
                                        .foregroundStyle(.white.opacity(0.36))
                                }
                            }
                            .padding(12)
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .padding()
                
                Spacer(minLength: 80)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(PlanBackground())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label(copy(de: "Bearbeiten", en: "Edit"), systemImage: "pencil")
                    }

                    Button {
                        showingShareSheet = true
                    } label: {
                        Label(copy(de: "QR-Code anzeigen", en: "Show QR code"), systemImage: "qrcode")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label(copy(de: "Löschen", en: "Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            TrainingProgramQRCodeView(program: program)
        }
        .sheet(isPresented: $showingEditSheet) {
            PlanCreationView(existingProgram: program)
        }
        .alert(copy(de: "Plan löschen?", en: "Delete plan?"), isPresented: $showingDeleteAlert) {
            Button(copy(de: "Löschen", en: "Delete"), role: .destructive) {
                challengeStore.deleteProgram(program)
                dismiss()
            }
            Button(copy(de: "Abbrechen", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(copy(de: "Dieser Trainingsplan wird aus deiner Liste entfernt.", en: "This training plan will be removed from your list."))
        }
    }

    private var isActiveProgram: Bool {
        challengeStore.activeProgram?.programId == program.id
    }
    
    private func dayName(for day: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isDE ? "de_DE" : "en_US")
        // weekdaySymbols are usually 0-indexed where 0 is Sunday, but here input 1..7 matches calendar.
        // Calendar.component(.weekday) returns 1 for Sunday.
        // DateFormatter.weekdaySymbols returns ["Sunday", "Monday", ...] (0...6)
        if day - 1 < formatter.weekdaySymbols.count {
            return formatter.weekdaySymbols[day - 1]
        }
        return "\(copy(de: "Tag", en: "Day")) \(day)"
    }

    private var affectedMuscleGroups: [String] {
        let groups = program.routines
            .flatMap(\.exercises)
            .flatMap { muscleGroups(for: $0) }
        return Array(Set(groups)).sorted()
    }

    private func muscleGroups(for exercise: String) -> [String] {
        let text = exercise.lowercased()
        var result: [String] = []

        if text.contains("bench") || text.contains("chest") || text.contains("press") || text.contains("push up") || text.contains("dips") {
            result.append("Brust")
        }
        if text.contains("row") || text.contains("pull") || text.contains("lat") || text.contains("deadlift") || text.contains("face pull") {
            result.append("Rücken")
        }
        if text.contains("squat") || text.contains("leg") || text.contains("lunge") || text.contains("calf") || text.contains("rdl") || text.contains("bulgarian") {
            result.append("Beine")
        }
        if text.contains("shoulder") || text.contains("lateral") || text.contains("overhead") || text.contains("raise") {
            result.append("Schultern")
        }
        if text.contains("curl") || text.contains("triceps") || text.contains("skull") || text.contains("extension") {
            result.append("Arme")
        }
        if text.contains("plank") || text.contains("core") || text.contains("crunch") || text.contains("leg raises") || text.contains("russian") {
            result.append("Core")
        }
        if text.contains("hip thrust") || text.contains("glute") {
            result.append("Glutes")
        }

        return result.isEmpty ? ["Ganzkörper"] : result
    }

    private func icon(for group: String) -> String {
        switch group {
        case "Brust": return "figure.strengthtraining.traditional"
        case "Rücken": return "figure.cooldown"
        case "Beine": return "figure.walk"
        case "Schultern": return "arrow.up.left.and.arrow.down.right"
        case "Arme": return "dumbbell.fill"
        case "Core": return "circle.hexagongrid.fill"
        case "Glutes": return "figure.stand"
        default: return "figure.mixed.cardio"
        }
    }

    private func localizedMuscleGroup(_ group: String) -> String {
        guard !isDE else { return group == "Glutes" ? "Gesäß" : group }
        switch group {
        case "Brust": return "Chest"
        case "Rücken": return "Back"
        case "Beine": return "Legs"
        case "Schultern": return "Shoulders"
        case "Arme": return "Arms"
        case "Ganzkörper": return "Full body"
        default: return group
        }
    }
}

struct TrainingProgramQRCodeView: View {
    let program: TrainingProgram
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        NavigationStack {
            ZStack {
                PlanBackground()
                VStack(spacing: 18) {
                    Text(isDE ? "Plan teilen" : "Share plan")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    if let image = TrainingProgramSharingService.generateQRCode(from: program) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 230, height: 230)
                            .padding(18)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    Text(program.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(isDE ? "Andere können diesen QR-Code scannen und den Plan importieren." : "Others can scan this QR code to import the plan.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(isDE ? "Teilen" : "Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDE ? "Schließen" : "Close") { dismiss() }
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }
}
