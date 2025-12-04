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
        let threshold = level * 100
        if xp >= threshold {
            level += 1
            unlockBadge(.level5) // Beispiel-Badge
        }
        save()
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

// MARK: - Farben
extension Color {
    static let gold = Color(red: 212/255, green: 175/255, blue: 55/255)
}

// MARK: - Detail-View (optional lokalisiert)
struct GamificationDetailView: View {
    @EnvironmentObject var gm: GamificationManager
    @EnvironmentObject var appSettings: AppSettings   // ⬅️ für Übersetzungen

    private var levelThreshold: Int { max(1, gm.level * 100) }
    private var xpInThisLevel: Int { gm.xp % levelThreshold }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Level & XP
                VStack(spacing: 8) {
                    Text(String(format: appSettings.localized("profile.level"), gm.level))
                        .font(.largeTitle.bold())

                    ProgressView(value: Double(xpInThisLevel), total: Double(levelThreshold))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.horizontal)

                    Text("\(xpInThisLevel)/\(levelThreshold) \(appSettings.localized("profile.xp"))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))

                // Coins & Streak
                HStack(spacing: 20) {
                    GamificationStatCard(
                        title: appSettings.localized("profile.coins"),
                        value: "\(gm.coins)",
                        icon: "dollarsign.circle.fill",
                        color: .gold
                    )

                    GamificationStatCard(
                        title: "Streak", // falls gewünscht: eigenen Key anlegen, z. B. gamification.streak
                        value: "\(gm.streak)🔥",
                        icon: "flame.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // Badges
                VStack(alignment: .leading, spacing: 12) {
                    Text(appSettings.localized("profile.badges"))
                        .font(.title2.bold())
                        .padding(.horizontal)

                    if gm.badges.isEmpty {
                        Text(appSettings.localized("gamification.badges.empty"))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                            ForEach(gm.badges) { badge in
                                VStack(spacing: 8) {
                                    Image(systemName: badge.icon)
                                        .font(.system(size: 36))
                                        .foregroundColor(badge.color)
                                    // ⬇️ lokalisiert mit Fallback
                                    Text(localizedBadgeTitle(badge))
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(appSettings.localized("gamification.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localizedBadgeTitle(_ badge: BadgeItem) -> String {
        let key = badge.titleKey
        let value = appSettings.localized(key)
        return (value == key) ? badge.displayName : value
    }
}

// Kleine Stat-Karte (Coins, Streak etc.)
struct GamificationStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
    }
}
