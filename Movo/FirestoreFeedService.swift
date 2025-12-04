import Foundation
import FirebaseFirestore
import FirebaseAuth

public protocol FeedService {
    func listenAcceptedFriendIds(of uid: String) -> AsyncStream<[String]>
    func listenRecentTrainings(for userIds: [String], perChunkLimit: Int, totalCap: Int) -> AsyncStream<[SocialTraining]>
}

public final class FirestoreFeedService: FeedService {
    private let db = Firestore.firestore()

    public init() {}

    public func listenAcceptedFriendIds(of uid: String) -> AsyncStream<[String]> {
        AsyncStream { cont in
            let q = db.collection("users").document(uid).collection("friends")
                .whereField("status", isEqualTo: "accepted")
            let l = q.addSnapshotListener { snap, err in
                if let err { print("friends listen error:", err); return }
                cont.yield(snap?.documents.map { $0.documentID } ?? [])
            }
            cont.onTermination = { _ in l.remove() }
        }
    }

    // Firestore whereIn: max 10 ⇒ chunken
    public func listenRecentTrainings(
        for userIds: [String],
        perChunkLimit: Int = 10,
        totalCap: Int = 50
    ) -> AsyncStream<[SocialTraining]> {
        AsyncStream { cont in
            guard !userIds.isEmpty else {
                cont.yield([])
                cont.finish()
                return
            }

            var regs: [ListenerRegistration] = []

            func attach(chunk: [String]) {
                print("[FEED] Listening for users:", chunk)

                let q = db.collection("trainings")
                    .whereField("userId", in: chunk)                 // nur Freunde (max 10, du chunkst ja)
                    .whereField("visibility", isEqualTo: "public")   // nur öffentliche
                    .order(by: "createdAt", descending: true)
                    .limit(to: perChunkLimit)


                let r = q.addSnapshotListener { snap, err in
                    if let err = err {
                        print("[FEED] ❌ listenRecentTrainings error:", err.localizedDescription)
                        return
                    }

                    guard let docs = snap?.documents, !docs.isEmpty else {
                        print("[FEED] ⚠️ Empty snapshot for chunk \(chunk)")
                        cont.yield([])
                        return
                    }

                    let items: [SocialTraining] = docs.compactMap {
                        do {
                            return try $0.data(as: SocialTraining.self)
                        } catch {
                            print("[FEED] ⚠️ decode error for \($0.documentID):", error)
                            return nil
                        }
                    }

                    print("[FEED] ✅ Got \(items.count) trainings from chunk \(chunk)")
                    cont.yield(items)
                }

                regs.append(r)
            }

            // Firestore "whereIn" unterstützt max. 10 Werte → daher aufteilen
            stride(from: 0, to: userIds.count, by: 10).forEach { i in
                let end = min(i + 10, userIds.count)
                let chunk = Array(userIds[i..<end])
                attach(chunk: chunk)
            }

            // Aufräumen bei Stream-Ende
            cont.onTermination = { _ in
                regs.forEach { $0.remove() }
                print("[FEED] 🔚 Feed listeners removed")
            }
        }
    }
}

public extension Array {
    func uniqued<T: Hashable>(by key: (Element) -> T) -> [Element] {
        var seen = Set<T>(); return filter { seen.insert(key($0)).inserted }
    }
}
