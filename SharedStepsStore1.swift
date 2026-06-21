//
//  SharedStores.swift
//  App & Widgets Extension (beide Targets einbinden)
//

import Foundation
import WidgetKit

// =====================================================
// MARK: - Trainings-Wochen (file-basiert, App Group)
// =====================================================

public struct WeekCount: Codable, Equatable {
    public let start: Date   // Wochenbeginn (Calendar.startOfWeek)
    public let count: Int
}

public struct TrainingWeeksSnapshot: Codable {
    public let updated: Date
    public let goalPerWeek: Int
    public let lastWeeks: [WeekCount]   // älteste -> neueste (z. B. 8 Wochen)
}

/// Dateibasierter App-Group-Store (robust, kein CFPreferences)
public enum TrainingWeeklyShared {
    private static let groupID = "group.com.movo"  // <- App Group in App & Widgets aktivieren!
    private static var url: URL {
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)!
        return dir.appendingPathComponent("training_weeks_snapshot.json")
    }

    public static func load() -> TrainingWeeksSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TrainingWeeksSnapshot.self, from: data)
    }

    public static func save(_ snap: TrainingWeeksSnapshot) {
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: url, options: .atomic)
        } catch {
            print("TrainingWeeklyShared.save error:", error)
        }
    }

    /// Rechnet aus kompletter History die letzten N Wochen aus und speichert sie.
    /// `dateProvider` liefert das Datum einer Trainingseinheit (z. B. `\TrainingEntry.date`)
    public static func saveWeeks<TE>(
        from history: [TE],
        weeks: Int = 8,
        goalPerWeek: Int = 3,
        dateProvider: (TE) -> Date
    ) {
        let cal = Calendar.current
        let now = Date()
        // Start der aktuellen Woche (lokal)
        let curStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)

        // Buckets für letzte N Wochen (inkl. aktueller), vorbefüllt mit 0
        var buckets: [Date: Int] = [:]
        for i in stride(from: weeks - 1, through: 0, by: -1) {
            if let start = cal.date(byAdding: .weekOfYear, value: -i, to: curStart) {
                buckets[start] = 0
            }
        }

        // Zähle Trainings pro Woche
        for item in history {
            let d = dateProvider(item)
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: d)?.start else { continue }
            if buckets.keys.contains(weekStart) {
                buckets[weekStart, default: 0] += 1
            }
        }

        // Sortiere älteste -> neueste
        let weeksArr = buckets.keys.sorted().map { WeekCount(start: $0, count: buckets[$0] ?? 0) }
        let snap = TrainingWeeksSnapshot(updated: now, goalPerWeek: goalPerWeek, lastWeeks: weeksArr)
        save(snap)
    }
}

// ================================================
// MARK: - Schritte (Snapshot + Premium-Flag)
// ================================================

import Foundation
import WidgetKit
import os.log
import StoreKit

public enum AppGroup {
    // ❗️GENAU diese ID in allen Targets bei "Signing & Capabilities" anhaken
    public static let id = "group.com.movo"

    public static var containerURL: URL {
        guard let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
            fatalError("AppGroup containerURL is nil. Check App Groups capability in this target!")
        }
        return u
    }
}

// MARK: Shared Steps Snapshot (dein vorhandenes Modell benutzen)
public struct StepsDayCompact: Codable, Equatable {
    public let d: Date
    public let s: Int
    public init(d: Date, s: Int) { self.d = d; self.s = s }
}

public struct StepsSnapshot: Codable {
    public let date: Date
    public let stepsToday: Int
    public let goal: Int
    public let lastDays: [StepsDayCompact]?
    public var premiumUnlocked: Bool
    public let hourlyHistory: [Double]?

    public init(date: Date, stepsToday: Int, goal: Int, lastDays: [StepsDayCompact]? = nil, premiumUnlocked: Bool = false, hourlyHistory: [Double]? = nil) {
        self.date = date; self.stepsToday = stepsToday; self.goal = goal
        self.lastDays = lastDays; self.premiumUnlocked = premiumUnlocked
        self.hourlyHistory = hourlyHistory
    }

    enum CodingKeys: String, CodingKey { case date, stepsToday, goal, lastDays, premiumUnlocked, hourlyHistory }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        stepsToday = try c.decode(Int.self, forKey: .stepsToday)
        goal = try c.decode(Int.self, forKey: .goal)
        lastDays = try c.decodeIfPresent([StepsDayCompact].self, forKey: .lastDays)
        premiumUnlocked = try c.decodeIfPresent(Bool.self, forKey: .premiumUnlocked) ?? false
        hourlyHistory = try c.decodeIfPresent([Double].self, forKey: .hourlyHistory)
    }
}

// MARK: StepsShared – zentraler Store + Diagnose
public enum StepsShared {
    private static var fileURL: URL {
        AppGroup.containerURL.appendingPathComponent("steps_snapshot.json")
    }
    
    
    /// Heutige Schritte + Ziel speichern und Widgets sofort aktualisieren.
    public static func updateToday(steps: Int, goal: Int, hourlyHistory: [Double]? = nil, date: Date = Date()) {
        let old = load()
        let snap = StepsSnapshot(
            date: date,
            stepsToday: steps,
            goal: goal,
            lastDays: old?.lastDays,
            premiumUnlocked: old?.premiumUnlocked ?? false,
            hourlyHistory: hourlyHistory
        )
        save(snap)
        // nur die betroffenen Widgets refreshen
        WidgetCenter.shared.reloadTimelines(ofKind: "StepsWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "StepsWeeklyWidget")
    }

    

    public static func load() -> StepsSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(StepsSnapshot.self, from: data)
    }

    public static func save(_ snap: StepsSnapshot) {
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            os_log("StepsShared.save error: %@", "\(error)")
        }
    }

    public static func saveMerging(date: Date = .now, stepsToday: Int, goal: Int) {
        let old = load()
        let snap = StepsSnapshot(date: date,
                                 stepsToday: stepsToday,
                                 goal: goal,
                                 lastDays: old?.lastDays,
                                 premiumUnlocked: old?.premiumUnlocked ?? false,
                                 hourlyHistory: old?.hourlyHistory)
        save(snap)
    }

    public static func saveHistory(days: [StepsDayCompact], goal: Int) {
        let old = load()
        let snap = StepsSnapshot(date: old?.date ?? .now,
                                 stepsToday: old?.stepsToday ?? 0,
                                 goal: goal,
                                 lastDays: days,
                                 premiumUnlocked: old?.premiumUnlocked ?? false,
                                 hourlyHistory: old?.hourlyHistory)
        save(snap)
    }

    public static func setPremium(_ unlocked: Bool) {
        var snap = load() ?? StepsSnapshot(date: .now, stepsToday: 0, goal: 8000, hourlyHistory: nil)
        snap.premiumUnlocked = unlocked
        save(snap)
        WidgetCenter.shared.reloadAllTimelines()
        debugDump(prefix: "setPremium(\(unlocked))") // <- Log
    }

    public static func isPremiumUnlocked() -> Bool { load()?.premiumUnlocked ?? false }

    // MARK: Diagnose: prüft Pfad + Inhalt
    public static func debugDump(prefix: String = "StepsShared") {
        let path = fileURL.path
        let exists = FileManager.default.fileExists(atPath: path)
        let snap = load()
        os_log("%@: path=%@ exists=%@ premium=%@ steps=%@ goal=%@",
               prefix, path, exists ? "true" : "false",
               (snap?.premiumUnlocked == true) ? "true" : "false",
               "\(snap?.stepsToday ?? -1)", "\(snap?.goal ?? -1)")
    }

    /// Schreibt eine Test-Marker-Datei, damit du im Widget genau denselben Pfad siehst
    public static func writeMarker() {
        let markerURL = AppGroup.containerURL.appendingPathComponent("marker.txt")
        try? "MARKER \(Date())".data(using: .utf8)?.write(to: markerURL, options: .atomic)
        os_log("Wrote marker at %@", markerURL.path)
    }
}

// Optional: StoreKit-Fallback als Helper (für Provider)
public enum PremiumResolver {
    private static let ids: Set<String> = [
        "com.benepkt.movo.premium.monthly",
        "com.benepkt.movo.premium.yearly",
        "com.benepkt.movo.premium.lifetime"
    ]

    public static func resolve() async -> Bool {
        if StepsShared.isPremiumUnlocked() { return true }
        do {
            for await r in StoreKit.Transaction.currentEntitlements {
                if case .verified(let t) = r, ids.contains(t.productID) { return true }
            }
        } catch { }
        return false
    }
}
