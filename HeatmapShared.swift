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

    // A small writer actor to serialize and debounce disk writes so UI isn't blocked.
    private actor HeatmapWriter {
        static let shared = HeatmapWriter()

        private var pending: HeatmapSnapshot?
        private var isScheduled = false

        func enqueue(_ snap: HeatmapSnapshot, to url: URL) async {
            pending = snap
            guard !isScheduled else { return }
            isScheduled = true
            await scheduleWrite(to: url)
        }

        private func scheduleWrite(to url: URL) async {
            // Debounce a bit to coalesce multiple quick updates (e.g. logging sets rapidly)
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300 ms
            } catch { /* task cancelled */ }

            guard let snap = pending else {
                isScheduled = false
                return
            }

            do {
                let data = try JSONEncoder().encode(snap)
                try data.write(to: url, options: .atomic)
            } catch {
                print("HeatmapShared.save error:", error)
            }

            // Reset state
            pending = nil
            isScheduled = false
        }
    }

    public static func load() -> HeatmapSnapshot? {
        // Loading is fast enough for most cases; keep synchronous for simplicity.
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(HeatmapSnapshot.self, from: data)
    }

    public static func save(_ snap: HeatmapSnapshot) {
        // Offload to the writer actor so we don't block the caller (e.g. Watch UI)
        Task {
            await HeatmapWriter.shared.enqueue(snap, to: fileURL)
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

        // Save asynchronously (debounced) to avoid blocking UI
        save(HeatmapSnapshot(updated: Date(), days: out))
    }

    /// Convenience overload if you already have plain dates.
    public static func saveSnapshot(fromDates dates: [Date], endDate: Date? = nil) {
        saveSnapshot(from: dates, endDate: endDate) { $0 }
    }
}
