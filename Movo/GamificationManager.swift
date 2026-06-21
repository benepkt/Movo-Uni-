import SwiftUI
import Combine

// MARK: - Badge-System
enum BadgeType: String, Codable, CaseIterable {
    case firstWorkout
    case streak7
    case coinCollector
    case level5
}

struct BadgeItem: Identifiable, Codable, Equatable {
    let id = UUID()
    let type: BadgeType

    // 🔑 Übersetzungs-Key (nutze appSettings.localized(titleKey) im UI)
    var titleKey: String { "badge.\(type.rawValue)" }

    var icon: String {
        switch type {
        case .firstWorkout:   return "figure.walk"
        case .streak7:        return "flame.fill"
        case .coinCollector:  return "dollarsign.circle.fill"
        case .level5:         return "star.fill"
        }
    }

    var color: Color {
        switch type {
        case .firstWorkout:   return .green
        case .streak7:        return .orange
        case .coinCollector:  return .yellow
        case .level5:         return .blue
        }
    }

    /// ⚠️ Nur noch als Fallback verwendet (falls ein Key fehlt)
    var displayName: String {
        switch type {
        case .firstWorkout:   return "Erstes Workout"
        case .streak7:        return "7-Tage Streak"
        case .coinCollector:  return "Münzsammler"
        case .level5:         return "Level 5 erreicht"
        }
    }
}

// MARK: - GamificationManager (pro-User Storage + Cloud Overrides)
final class GamificationManager: ObservableObject {
    @Published var xp: Int = 0
    @Published var level: Int = 1
    @Published var coins: Int = 0
    @Published var streak: Int = 0
    @Published var badges: [BadgeItem] = []

    private let defaults = UserDefaults.standard
    private static let activeUidKey = "active.uid" // <- von SyncService setzen: "guest" oder tatsächliche UID
    private var cancellables = Set<AnyCancellable>()

    // pro-User Storage-Key
    private var storageKey: String {
        let uid = defaults.string(forKey: Self.activeUidKey) ?? "guest"
        return "gamificationData.\(uid)"
    }

    init() {
        load()

        // Wenn SyncService in den Gastmodus wechselt -> neu laden
        NotificationCenter.default.publisher(for: .gmResetForGuest)
            .sink { [weak self] _ in self?.reloadForCurrentUser() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reloadForCurrentUser() }
            .store(in: &cancellables)
    }

    // MARK: - XP & Level
    func addXP(_ amount: Int) {
        xp += amount
        while xp >= Self.xpRequired(for: level + 1) {
            level += 1
            unlockBadge(.level5) // Beispiel-Badge
        }
        save()
    }

    func addWorkoutXP(for entry: TrainingEntry) {
        addXP(Self.xpReward(for: entry))
    }

    static func xpReward(for entry: TrainingEntry) -> Int {
        let volume = entry.exercises.reduce(0.0) { $0 + $1.totalWeight }
        let reps = entry.exercises.reduce(0) { partial, exercise in
            partial + exercise.sets.reduce(0) { $0 + (Int($1.reps.filter(\.isNumber)) ?? 0) }
        }
        let activityMinutes = entry.activities.reduce(0.0) { $0 + $1.duration / 60.0 }
        let activityDistance = entry.activities.reduce(0.0) { $0 + ($1.distanceKm ?? 0) }
        let standaloneActivityMinutes = entry.exercises.isEmpty ? entry.duration / 60.0 : 0
        let standaloneActivityDistance = entry.loggedDistanceKm ?? 0

        let strengthXP = Int((volume / 90.0).rounded()) + Int(Double(reps) * 0.18)
        let activityXP = Int((activityMinutes + standaloneActivityMinutes) * 0.65) + Int((activityDistance + standaloneActivityDistance) * 3)
        return max(12, min(180, strengthXP + activityXP))
    }

    static func xpRequired(for level: Int) -> Int {
        guard level > 1 else { return 0 }
        let step = Double(level - 1)
        return Int(step * 240.0 + pow(step, 1.72) * 150.0)
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xp >= xpRequired(for: level + 1), level < 250 {
            level += 1
        }
        return level
    }

    static func progressSnapshot(xp: Int, level: Int) -> LevelProgressSnapshot {
        let normalizedLevel = max(level, Self.level(forXP: xp))
        let previous = xpRequired(for: normalizedLevel)
        let next = xpRequired(for: normalizedLevel + 1)
        let current = max(0, xp - previous)
        let needed = max(1, next - previous)
        return LevelProgressSnapshot(
            level: normalizedLevel,
            xpInLevel: current,
            xpNeededForLevel: needed,
            xpToNextLevel: max(0, next - xp),
            progress: min(Double(current) / Double(needed), 1)
        )
    }

    // MARK: - Coins
    func addCoins(_ amount: Int) {
        coins += amount
        if coins >= 100 {
            unlockBadge(.coinCollector)
        }
        save()
    }

    // MARK: - Streak
    func updateStreak() {
        streak += 1
        if streak == 7 {
            unlockBadge(.streak7)
        }
        save()
    }

    // MARK: - Badges
    func unlockBadge(_ type: BadgeType) {
        if !badges.contains(where: { $0.type == type }) {
            badges.append(BadgeItem(type: type))
        }
        save()
    }

    // MARK: - Persistence (pro User)
    private func save() {
        let data = GamificationData(xp: xp, level: level, coins: coins, streak: streak, badges: badges)
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        // 0) Defaults
        self.xp = 0
        self.level = 1
        self.coins = 0
        self.streak = 0
        self.badges = []

        // 1) Cloud-Baseline
        if let n = defaults.value(forKey: "gm.level.cloud") as? NSNumber { self.level = n.intValue }
        if let n = defaults.value(forKey: "gm.xp.cloud")    as? NSNumber { self.xp    = n.intValue }
        if let n = defaults.value(forKey: "gm.coins.cloud") as? NSNumber { self.coins = n.intValue }

        // 2) lokale Persistenz darüberlegen
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(GamificationData.self, from: data) {
            self.xp = decoded.xp
            self.level = decoded.level
            self.coins = decoded.coins
            self.streak = decoded.streak
            self.badges = decoded.badges
        }

        self.level = Self.level(forXP: self.xp)
    }

    func reloadForCurrentUser() {
        if Thread.isMainThread { load() }
        else { DispatchQueue.main.async { [weak self] in self?.load() } }
    }

    private func applyCloudIfAvailable() {
        if let cloudLevel = defaults.object(forKey: "gm.level.cloud") as? Int { self.level = cloudLevel }
        if let cloudXP    = defaults.object(forKey: "gm.xp.cloud")    as? Int { self.xp    = cloudXP }
        if let cloudCoins = defaults.object(forKey: "gm.coins.cloud") as? Int { self.coins = cloudCoins }
    }
}

// MARK: - Codable Wrapper
struct GamificationData: Codable {
    let xp: Int
    let level: Int
    let coins: Int
    let streak: Int
    let badges: [BadgeItem]
}

struct LevelProgressSnapshot {
    let level: Int
    let xpInLevel: Int
    let xpNeededForLevel: Int
    let xpToNextLevel: Int
    let progress: Double
}

// MARK: - Farben
extension Color {
    static let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
}

// Kleine Stat-Karte (Coins, Streak etc.)
