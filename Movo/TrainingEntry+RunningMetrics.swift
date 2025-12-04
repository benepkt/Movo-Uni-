import Foundation
import MapKit

extension TrainingEntry {
    var isJogging: Bool { title.lowercased() == "joggen" }

    /// Distanz in km
    /// Primär aus der Route (präziser). Fallback: für ältere Einträge,
    /// bei denen du Distanz in `totalWeight` (Meter) gespeichert hast.
    var distanceKm: Double {
        if let route = route, route.count > 1 {
            var total: CLLocationDistance = 0
            for i in 1..<route.count {
                let p1 = MKMapPoint(route[i-1])
                let p2 = MKMapPoint(route[i])
                total += p1.distance(to: p2)
            }
            return total / 1000.0
        } else if isJogging {
            return max(0, totalWeight) / 1000.0
        } else {
            return 0
        }
    }

    /// Pace in Sekunden pro km
    var paceSecPerKm: Double? {
        guard distanceKm > 0 else { return nil }
        return duration / distanceKm
    }

    var formattedPace: String {
        guard let p = paceSecPerKm else { return "–" }
        let m = Int(p) / 60
        let s = Int(p) % 60
        return String(format: "%d:%02d min/km", m, s)
    }

    /// Durchschnittsgeschwindigkeit in km/h
    var avgSpeedKmh: Double? {
        guard duration > 0 else { return nil }
        return distanceKm / (duration / 3600.0)
    }

    var formattedSpeed: String {
        guard let v = avgSpeedKmh else { return "–" }
        return String(format: "%.1f km/h", v)
    }
}
