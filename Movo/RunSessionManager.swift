import Foundation
import CoreLocation
import Combine

final class RunSessionManager: NSObject, ObservableObject {
    enum State {
        case idle
        case running
        case paused
        case finished
    }

    // MARK: - Public @Published

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var locations: [CLLocation] = []

    // MARK: - Derived values

    var distanceKm: Double { distanceMeters / 1000.0 }

    /// Durchschnittspace in Sekunden pro km (nil, wenn Distanz 0)
    var averagePaceSecondsPerKm: Double? {
        guard distanceKm > 0 else { return nil }
        return elapsed / distanceKm
    }

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private var timer: Timer?
    private var startDate: Date?
    private var pausedElapsed: TimeInterval = 0
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // mindestens 5m, um Noise zu reduzieren
    }

    // MARK: - Permissions

    func requestAuthorizationIfNeeded() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    // MARK: - Controls

    func start() {
        guard state == .idle || state == .finished else { return }

        requestAuthorizationIfNeeded()

        elapsed = 0
        distanceMeters = 0
        locations = []
        pausedElapsed = 0
        startDate = Date()
        lastLocation = nil

        state = .running
        startTimer()
        locationManager.startUpdatingLocation()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        stopTimer()
        pausedElapsed = elapsed
        locationManager.stopUpdatingLocation()
    }

    func resume() {
        guard state == .paused else { return }
        startDate = Date()
        state = .running
        startTimer()
        locationManager.startUpdatingLocation()
    }

    func stop() {
        guard state == .running || state == .paused else { return }
        state = .finished
        stopTimer()
        locationManager.stopUpdatingLocation()
    }

    func reset() {
        stop()
        state = .idle
        elapsed = 0
        distanceMeters = 0
        locations = []
        pausedElapsed = 0
        startDate = nil
        lastLocation = nil
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let base = pausedElapsed
        let startRef = startDate ?? Date()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, self.state == .running else { return }
            let e = base + Date().timeIntervalSince(startRef)
            DispatchQueue.main.async {
                self.elapsed = e
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Location handling

    private func handleNewLocations(_ newLocations: [CLLocation]) {
        guard state == .running else { return }

        for loc in newLocations {
            // Filter raus: sehr alte oder ungenaue Samples
            guard loc.horizontalAccuracy >= 0,
                  loc.horizontalAccuracy <= 40,
                  abs(loc.timestamp.timeIntervalSinceNow) < 10
            else { continue }

            if let last = lastLocation {
                let delta = loc.distance(from: last)
                // kleine Jitter ignorieren
                if delta > 1 {
                    distanceMeters += delta
                }
            }

            lastLocation = loc
            locations.append(loc)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension RunSessionManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Optional: Bei granted direkt loslegen oder nur Status merken
        // Hier machen wir nichts – Start wird manuell aus dem View getriggert.
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
        handleNewLocations(newLocations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[RUN] Location error:", error.localizedDescription)
    }
}
