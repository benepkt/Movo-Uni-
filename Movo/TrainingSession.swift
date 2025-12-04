import Foundation
import CoreLocation

struct TrainingSession: Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval  // Sekunden
    let distance: Double        // in Metern
    let route: [CLLocationCoordinate2D]

    init(date: Date, duration: TimeInterval, distance: Double, route: [CLLocationCoordinate2D]) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.distance = distance
        self.route = route
    }

    // Optional: für einfachere Anzeige
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var distanceInKm: Double {
        distance / 1000
    }
}
