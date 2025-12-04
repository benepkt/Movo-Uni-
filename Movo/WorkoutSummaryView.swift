import SwiftUI
import PhotosUI

struct WorkoutSummaryView: View {
    let entry: TrainingEntry
    let streakWeeks: Int?                  // nil → kein Congrats
    let weekProgress: [Bool]               // 7 Werte (ab Locale-Wochenstart)
    var onDone: () -> Void

    @Environment(\.designTokens) private var t

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

    fileprivate static let volNF: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 1
        return nf
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    previewCard
                    imagePickerSection
                    exercisesSection
                    shareRow
                    primaryCTA
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Workout Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { continueTapped() }     // ➜ Streak oder schließen
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

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 6) {
            Text(entry.title.isEmpty ? "Training" : entry.title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(dateString(entry.date))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Classic Preview (in der Seite)
    private var previewCard: some View {
        ClassicCardContent(entry: entry,
                           pickedImage: imageFromData(pickedImageData),
                           volumeText: volumeText(totalVolumeKg),
                           heroHeight: 180)
            .padding()
            .appElevatedCard()
            .padding(.horizontal, 2)
            .frame(height: 460)
    }

    // MARK: - Exercises
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises").font(.headline).padding(.horizontal, 2)
            VStack(spacing: 10) {
                ForEach(entry.exercises.indices, id: \.self) { i in
                    ExerciseSummaryRow(exercise: entry.exercises[i], accent: t.palette.primary)
                }
            }
            .appElevatedCard()
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
                                .stroke(t.palette.outline, lineWidth: 0.8)
                        )

                    Button {
                        pickedImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
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
                .buttonStyle(.bordered)
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "plus.circle").font(.title2)
                        Text("Add an image for more shareables")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .appElevatedCard()
                }
            }
        }
    }

    // MARK: - Share actions (ein Button)
    private var shareRow: some View {
        HStack(spacing: 18) {
            Button { renderAndShare(aspect: .square) } label: {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up").font(.title3)
                    Text("More").font(.footnote)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var primaryCTA: some View {
        Button { continueTapped() } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
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
        let f = DateFormatter(); f.dateStyle = .full; return f.string(from: d)
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

                Text(exercise.name).font(.headline).lineLimit(2)
                Spacer()
            }

            HStack(spacing: 10) {
                metric("Volume", volText(volume))
                metric("Max Weight", volText(maxWeight))
                metric("Total Reps", "\(reps)")
            }
        }
        .padding(14)
        .appElevatedCard()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .appElevatedCard()
    }

    private func volText(_ v: Double) -> String {
        let nf = WorkoutSummaryView.volNF
        let s = nf.string(from: NSNumber(value: max(0, v))) ?? "0"
        return "\(s) kg"
    }
}
