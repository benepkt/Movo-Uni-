// HeatmapShared.swift
// Shared by App target and Widgets extension (add to both targets)

import Foundation

public struct HeatmapDayCompact: Codable, Equatable {
    public let d: Date   // startOfDay
    public let c: Int    // workout count that day
    public init(d: Date, c: Int) { self.d = d; self.c = c }
}

public struct HeatmapSnapshot: Codable, Equatable {
    public let updated: Date
    public let days: [HeatmapDayCompact]   // oldest -> newest, continuous per day
    public init(updated: Date, days: [HeatmapDayCompact]) {
        self.updated = updated
        self.days = days
    }
}

public enum HeatmapShared {
    // Use the same App Group helper you already have
    private static var fileURL: URL {
        AppGroup.containerURL.appendingPathComponent("training_heatmap_snapshot.json")
    }

    public static func load() -> HeatmapSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(HeatmapSnapshot.self, from: data)
    }

    public static func save(_ snap: HeatmapSnapshot) {
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("HeatmapShared.save error:", error)
        }
    }

    /// Build and persist a continuous 52-week (364 days) snapshot from a history array.
    /// - Parameters:
    ///   - history: Your history array (e.g. [TrainingEntry] in the app target)
    ///   - endDate: Optional end anchor (defaults to today at start-of-day)
    ///   - dateProvider: Closure that returns the date for each history item (e.g. \.date)
    public static func saveSnapshot<TE>(
        from history: [TE],
        endDate: Date? = nil,
        dateProvider: (TE) -> Date
    ) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: endDate ?? Date())
        let start = cal.date(byAdding: .day, value: -(7 * 52 - 1), to: end)! // 364 days

        // Count workouts per start-of-day within the span
        var counts: [Date: Int] = [:]
        for item in history {
            let d = cal.startOfDay(for: dateProvider(item))
            if d >= start && d <= end {
                counts[d, default: 0] += 1
            }
        }

        // Emit continuous array oldest -> newest (pad missing days with 0)
        var out: [HeatmapDayCompact] = []
        var day = start
        while day <= end {
            out.append(HeatmapDayCompact(d: day, c: counts[day] ?? 0))
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }

        save(HeatmapSnapshot(updated: Date(), days: out))
    }

    /// Convenience overload if you already have plain dates.
    public static func saveSnapshot(fromDates dates: [Date], endDate: Date? = nil) {
        saveSnapshot(from: dates, endDate: endDate) { $0 }
    }
}
