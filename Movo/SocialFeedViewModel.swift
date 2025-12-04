import Foundation
import Combine

@MainActor
public final class SocialFeedViewModel: ObservableObject {
    @Published public private(set) var feed: [SocialTraining] = []
    @Published public private(set) var friendCount: Int = 0

    private let service: FeedService
    private var friendsTask: Task<Void, Never>?
    private var feedTask: Task<Void, Never>?

    public init(service: FeedService) { self.service = service }

    public func start(uid: String) {
        stop()
        friendsTask = Task {
            for await friends in service.listenAcceptedFriendIds(of: uid) {
                self.friendCount = friends.count
                await self.listenFeed(userIds: [uid] + friends)
            }
        }
    }

    public func stop() { friendsTask?.cancel(); friendsTask = nil; feedTask?.cancel(); feedTask = nil }

    private func listenFeed(userIds: [String]) async {
        feedTask?.cancel()
        feedTask = Task { [service] in
            var merged: [String: SocialTraining] = [:]  // id → doc
            for await chunk in service.listenRecentTrainings(for: userIds, perChunkLimit: 10, totalCap: 50) {
                for item in chunk {
                    if let id = item.id { merged[id] = item }
                }
                let sorted = merged.values.sorted { $0.createdAt > $1.createdAt }
                self.feed = Array(sorted.prefix(50))
            }
        }
    }

    public func lastTrainings(_ limit: Int) -> [SocialTraining] { Array(feed.prefix(limit)) }
}

// SocialPublisher.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore

enum TrainingVisibility: String { case `private`, friends, `public` }

struct SocialPublisher {

    /// Legt ein Social-Doc unter /trainings an (für den Freundes-Feed).
    static func publish(type: String,
                        startedAt: Date,
                        durationMin: Int,
                        visibility: TrainingVisibility = .public,
                        userDisplayName overrideName: String? = nil) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let name = overrideName ?? Auth.auth().currentUser?.displayName ?? ""

        let data: [String: Any] = [
            "userId": uid,
            "userDisplayName": name,
            "type": type,
            "durationMin": durationMin,
            "startedAt": Timestamp(date: startedAt),
            "createdAt": FieldValue.serverTimestamp(),   // sortier-/index-feld
            "visibility": visibility.rawValue            // ← "public" für den Feed
        ]

        do {
            try await Firestore.firestore()
                .collection("trainings")
                .addDocument(data: data)
            print("[SOCIAL] ✅ published public training")
        } catch {
            print("[SOCIAL] ❌ publish error:", error.localizedDescription)
        }
    }
}
