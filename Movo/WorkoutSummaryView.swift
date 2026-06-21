import SwiftUI
import PhotosUI

struct WorkoutPersonalRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let exerciseName: String
    let newWeightKg: Double
    let previousWeightKg: Double?
    let reps: Int
    let setVolumeKg: Double

    init(
        id: UUID = UUID(),
        exerciseName: String,
        newWeightKg: Double,
        previousWeightKg: Double?,
        reps: Int,
        setVolumeKg: Double
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.newWeightKg = newWeightKg
        self.previousWeightKg = previousWeightKg
        self.reps = reps
        self.setVolumeKg = setVolumeKg
    }
}

struct WorkoutSummaryView: View {
    let entry: TrainingEntry
    let streakWeeks: Int?                  // nil → kein Congrats
    let weekProgress: [Bool]               // 7 Werte (ab Locale-Wochenstart)
    var personalRecords: [WorkoutPersonalRecord] = []
    var onDone: () -> Void

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var gm: GamificationManager
    @Environment(\.designTokens) private var t
    @AppStorage("units.weight") private var weightUnit: WeightUnit = .kg

    @State private var pickedImageData: Data? = nil
    @State private var photoItem: PhotosPickerItem? = nil

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    // 🎉 lokal: Cover steuern
    @State private var showCongrats = false

    // KPIs
    private var totalVolumeKg: Double { entry.totalWeight }
    private var totalReps: Int {
        entry.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + (Int($1.reps) ?? 0) } }
    }
    private var totalSets: Int { entry.exercises.reduce(0) { $0 + $1.sets.count } }
    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private var isActivity: Bool { entry.exercises.isEmpty && entry.cardioType != nil }
    private var durationMinutes: Int { max(0, Int(entry.duration / 60)) }
    private var embeddedActivityMinutes: Int {
        max(0, Int(entry.activities.reduce(0.0) { $0 + $1.duration } / 60))
    }
    private var topExercise: Exercise? {
        entry.exercises.max { lhs, rhs in lhs.totalWeight < rhs.totalWeight }
    }

    fileprivate static let volNF: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 1
        return nf
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                summaryBackground

                ScrollView {
                    VStack(spacing: 18) {
                        header
                        prCelebrationCard
                        metricsGrid
                        highlightCard
                        levelProgressCard
                        imagePickerSection
                        exercisesSection
                        embeddedActivitiesSection
                        shareRow
                        primaryCTA
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isDE ? "Fertig" : "Done") { continueTapped() }
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) { ShareSheet(items: shareItems) }
        .onChange(of: photoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    pickedImageData = data
                }
                photoItem = nil
            }
        }
        // 🎉 Streak-Cover
        .fullScreenCover(isPresented: $showCongrats) {
            StreakCongratsView(
                unlockedWeeks: streakWeeks ?? 0,
                weekProgress: weekProgress
            ) {
                showCongrats = false
                onDone()                                  // danach Summary schließen
            }
            .preferredColorScheme(.dark)
        }
    }

    private var summaryBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [t.palette.primary.opacity(0.38), Color.blue.opacity(0.15), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 440
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color.cyan.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var prCelebrationCard: some View {
        if !personalRecords.isEmpty {
            let topRecord = personalRecords.max { $0.newWeightKg < $1.newWeightKg } ?? personalRecords[0]
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(t.palette.primary)
                            .frame(width: 54, height: 54)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(.black)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(isDE ? "Glückwunsch" : "Congratulations")
                            .font(.caption.weight(.black))
                            .foregroundStyle(t.palette.primary)
                        Text(personalRecords.count == 1
                             ? (isDE ? "Neuer persönlicher Rekord" : "New personal record")
                             : String(format: isDE ? "%d neue persönliche Rekorde" : "%d new personal records", personalRecords.count))
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topRecord.exerciseName)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(prSubtitle(for: topRecord))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer()
                    Text(weightText(topRecord.newWeightKg))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.22)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))

                if personalRecords.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(personalRecords.prefix(3)) { record in
                            Text(record.exerciseName)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(.white.opacity(0.10)))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [t.palette.primary.opacity(0.34), Color.blue.opacity(0.16), Color.white.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(t.palette.primary.opacity(0.38), lineWidth: 1))
            .shadow(color: t.palette.primary.opacity(0.22), radius: 18, x: 0, y: 10)
        }
    }

    private func prSubtitle(for record: WorkoutPersonalRecord) -> String {
        if let previous = record.previousWeightKg {
            let delta = max(0, record.newWeightKg - previous)
            return String(format: isDE ? "+%@ gegenüber altem Bestwert • %d Wdh." : "+%@ over previous best • %d reps",
                          weightText(delta),
                          record.reps)
        }
        return String(format: isDE ? "Erster Bestwert • %d Wdh." : "First benchmark • %d reps", record.reps)
    }

    private func weightText(_ kg: Double) -> String {
        let value = weightUnit.fromKilograms(kg)
        let number = WorkoutSummaryView.volNF.string(from: NSNumber(value: value)) ?? "0"
        return "\(number) \(weightUnit.symbol)"
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isDE ? "Gespeichert" : "Saved")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(t.palette.primary)
                    Text(entry.title.isEmpty ? (isDE ? "Training" : "Workout") : entry.title)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(dateString(entry.date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text(entry.emoji ?? (isActivity ? "🔥" : "💪"))
                    .font(.system(size: 38))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(.white.opacity(0.10)))
                    .overlay(Circle().stroke(.white.opacity(0.13), lineWidth: 1))
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if isActivity {
                summaryMetric(
                    title: isDE ? "Dauer" : "Duration",
                    value: durationText,
                    icon: "timer",
                    color: t.palette.primary
                )
                if let distance = entry.loggedDistanceKm {
                    summaryMetric(title: isDE ? "Distanz" : "Distance", value: String(format: "%.2f km", distance), icon: "point.topleft.down.curvedto.point.bottomright.up", color: .cyan)
                }
                if let calories = entry.activeCalories {
                    summaryMetric(title: isDE ? "Kalorien" : "Calories", value: "\(Int(calories.rounded())) kcal", icon: "flame.fill", color: .orange)
                }
                if let effort = entry.perceivedEffort {
                    summaryMetric(title: isDE ? "Anstrengung" : "Effort", value: "\(effort)/10", icon: "gauge.with.dots.needle.67percent", color: .purple)
                }
            } else {
                summaryMetric(title: isDE ? "Volumen" : "Volume", value: volumeText(totalVolumeKg), icon: "scalemass.fill", color: t.palette.primary)
                summaryMetric(title: isDE ? "Sätze" : "Sets", value: "\(totalSets)", icon: "list.bullet.rectangle", color: .blue)
                summaryMetric(title: isDE ? "Wdh." : "Reps", value: "\(totalReps)", icon: "repeat", color: .mint)
                summaryMetric(
                    title: entry.activities.isEmpty ? (isDE ? "Dauer" : "Duration") : (isDE ? "Aktivität" : "Activity"),
                    value: entry.activities.isEmpty ? durationText : "\(embeddedActivityMinutes) min",
                    icon: entry.activities.isEmpty ? "timer" : "figure.outdoor.cycle",
                    color: .purple
                )
            }
        }
    }

    private func summaryMetric(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var highlightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(isActivity ? (isDE ? "Aktivität" : "Activity") : (isDE ? "Training" : "Workout"), systemImage: isActivity ? "figure.run" : "dumbbell.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(t.palette.primary)
                Spacer()
            }

            if isActivity {
                Text(activityHighlightText)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                if let note = entry.activityNote, !note.isEmpty {
                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
            } else if let topExercise {
                Text(String(format: isDE ? "Stärkster Fokus: %@" : "Top focus: %@", topExercise.name))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Text(isDE ? "Die Übungsdetails bleiben unten sauber aufgeschlüsselt." : "Exercise details are broken down below.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                Text(isDE ? "Training abgeschlossen" : "Workout completed")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var levelProgressCard: some View {
        let reward = GamificationManager.xpReward(for: entry)
        let snapshot = GamificationManager.progressSnapshot(xp: gm.xp, level: gm.level)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(t.palette.primary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(isDE ? "Level-Fortschritt" : "Level progress")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(isDE ? "+\(reward) XP aus Sätzen, Gewicht und Aktivitäten" : "+\(reward) XP from sets, weight and activities")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(t.palette.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Lvl \(snapshot.level)")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("→ \(snapshot.level + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.10))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [t.palette.primary, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * snapshot.progress))
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(snapshot.xpInLevel)/\(snapshot.xpNeededForLevel) XP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Text(isDE ? "Noch \(snapshot.xpToNextLevel) XP bis Level \(snapshot.level + 1)" : "\(snapshot.xpToNextLevel) XP to level \(snapshot.level + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Exercises
    @ViewBuilder
    private var exercisesSection: some View {
        if !entry.exercises.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(isDE ? "Übungen" : "Exercises")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 2)
                VStack(spacing: 10) {
                    ForEach(entry.exercises.indices, id: \.self) { i in
                        ExerciseSummaryRow(exercise: entry.exercises[i], accent: t.palette.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var embeddedActivitiesSection: some View {
        if !entry.activities.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(isDE ? "Aktivitäten" : "Activities")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 2)
                VStack(spacing: 10) {
                    ForEach(entry.activities) { activity in
                        HStack(spacing: 12) {
                            Text(activity.emoji ?? "🔥")
                                .font(.title3)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(.white.opacity(0.09)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(activity.title)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(.white)
                                Text(activitySubtitle(activity))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.54))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(13)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Image Picker
    private var imagePickerSection: some View {
        VStack(spacing: 10) {
            if let data = pickedImageData, let ui = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )

                    Button {
                        pickedImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(10)
                    }
                }

                Button {
                    pickedImageData = nil
                } label: {
                    Label("Remove image", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus").font(.title2)
                        Text(isDE ? "Bild für Teilen hinzufügen" : "Add image for sharing")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Share actions (ein Button)
    private var shareRow: some View {
        HStack(spacing: 18) {
            Button { renderAndShare(aspect: .square) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(isDE ? "Teilen" : "Share")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.76))
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Capsule().fill(.white.opacity(0.08)))
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var primaryCTA: some View {
        Button { continueTapped() } label: {
            Text(isDE ? "Weiter" : "Continue")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(t.palette.primary))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Continue Handler
    private func continueTapped() {
        if streakWeeks != nil {
            showCongrats = true    // ➜ erst Streak, danach onDone()
        } else {
            onDone()
        }
    }

    // MARK: - Rendering & Share
    enum ShareAspect { case square, poster
        var pixelSize: CGSize {
            switch self {
            case .square: return CGSize(width: 1080, height: 1080)
            case .poster: return CGSize(width: 1242, height: 2208)
            }
        }
    }

    private func renderAndShare(aspect: ShareAspect) {
        let pixel = aspect.pixelSize
        let scale = UIScreen.main.scale
        let pointSize = CGSize(width: pixel.width / scale, height: pixel.height / scale)

        let exportView = ShareExportView(
            entry: entry,
            pickedImage: imageFromData(pickedImageData),
            volumeText: volumeText(totalVolumeKg),
            aspect: aspect
        )
        .environment(\.colorScheme, .light)
        .frame(width: pointSize.width, height: pointSize.height)
        .background(Color(.systemBackground))

        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: exportView)
            renderer.scale = scale
            renderer.isOpaque = true
            if let uiImage = renderer.uiImage {
                if let data = uiImage.jpegData(compressionQuality: 0.95) {
                    self.shareItems = [data]
                } else {
                    self.shareItems = [uiImage]
                }
                self.showShareSheet = true
            }
        } else {
            let host = UIHostingController(rootView: exportView)
            host.view.bounds = CGRect(origin: .zero, size: pointSize)
            host.view.backgroundColor = .systemBackground
            let format = UIGraphicsImageRendererFormat(); format.scale = scale
            let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
            let img = renderer.image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            if let data = img.jpegData(compressionQuality: 0.95) { self.shareItems = [data] }
            else { self.shareItems = [img] }
            self.showShareSheet = true
        }
    }

    // MARK: - Helpers
    private func imageFromData(_ data: Data?) -> UIImage? {
        guard let data, let img = UIImage(data: data) else { return nil }
        return img
    }
    private func volumeText(_ v: Double) -> String {
        let s = WorkoutSummaryView.volNF.string(from: NSNumber(value: max(0, v))) ?? "0"
        return "\(s) kg"
    }
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: isDE ? "de_DE" : "en_US")
        f.dateStyle = .full
        return f.string(from: d)
    }

    private var durationText: String {
        if durationMinutes < 60 { return "\(durationMinutes) min" }
        return "\(durationMinutes / 60)h \(durationMinutes % 60)m"
    }

    private var activityHighlightText: String {
        if let distance = entry.loggedDistanceKm, distance > 0 {
            return String(format: isDE ? "%.2f km in %@" : "%.2f km in %@", distance, durationText)
        }
        return isDE ? "Aktivität erfolgreich gespeichert." : "Activity saved successfully."
    }

    private func activitySubtitle(_ activity: WorkoutActivityBlock) -> String {
        var parts: [String] = []
        let minutes = Int((activity.duration / 60).rounded())
        if minutes > 0 { parts.append("\(minutes) min") }
        if let distance = activity.distanceKm, distance > 0 {
            parts.append(String(format: "%.2f km", distance))
        }
        if let resistance = activity.resistanceLevel, resistance > 0 {
            parts.append("Level \(Int(resistance.rounded()))")
        }
        if let incline = activity.inclinePercent, incline > 0 {
            parts.append("\(Int(incline.rounded()))%")
        }
        if let watts = activity.averageWatts, watts > 0 {
            parts.append("\(Int(watts.rounded())) W")
        }
        if let calories = activity.activeCalories, calories > 0 {
            parts.append("\(Int(calories.rounded())) kcal")
        }
        if let heartRate = activity.averageHeartRate, heartRate > 0 {
            parts.append("\(Int(heartRate.rounded())) bpm")
        }
        return parts.isEmpty ? (isDE ? "Im Training erfasst" : "Logged in workout") : parts.joined(separator: " · ")
    }

    struct ShareSheet: UIViewControllerRepresentable {
        var items: [Any]
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: items, applicationActivities: nil)
        }
        func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
    }
}

// MARK: - Classic Card Content (einmalig, ohne äußere Card)
//
private struct ClassicCardContent: View {
    @Environment(\.designTokens) private var t

    let entry: TrainingEntry
    let pickedImage: UIImage?
    let volumeText: String
    let heroHeight: CGFloat // explizit steuerbar

    private var reps: Int { entry.exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + (Int($1.reps) ?? 0) } } }
    private var sets: Int { entry.exercises.reduce(0) { $0 + $1.sets.count } }

    private var volumeNumber: String { volumeText.split(separator: " ").first.map(String.init) ?? volumeText }
    private var volumeUnit: String {
        let p = volumeText.split(separator: " ")
        return p.count >= 2 ? p.dropFirst().joined(separator: " ") : ""
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(entry.title.isEmpty ? "Training" : entry.title)
                    .font(.title2.bold())
                Text(DateFormatter.localizedString(from: entry.date, dateStyle: .full, timeStyle: .none))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Group {
                if let img = pickedImage {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(height: heroHeight).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if let robot = UIImage(named: "fitness_robot_blue") {
                    Image(uiImage: robot)
                        .resizable().scaledToFit()
                        .frame(height: heroHeight - 40)
                        .padding(.vertical, 8)
                } else {
                    Image(systemName: "bolt.shield")
                        .font(.system(size: max(48, heroHeight - 60), weight: .bold))
                        .foregroundStyle(t.palette.primary)
                        .padding(.vertical, 8)
                }
            }

            // KPI Segment-Card
            HStack(spacing: 0) {
                statCell(title: "Volume", value: volumeNumber, unit: volumeUnit)
                Rectangle().fill(t.palette.outline.opacity(0.2)).frame(width: 1).padding(.vertical, 6)
                statCell(title: "Reps", value: "\(reps)", unit: nil)
                Rectangle().fill(t.palette.outline.opacity(0.2)).frame(width: 1).padding(.vertical, 6)
                statCell(title: "Sets", value: "\(sets)", unit: nil)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .appElevatedCard()
        }
        .padding(18)
    }

    private func statCell(title: String, value: String, unit: String?) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title3.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                if let unit, !unit.isEmpty {
                    Text(unit).font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

//
// MARK: - Export View – füllt Höhe, kein doppelter Header/Hero
//
private struct ShareExportView: View {
    let entry: TrainingEntry
    let pickedImage: UIImage?
    let volumeText: String
    let aspect: WorkoutSummaryView.ShareAspect

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            // hero proportional – keine riesigen Leerflächen
            let hero = min(max(h * (aspect == .poster ? 0.16 : 0.18), 140), aspect == .poster ? 320 : 200)
            ZStack {
                Color(.systemBackground)
                VStack {
                    ClassicCardContent(entry: entry,
                                       pickedImage: pickedImage,
                                       volumeText: volumeText,
                                       heroHeight: hero)
                        .appElevatedCard()
                    Spacer(minLength: 0)
                }
                .padding(aspect == .poster ? 24 : 18)
            }
        }
    }
}

// MARK: - Exercise Summary Row (unverändert)
private struct ExerciseSummaryRow: View {
    let exercise: Exercise
    let accent: Color

    private func parse(_ s: String) -> Double {
        let t = s.replacingOccurrences(of: ",", with: ".")
        return Double(t) ?? 0
    }
    private var volume: Double { exercise.sets.reduce(0.0) { $0 + parse($1.weight) } }
    private var maxWeight: Double { exercise.sets.map { parse($0.weight) }.max() ?? 0 }
    private var reps: Int { exercise.sets.reduce(0) { $0 + (Int($1.reps) ?? 0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(accent.opacity(0.14))
                    Image(systemName: "dumbbell.fill").foregroundStyle(accent)
                }.frame(width: 28, height: 28)

                Text(exercise.name)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
            }

            HStack(spacing: 10) {
                metric("Volume", volText(volume))
                metric("Max", volText(maxWeight))
                metric("Reps", "\(reps)")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private func volText(_ v: Double) -> String {
        let nf = WorkoutSummaryView.volNF
        let s = nf.string(from: NSNumber(value: max(0, v))) ?? "0"
        return "\(s) kg"
    }
}
