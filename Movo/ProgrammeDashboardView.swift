import SwiftUI
import AVFoundation

struct ProgrammeDashboardView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var challengeStore: ChallengeStore
    @EnvironmentObject var equipmentStore: EquipmentStore
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var templateStore: TemplateStore
    
    @State private var showingEquipmentSheet = false
    @State private var showingPlanCreation = false
    @State private var showingProgramImport = false
    @State private var showingActiveProgramShare = false
    
    // Derived: "Today's" scheduled unit
    private var todaysWorkout: TrainingTemplate? {
        challengeStore.recommendedTemplate(from: trainingStore.history)
    }

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    private func copy(de: String, en: String) -> String { isDE ? de : en }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    heroCardSection
                    quickActionsSection
                    allProgrammesSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 18)
            }
            .background(PlanBackground())
            .navigationTitle(copy(de: "Trainingsplan", en: "Training plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEquipmentSheet) {
                EquipmentSelectionView()
            }
            .sheet(isPresented: $showingPlanCreation) {
                PlanCreationView()
            }
            .sheet(isPresented: $showingProgramImport) {
                ProgramCodeImportView()
                    .environmentObject(challengeStore)
            }
            .sheet(isPresented: $showingActiveProgramShare) {
                if let program = challengeStore.activeTrainingProgram() {
                    TrainingProgramQRCodeView(program: program)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var heroCardSection: some View {
        if let workout = todaysWorkout {
            TodaysTemplateCard(template: workout)
        } else if challengeStore.activeProgram != nil {
            // Plan active, but REST DAY
            RestDayCard()
        } else {
            // No Plan
            NoPlanCard(action: { showingPlanCreation = true })
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 54, height: 54)
                    .background(Color.cyan)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(copy(de: "Dein Plan", en: "Your plan"))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    
                    if let active = challengeStore.activeProgram,
                       let program = challengeStore.availablePrograms.first(where: { $0.id == active.programId }) {
                        Text(program.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(copy(de: "Baue dir einen Wochenrhythmus aus deinen Templates.", en: "Build a weekly rhythm from your templates."))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
                
                Spacer()
                
                if challengeStore.activeProgram != nil {
                    Menu {
                        Button {
                            showingActiveProgramShare = true
                        } label: {
                            Label(copy(de: "Per QR teilen", en: "Share via QR"), systemImage: "qrcode")
                        }

                        Button(role: .destructive, action: {
                            withAnimation {
                                challengeStore.leaveCurrentProgram()
                            }
                        }) {
                            Label(copy(de: "Plan verlassen", en: "Leave plan"), systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            planActionButton(title: copy(de: "Selbst", en: "Create"), icon: "plus", tint: .cyan) {
                showingPlanCreation = true
            }
            planActionButton(title: copy(de: "QR-Import", en: "QR import"), icon: "qrcode.viewfinder", tint: .blue) {
                showingProgramImport = true
            }
        }
        .padding(.horizontal, 20)
    }

    private func planActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(tint)
                    .clipShape(Circle())
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private var equipmentRow: some View {
        Button(action: { showingEquipmentSheet = true }) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(Color.accentColor))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy(de: "Equipment", en: "Equipment"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    let count = equipmentStore.selectedEquipmentIDs.count
                    Text(count == 0 ? copy(de: "Kein Equipment", en: "No equipment") : copy(de: "\(count) verfügbar", en: "\(count) items available"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal)
        .buttonStyle(.plain)
    }
    
    private var allProgrammesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy(de: "Alle Pläne", en: "All plans"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                ForEach(challengeStore.availablePrograms) { program in
                    NavigationLink(destination: TrainingProgramDetailView(program: program)) {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.cyan)
                                .frame(width: 42, height: 42)
                                .background(.white.opacity(0.08))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(program.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text("\(program.routines.count) \(copy(de: "Templates", en: "templates")) · \(program.isUnlimited ? copy(de: "unbegrenzt", en: "unlimited") : "\(program.durationWeeks) \(copy(de: "Wochen", en: "weeks"))")")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.48))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white.opacity(0.34))
                        }
                        .padding(16)
                        .background(.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Subviews

struct TodaysTemplateCard: View {
    let template: TrainingTemplate
    @EnvironmentObject var sessionManager: TrainingSessionManager
    @EnvironmentObject var appSettings: AppSettings
    @State private var showTrainingStarted = false

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Image / Gradient
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 160)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isDE ? "HEUTE GEPLANT" : "PLANNED TODAY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(1)
                    
                    Text(template.name)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                .padding()
            }
            
            // Details
            HStack {
                Label("~ 45 Min", systemImage: "clock")
            }
            .font(.subheadline.weight(.medium))
            .padding()
            .background(.white.opacity(0.08))
        }
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        .padding(.horizontal, 20)
    }
    
    private func startTraining() {
        sessionManager.startTraining(title: template.name, source: "from_plan", templateId: template.id, hasActivePlan: true)
        for name in template.exercises { sessionManager.addExercise(name) }
        AnalyticsService.trackWorkoutStarted(source: "from_plan", template: template, hasActivePlan: true)
    }
}

struct RestDayCard: View {
    @EnvironmentObject var appSettings: AppSettings
    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.green)
            
            Text(isDE ? "Ruhetag" : "Rest day")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text(isDE ? "Heute steht Regeneration an. Dein nächstes Template wartet im Plan." : "Today is for recovery. Your next template is waiting in your plan.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.56))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

struct TodaysWorkoutCard: View {
    let unit: TrainingUnit
    @EnvironmentObject var appSettings: AppSettings
    // Deprecated / Placeholder
    var body: some View { EmptyView() } 
}

struct NoPlanCard: View {
    let action: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                
                    .foregroundStyle(Color.accentColor)
                
                Text(isDE ? "Plan erstellen" : "Create your plan")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(isDE ? "Wähle mehrere Templates und baue daraus deinen Wochenplan." : "Choose multiple templates and turn them into your weekly plan.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

struct ProgramCodeImportView: View {
    @EnvironmentObject var challengeStore: ChallengeStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var errorText: String?
    @State private var showingScanner = false

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        NavigationStack {
            ZStack {
                PlanBackground()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isDE ? "Plan importieren" : "Import plan")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(isDE ? "Scanne den QR-Code eines geteilten Trainingsplans." : "Scan the QR code of a shared training plan.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Button {
                        showingScanner = true
                    } label: {
                        Label(isDE ? "QR-Code scannen" : "Scan QR code", systemImage: "qrcode.viewfinder")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if let errorText {
                        Text(errorText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red.opacity(0.9))
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(isDE ? "Import" : "Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDE ? "Schließen" : "Close") { dismiss() }
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .sheet(isPresented: $showingScanner) {
                ProgramQRCodeScannerView { scannedCode in
                    showingScanner = false
                    importProgram(scannedCode)
                }
            }
            .onAppear { showingScanner = true }
        }
    }

    private func importProgram(_ code: String) {
        guard let program = TrainingProgramSharingService.decodeProgram(fromCode: code) else {
            errorText = isDE ? "Der QR-Code konnte nicht gelesen werden." : "The QR code could not be read."
            return
        }

        challengeStore.startProgram(program)
        dismiss()
    }
}

struct ProgramQRCodeScannerView: View {
    let onCode: (String) -> Void
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerRepresentable(onCode: onCode)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 34, weight: .bold))
                        Text(isDE ? "Movo Plan QR-Code scannen" : "Scan Movo plan QR code")
                            .font(.headline.weight(.bold))
                        Text(isDE ? "Halte den QR-Code mittig in den Rahmen." : "Keep the QR code centered in the frame.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(20)
                }
            }
            .navigationTitle(isDE ? "QR-Scan" : "QR scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDE ? "Schließen" : "Close") { dismiss() }
                }
            }
        }
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didReadCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureScanner()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func configureScanner() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didReadCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        didReadCode = true
        session.stopRunning()
        onCode?(value)
    }
}

struct TrainingProgramImportView: View {
    let program: TrainingProgram
    @EnvironmentObject var challengeStore: ChallengeStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private var isDE: Bool { appSettings.language.lowercased().hasPrefix("de") }

    var body: some View {
        NavigationStack {
            ZStack {
                PlanBackground()
                VStack(alignment: .leading, spacing: 18) {
                    Text(isDE ? "Geteilter Plan" : "Shared plan")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(program.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(program.routines.count) \(isDE ? "Templates" : "templates") · \(program.isUnlimited ? (isDE ? "unbegrenzt" : "unlimited") : "\(program.durationWeeks) \(isDE ? "Wochen" : "weeks")")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))

                    VStack(spacing: 10) {
                        ForEach(program.routines) { template in
                            HStack {
                                Text(template.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(template.exercises.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.46))
                            }
                            .padding(12)
                            .background(.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Spacer()

                    Button {
                        challengeStore.startProgram(program)
                        dismiss()
                    } label: {
                        Text(isDE ? "Importieren & starten" : "Import & start")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .navigationTitle(isDE ? "Import" : "Import")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EquipmentSelectionView: View {
    @EnvironmentObject var equipmentStore: EquipmentStore
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss

    // Explicit order of sections (no CaseIterable needed)
    private let allTypes: [EquipmentItem.EquipmentType] = [
        .freeWeights, .machines, .cardio, .bodyweight, .other
    ]
    
    private func items(for type: EquipmentItem.EquipmentType) -> [EquipmentItem] {
        equipmentStore.allEquipment.filter { $0.type == type }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(allTypes, id: \.rawValue) { type in
                    Section(header: Text(type.rawValue)) {
                        ForEach(items(for: type)) { item in
                            EquipmentRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("Equipment")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appSettings.language.lowercased().hasPrefix("de") ? "Fertig" : "Done") { dismiss() }
                }
            }
        }
    }
}

private struct EquipmentRow: View {
    @EnvironmentObject var equipmentStore: EquipmentStore
    let item: EquipmentItem
    
    var body: some View {
        Button(action: { equipmentStore.toggle(item) }) {
            HStack {
                Image(systemName: item.icon)
                    .frame(width: 24)
                Text(item.name)
                Spacer()
                if equipmentStore.has(item.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
