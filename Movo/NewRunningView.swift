import SwiftUI
import MapKit
import CoreLocation
import Combine
import HealthKit

// MARK: - RUNNING TRAINING VIEW

enum CardioType: String {
    case running = "Joggen"
    case cycling = "Radfahren"
    case walking = "Spazieren"
    
    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .walking: return "figure.walk"
        }
    }
    
    var speedLabel: String {
        switch self {
        case .running, .walking: return "min/km"  // Pace
        case .cycling: return "km/h"  // Speed
        }
    }
}

struct RunningTrainingView: View {
    let cardioType: CardioType
    @EnvironmentObject var trainingStore: TrainingStore
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var healthKit: HealthKitManager

    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var t

    @StateObject private var run = RunningSessionManager()

    @State private var rewardMessage: RewardMessage? = nil
    @State private var showCancelConfirm = false
    @State private var showSummary = false
    @State private var lastSavedEntry: TrainingEntry?

    @State private var followUser = true
    @State private var showFullStats = false      // 👈 Vollbild-Stats

    @State private var summaryStreakWeeks: Int? = nil
    @State private var summaryWeekProgress: [Bool] = Array(repeating: false, count: 7)

    // Map-Options à la Strava
    @State private var isSatellite = false
    @State private var is3D = false
    @State private var mapPosition: MapCameraPosition = .automatic

    // Daten für die Run-Summary
    @State private var lastRunDistanceKm: Double = 0
    @State private var lastRunPath: [CLLocationCoordinate2D] = []

    private var distanceKm: Double { run.distanceMeters / 1000.0 }
    private var formattedDistance: String {
        String(format: "%.2f", distanceKm)
    }
    private var formattedDuration: String {
        let total = Int(run.elapsedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    private var formattedPace: String {
        guard distanceKm > 0 else { return cardioType == .cycling ? "0.0" : "--:--" }
        
        if cardioType == .cycling {
            // Show km/h for cycling
            let hours = run.elapsedSeconds / 3600.0
            let kmh = distanceKm / hours
            return String(format: "%.1f", kmh)
        } else {
            // Show min/km for running/walking
            let secondsPerKm = run.elapsedSeconds / distanceKm
            let m = Int(secondsPerKm) / 60
            let s = Int(secondsPerKm) % 60
            return String(format: "%d:%02d", m, s)
        }
    }
    private var gpsText: String {
        switch run.gpsStatus {
        case .searching: return "GPS wird gesucht …"
        case .acquired:  return "GPS bereit"
        case .denied:    return "Kein GPS-Zugriff"
        case .unknown:   return "GPS wird vorbereitet …"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // MARK: Map im Hintergrund
            mapLayer
                .ignoresSafeArea()
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        followUser = false       // Karte bewegt → Follow aus
                    }
                )

            // MARK: Overlay-Layout (Top-Button + Bottom-Cards)
            VStack {
                // Top-Close-Button
                HStack {
                    Button {
                        cancelTapped()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                    }
                    .padding(.leading, 16)

                    Spacer()
                }
                .padding(.top, 12)

                Spacer()

                // Bottom Cards
                VStack(spacing: 14) {
                    statusCard
                    controlsBar
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }

            // Rechte Strava-Leiste
            rightSideControls

            // MARK: Vollbild-Stats Overlay
            if showFullStats {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)

                RunningStatsExpandedView(
                    duration: formattedDuration,
                    distance: formattedDistance,
                    pace: formattedPace,
                    heartRate: healthKit.currentHeartRate.map { "\(Int($0))" } ?? "--",
                    gpsText: gpsText
                ) {
                    withAnimation(.spring()) {
                        showFullStats = false
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(50)
            }
        }
        // System-Navigation komplett verstecken
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await run.requestAuthorization()
            mapPosition = .region(run.region)
            
            // Heart Rate Streaming starten (nur Apple Watch Samples)
            if let type = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                await healthKit.requestReadAuthorizationIfNeeded(readTypes: [type], forcePrompt: false)
                healthKit.startHeartRateStreaming(filterToAppleWatch: true)
            }
        }
        .onDisappear {
            run.stopCompletely()
            healthKit.stopHeartRateStreaming()
        }
        .onReceive(run.$region) { newRegion in
            guard followUser, !is3D else { return }
            mapPosition = .region(newRegion)
        }
        // ✅ Reward-Popup
        .overlay(alignment: .center) {
            if let reward = rewardMessage {
                RunningRewardPopup(text: reward.text,
                                   icon: reward.icon,
                                   color: t.palette.primary)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(999)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeOut) { rewardMessage = nil }
                        }
                    }
            }
        }
        // ❌ Abbrechen-Alert
        .alert("Lauf abbrechen?", isPresented: $showCancelConfirm) {
            Button("Verwerfen", role: .destructive) {
                run.stopCompletely()
                dismiss()
            }
            Button("Zurück", role: .cancel) { }
        } message: {
            Text("Unfertigen Lauf verwerfen?")
        }
        // 🧾 Run-Summary
        .fullScreenCover(isPresented: $showSummary, onDismiss: { lastSavedEntry = nil }) {
            if let entry = lastSavedEntry {
                RunningSummaryView(
                    entry: entry,
                    distanceKm: lastRunDistanceKm,
                    path: lastRunPath,
                    streakWeeks: summaryStreakWeeks,
                    weekProgress: summaryWeekProgress,
                    cardioType: cardioType

                ) {
                    showSummary = false
                    dismiss()
                }
            } else {
                VStack {
                    Text("Summary").font(.title2).padding()
                    Button("Fertig") { showSummary = false; dismiss() }
                }
            }
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        Group {
            if #available(iOS 17.0, *) {
                Map(position: $mapPosition) {
                    UserAnnotation()
                    if !run.pathCoordinates.isEmpty {
                        MapPolyline(coordinates: run.pathCoordinates)
                            .stroke(t.palette.primary, lineWidth: 4)
                    }
                }
                .mapStyle(
                    isSatellite
                    ? .imagery(elevation: .realistic)
                    : .standard(elevation: .realistic)
                )
            } else {
                Map(coordinateRegion: $run.region, showsUserLocation: true)
            }
        }
    }

    // MARK: - Status Card (mit Expand-Button)

    private var statusCard: some View {
        VStack(spacing: 10) {
            // Top-Zeile: GPS-Text + Icon
            HStack {
                Text(gpsText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(run.gpsStatus == .acquired ? .green : .secondary)
                Spacer()
                Image(systemName: "location.fill")
                    .foregroundStyle(run.gpsStatus == .acquired
                                     ? .green
                                     : .secondary)
            }

            // Eine Zeile mit drei Spalten: Zeit | Distanz | Pace
            HStack(spacing: 0) {
                metricBlock(title: "Zeit", value: formattedDuration)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 40)

                metricBlock(title: "Distanz (km)", value: formattedDistance)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)

                Divider().frame(height: 40)

                metricBlock(
                    title: "\(cardioType == .cycling ? "Geschw." : "Pace") (\(cardioType.speedLabel))",
                    value: formattedPace
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(t.palette.outline.opacity(0.3), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.spring()) {
                    showFullStats = true
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .padding(10)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack(spacing: 16) {
            // Stop / Beenden
            Button {
                if run.elapsedSeconds < 5 || distanceKm < 0.05 {
                    cancelTapped()
                } else {
                    finishRunAndSave()
                }
            } label: {
                Text(run.state == .running || run.state == .paused ? "Beenden" : "Schließen")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.red.opacity(0.9))

            // Start / Pause / Weiter – großer Knopf
            Button {
                primaryActionTapped()
            } label: {
                ZStack {
                    Circle()
                        .fill(t.palette.primary)
                        .frame(width: 72, height: 72)
                    Image(systemName: primaryActionIconName())
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            // Ziel-Button: kompletten Lauf speichern
            Button {
                guard run.state == .running || run.state == .paused else { return }
                finishRunAndSave()
            } label: {
                Image(systemName: "flag.checkered")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(t.palette.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(t.palette.outline.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private func primaryActionIconName() -> String {
        switch run.state {
        case .running: return "pause"
        case .paused, .ready, .idle: return "play.fill"
        case .finished: return "checkmark"
        }
    }

    private func primaryActionTapped() {
        switch run.state {
        case .idle, .ready:
            run.start()
        case .running:
            run.pause()
        case .paused:
            run.resume()
        case .finished:
            break
        }
    }

    // MARK: - Rechte Strava-Leiste

    private var rightSideControls: some View {
        VStack(spacing: 14) {
            Spacer()

            // Map-Layer wechseln (Standard / Satellit)
            CircleIconButton(systemName: "square.3.layers.3d.down.left") {
                isSatellite.toggle()
            }

            // 3D Kamera
            CircleIconButton(systemName: "3d") {
                is3D.toggle()
                updateCameraFor3D()
            }

            // Auf Nutzer / Strecke zentrieren
            CircleIconButton(systemName: "location") {
                recenterOnUser()
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 260) // Höhe an deine UI angepasst
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Map-Helpers

    private func zoomedRegion(from region: MKCoordinateRegion, factor: Double) -> MKCoordinateRegion {
        var r = region
        r.span.latitudeDelta *= factor
        r.span.longitudeDelta *= factor
        return r
    }

    private func recenterOnUser() {
        let zoomed = zoomedRegion(from: run.region, factor: 0.5)
        withAnimation(.easeInOut) {
            followUser = true          // wieder aktivieren
            mapPosition = .region(zoomed)
        }
    }

    private func updateCameraFor3D() {
        if is3D {
            let camera = MapCamera(
                centerCoordinate: run.region.center,
                distance: 1200,
                heading: 0,
                pitch: 60
            )
            withAnimation(.easeInOut) {
                mapPosition = .camera(camera)
            }
        } else {
            withAnimation(.easeInOut) {
                mapPosition = .region(run.region)
            }
        }
    }

    // MARK: - Cancel / Save

    private func cancelTapped() {
        if run.elapsedSeconds < 1 && run.distanceMeters < 5 {
            run.stopCompletely()
            dismiss()
        } else {
            showCancelConfirm = true
        }
    }

    private func finishRunAndSave() {
        run.stop()

        let distance = distanceKm
        let duration = run.elapsedSeconds

        // Daten für Run-Summary merken
        lastRunDistanceKm = distance
        lastRunPath = run.pathCoordinates

        let prevDays = trainingStore.currentStreakDays()
        let prevWeeks = weeksCeil(fromDays: prevDays)

        gm.addXP(80)
        gm.addCoins(10)

        let titleBase = cardioType.rawValue
        let title: String
        if distance > 0 {
            title = String(format: "%@ – %.2f km", titleBase, distance)
        } else {
            title = titleBase
        }

        let polyline = encodePolyline(run.pathCoordinates)
        let emoji: String
        switch cardioType {
        case .running: emoji = "🏃‍♂️"
        case .cycling: emoji = "🚴‍♂️"
        case .walking: emoji = "🚶‍♂️"
        }
        
        let entry = TrainingEntry(
            date: Date(),
            title: title,
            exercises: [],
            duration: duration,
            totalWeight: 0,
            emoji: emoji,
            updatedAt: Date(),
            routePolyline: polyline
        )

        trainingStore.add(entry: entry)

        Task {
            await syncService.saveProfile(level: gm.level, xp: gm.xp, coins: gm.coins)
        }

        withAnimation(.spring()) {
            rewardMessage = RewardMessage(
                text: "+80 XP & +10 Coins",
                icon: "star.fill",
                color: t.palette.primary
            )
        }

        gm.unlockBadge(.firstWorkout)
        if gm.streak == 7 { gm.unlockBadge(.streak7) }

        let newDays = trainingStore.currentStreakDays(reference: entry.date)
        let newWeeks = weeksCeil(fromDays: newDays)

        if newWeeks > prevWeeks {
            summaryStreakWeeks = newWeeks
            summaryWeekProgress = weekProgress(asOf: entry.date)
        } else {
            summaryStreakWeeks = nil
            summaryWeekProgress = Array(repeating: false, count: 7)
        }

        lastSavedEntry = entry
        showSummary = true
    }

    private func weeksCeil(fromDays d: Int) -> Int {
        d == 0 ? 0 : (d + 6) / 7
    }

    private func weekProgress(asOf date: Date) -> [Bool] {
        var cal = Calendar.current
        cal.locale = .current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: date) else {
            return Array(repeating: false, count: 7)
        }
        let trained = Set(trainingStore.history.map { cal.startOfDay(for: $0.date) })
        return (0..<7).map { i in
            let day = cal.date(byAdding: .day, value: i, to: interval.start)!
            return trained.contains(cal.startOfDay(for: day))
        }
    }

    // MARK: - Vollbild-Stats View (nested)

    private struct RunningStatsExpandedView: View {
        let duration: String
        let distance: String
        let pace: String
        let heartRate: String
        let gpsText: String
        let onClose: () -> Void

        // Durchschnittsgeschwindigkeit (km/h) aus Pace (min/km)
        private var avgSpeedKmh: String {
            let components = pace.split(separator: ":")
            guard components.count == 2,
                  let minutes = Double(components[0]),
                  let seconds = Double(components[1]) else {
                return "0,0"
            }

            let totalMinutesPerKm = minutes + seconds / 60.0
            guard totalMinutesPerKm > 0 else { return "0,0" }

            let kmPerHour = 60.0 / totalMinutesPerKm
            return String(format: "%.1f", kmPerHour)
                .replacingOccurrences(of: ".", with: ",")
        }

        var body: some View {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top bar mit Close-Button
                    HStack {
                        Spacer()
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer()

                    // Main-Stats
                    VStack(spacing: 40) {
                        // Zeit
                        VStack(spacing: 8) {
                            Text(duration)
                                .font(.system(size: 48, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }

                        // Distanz
                        VStack(spacing: 12) {
                            Text(distance.replacingOccurrences(of: ".", with: ","))
                                .font(.system(size: 96, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)

                            Text("Distance (km)")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }

                        // 🔹 NEU: Pace
                         VStack(spacing: 8) {
                             Text(pace)
                                 .font(.system(size: 48, weight: .bold))
                                 .monospacedDigit()
                                 .minimumScaleFactor(0.5)
                                 .lineLimit(1)

                             Text("Pace (min/km)")
                                 .font(.system(size: 18))
                                 .foregroundStyle(.secondary)
                         }

                        
                        // Durchschnittsgeschwindigkeit
                        VStack(spacing: 8) {
                            Text(avgSpeedKmh)
                                .font(.system(size: 48, weight: .bold))
                                .monospacedDigit()

                            Text("Avg. speed (km/h)")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }

                        // Herzfrequenz
                        VStack(spacing: 12) {
                            Text(heartRate)
                                .font(.system(size: 72, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.red)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)

                            Text("Heart Rate (bpm)")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }

                        // GPS-Status
                        VStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.secondary)
                            Text(gpsText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    Color.clear.frame(height: 60)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - SESSION MANAGER (ohne Laps)
    final class RunningSessionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
        enum State { case idle, ready, running, paused, finished }
        enum GPSStatus { case unknown, searching, acquired, denied }
        
        @Published var state: State = .idle
        @Published var gpsStatus: GPSStatus = .unknown
        @Published var elapsedSeconds: Double = 0
        @Published var distanceMeters: Double = 0
        @Published var region: MKCoordinateRegion = .init(
            center: CLLocationCoordinate2D(latitude: 50.0, longitude: 8.0),
            span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        @Published var pathCoordinates: [CLLocationCoordinate2D] = []
        
        private let locationManager = CLLocationManager()
        private var timer: Timer?
        private var runStartDate: Date?
        private var elapsedBeforePause: Double = 0
        private var lastLocation: CLLocation?
        
        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.activityType = .fitness
        }
        
        // MARK: - Permissions
        func requestAuthorization() async {
            let status = locationManager.authorizationStatus
            switch status {
            case .notDetermined:
                gpsStatus = .searching
                locationManager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                gpsStatus = .acquired
                locationManager.startUpdatingLocation()
                state = .ready
            case .denied, .restricted:
                gpsStatus = .denied
            @unknown default:
                gpsStatus = .unknown
            }
        }
        
        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            Task { @MainActor in
                await requestAuthorization()
            }
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.last else { return }
            
            // 1) Schlechte GPS-Punkte direkt ignorieren
            let minAccuracy: CLLocationAccuracy = 25
            guard loc.horizontalAccuracy > 0,
                  loc.horizontalAccuracy <= minAccuracy else {
                return
            }
            
            if gpsStatus != .denied {
                gpsStatus = .acquired
            }
            
            // Region nur updaten, nicht zoomen
            region.center = loc.coordinate
            
            // Wenn wir gerade nicht laufen: nur lastLocation merken und raus
            guard state == .running else {
                lastLocation = loc
                return
            }
            
            // 2) Distanz / Routen-Filter
            let minDistance: CLLocationDistance = 4
            let maxJump: CLLocationDistance = 60
            
            if let last = lastLocation {
                let delta = loc.distance(from: last)
                
                if delta > maxJump {
                    lastLocation = loc
                    return
                }
                
                if delta >= minDistance {
                    distanceMeters += delta
                    pathCoordinates.append(loc.coordinate)
                    lastLocation = loc
                }
            } else {
                pathCoordinates.append(loc.coordinate)
                lastLocation = loc
            }
        }
        
        
        // MARK: - State Machine
        func start() {
            guard state == .ready || state == .idle else { return }
            elapsedSeconds = 0
            distanceMeters = 0
            elapsedBeforePause = 0
            pathCoordinates = []
            runStartDate = Date()
            state = .running
            startTimer()
            locationManager.startUpdatingLocation()
        }
        
        func pause() {
            guard state == .running else { return }
            timer?.invalidate()
            if let start = runStartDate {
                elapsedBeforePause += Date().timeIntervalSince(start)
            }
            state = .paused
        }
        
        func resume() {
            guard state == .paused else { return }
            runStartDate = Date()
            state = .running
            startTimer()
        }
        
        func stop() {
            guard state == .running || state == .paused else { return }
            timer?.invalidate()
            if state == .running, let start = runStartDate {
                elapsedBeforePause += Date().timeIntervalSince(start)
            }
            elapsedSeconds = elapsedBeforePause
            state = .finished
        }
        
        func stopCompletely() {
            timer?.invalidate()
            locationManager.stopUpdatingLocation()
            state = .idle
            elapsedSeconds = 0
            distanceMeters = 0
            pathCoordinates = []
            elapsedBeforePause = 0
            runStartDate = nil
        }
        
        private func startTimer() {
            timer?.invalidate()
            let startRef = runStartDate ?? Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self else { return }
                guard self.state == .running else { return }
                let base = self.elapsedBeforePause
                let extra = Date().timeIntervalSince(startRef)
                self.elapsedSeconds = base + extra
            }
        }
    }
    
    
    // MARK: - RUNNING SUMMARY VIEW
    struct RunningSummaryView: View {
        let entry: TrainingEntry
        let distanceKm: Double
        let path: [CLLocationCoordinate2D]
        let streakWeeks: Int?
        let weekProgress: [Bool]
        var onDone: () -> Void
        let cardioType: CardioType

        
        @Environment(\.designTokens) private var t
        
        @State private var region: MKCoordinateRegion
        @State private var showCongrats = false
        
        init(entry: TrainingEntry,
             distanceKm: Double,
             path: [CLLocationCoordinate2D],
             streakWeeks: Int?,
             weekProgress: [Bool],
             cardioType: CardioType,
             onDone: @escaping () -> Void)
        {
            self.entry = entry
            self.distanceKm = distanceKm
            self.path = path
            self.streakWeeks = streakWeeks
            self.weekProgress = weekProgress
            self.cardioType = cardioType
            self.onDone = onDone
            
            _region = State(initialValue: RunningSummaryView.makeRegion(for: path))
        }
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        routeCard
                        statsCard
                        primaryCTA
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .navigationTitle("Run Summary")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Fertig") { continueTapped() }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCongrats) {
                StreakCongratsView(
                    unlockedWeeks: streakWeeks ?? 0,
                    weekProgress: weekProgress
                ) {
                    showCongrats = false
                    onDone()
                }
                .preferredColorScheme(.dark)
            }
        }
        
        // MARK: - Sections
        
        private var header: some View {
            VStack(spacing: 6) {
                Text(entry.title.isEmpty ? "Run" : entry.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text(dateString(entry.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        
        private var routeCard: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Route")
                    .font(.headline)
                
                Group {
                    if #available(iOS 17.0, *) {
                        Map(initialPosition: .region(region)) {
                            if !path.isEmpty {
                                MapPolyline(coordinates: path)
                                    .stroke(t.palette.primary, lineWidth: 4)
                            }
                        }
                    } else {
                        Map(coordinateRegion: $region)
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(14)
            .appElevatedCard()
        }
        
        private var statsCard: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stats")
                    .font(.headline)
                
                HStack(spacing: 0) {
                    statCell(title: "Distance", value: formattedDistance, unit: "km")
                    Divider().frame(height: 44)
                    statCell(title: cardioType == .cycling ? "Avg Speed" : "Avg Pace", value: formattedPace, unit: cardioType.speedLabel)
                    Divider().frame(height: 44)
                    statCell(title: "Time", value: formattedDuration, unit: nil)
                }
            }
            .padding(14)
            .appElevatedCard()
        }
        
        private func statCell(title: String, value: String, unit: String?) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    if let unit {
                        Text(unit)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        private var primaryCTA: some View {
            Button {
                continueTapped()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
        
        // MARK: - Actions
        
        private func continueTapped() {
            if streakWeeks != nil {
                showCongrats = true
            } else {
                onDone()
            }
        }
        
        // MARK: - Helpers: Region & Formatting
        
        private static func makeRegion(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
            guard let first = coords.first else {
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 50, longitude: 8),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
            
            var minLat = first.latitude
            var maxLat = first.latitude
            var minLon = first.longitude
            var maxLon = first.longitude
            
            for c in coords {
                minLat = min(minLat, c.latitude)
                maxLat = max(maxLat, c.latitude)
                minLon = min(minLon, c.longitude)
                maxLon = max(maxLon, c.longitude)
            }
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let extra = 1.3
            let latDelta = max((maxLat - minLat) * extra, 0.005)
            let lonDelta = max((maxLon - minLon) * extra, 0.005)
            
            return MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        }
        
        private var formattedDistance: String {
            String(format: "%.2f", distanceKm)
        }
        
        private var formattedDuration: String {
            let total = Int(entry.duration)
            let h = total / 3600
            let m = (total % 3600) / 60
            let s = total % 60
            
            if h > 0 {
                return String(format: "%d:%02d:%02d", h, m, s)
            } else {
                return String(format: "%02d:%02d", m, s)
            }
        }
        
        private var formattedPace: String {
            guard distanceKm > 0 else { return "--:--" }
            let secondsPerKm = entry.duration / distanceKm
            let m = Int(secondsPerKm) / 60
            let s = Int(secondsPerKm) % 60
            return String(format: "%d:%02d", m, s)
        }
        
        private func dateString(_ d: Date) -> String {
            let f = DateFormatter()
            f.dateStyle = .full
            return f.string(from: d)
        }
    }
    
    
    // MARK: - Kleine runde Icon-Buttons rechts
    
    private struct CircleIconButton: View {
        let systemName: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 52, height: 52)
                    if systemName == "3d" {
                        Text("3D")
                            .font(.headline.weight(.semibold))
                    } else {
                        Image(systemName: systemName)
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            .buttonStyle(.plain)
            .shadow(radius: 8)
        }
    }
    
    
    // MARK: - Reward Popup (Running)
    
    private struct RunningRewardPopup: View {
        let text: String
        let icon: String
        let color: Color
        @Environment(\.designTokens) private var t
        
        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(color)
                Text(text)
                    .font(.headline.bold())
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [t.palette.surfaceA, t.palette.surfaceB],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(t.palette.outline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
            .padding()
        }
    }
    
    
    // MARK: - Polyline ENcodieren (CLLocationCoordinate2D[] -> String)
    
    func encodePolyline(_ coords: [CLLocationCoordinate2D]) -> String {
        guard !coords.isEmpty else { return "" }
        
        var output = ""
        var lastLat = 0
        var lastLon = 0
        
        for coord in coords {
            let lat = Int(round(coord.latitude * 1e5))
            let lon = Int(round(coord.longitude * 1e5))
            
            let dLat = lat - lastLat
            let dLon = lon - lastLon
            
            output.append(encodeSigned(dLat))
            output.append(encodeSigned(dLon))
            
            lastLat = lat
            lastLon = lon
        }
        
        return output
    }
    
    private func encodeSigned(_ value: Int) -> String {
        var v = value << 1
        if value < 0 {
            v = ~v
        }
        
        var chunks: [UInt8] = []
        
        while v >= 0x20 {
            let chunk = UInt8((0x20 | (v & 0x1f)) + 63)
            chunks.append(chunk)
            v >>= 5
        }
        chunks.append(UInt8(v + 63))
        
        return String(bytes: chunks, encoding: .utf8) ?? ""
    }
}
