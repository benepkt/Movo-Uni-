import Foundation
import Combine
import FirebaseAuth

/// Rein lokaler Store für Templates.
/// - Speichert pro Nutzer (inkl. Gast) in UserDefaults.
/// - Keine Firestore-Reads/Writes/Listener.
/// - Spiegelt beidseitig mit TrainingStore:
///     userTemplates  → training.templates  (beim Add/Update/Delete)
///     training.templates → userTemplates   (wenn SyncService gepullt hat)
final class TemplateStore: ObservableObject {
    // Öffentlich
    @Published private(set) var userTemplates: [TrainingTemplate] = []
    @Published private(set) var defaultTemplates: [TrainingTemplate] = []

    private let training: TrainingStore
    private var cancellables = Set<AnyCancellable>()

    // Flag, um Feedback-Loops zu verhindern, wenn wir selbst ins TrainingStore schreiben
    private var isMirroringToTraining = false

    // MARK: - Keys / Per-User Storage
    private func storageKey(for uid: String?) -> String {
        let id = uid ?? guestOwnerId()
        return "templates.\(id).v1"
    }

    // Gast-Kennung
    private func guestOwnerId() -> String {
        let key = "guest.device.id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return "guest:\(existing)"
        } else {
            let id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: key)
            return "guest:\(id)"
        }
    }

    private var currentUID: String? { Auth.auth().currentUser?.uid }
    private var authHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Init
    init(training: TrainingStore) {
        self.training = training

        // eingebaute (nicht pushbare) Defaults
        self.defaultTemplates = [
            TrainingTemplate(name: "Push",
                             exercises: [
                                "Bench press (Barbell)",
                                "Incline Dumbbell Press",
                                "Shoulder Press (Dumbbell)",
                                "Lateral Raises (Dumbbell)",
                                "Triceps Pushdown (Cable)",
                                "Overhead Triceps Extension (Cable)"
                             ],
                             ownerId: "builtin"),
            TrainingTemplate(name: "Pull",
                             exercises: [
                                "Lat Pulldown",
                                "Seated Row (Cable)",
                                "Hammer Curls (Dumbbells)",
                                "Bicep Curls (Dumbbells)"
                             ],
                             ownerId: "builtin"),
            TrainingTemplate(name: "Leg",
                             exercises: [
                                "Squats",
                                "Leg Extension",
                                "Leg Curl",
                                "Abductor",
                                "Adductor"
                             ],
                             ownerId: "builtin")
        ]

        // Initial laden (Gast oder aktueller User)
        loadForCurrentAccount()

        // Auf Account-Wechsel reagieren → neu aus lokalem Speicher laden
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            self?.loadForCurrentAccount()
        }

        // 👇 NEU: Wenn der SyncService training.templates via Cloud-Listener aktualisiert,
        // übernehmen wir diese Änderungen in userTemplates (ohne Loop).
        training.$templates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTemplates in
                guard let self = self else { return }
                // Wenn wir selbst gerade in training.templates gespiegelt haben → ignorieren
                if self.isMirroringToTraining { return }
                // Nur updaten, wenn sich etwas tatsächlich geändert hat
                if self.userTemplates != newTemplates {
                    self.userTemplates = newTemplates
                    self.persistCurrent()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }

    // MARK: - Public API

    var allTemplates: [TrainingTemplate] {
        defaultTemplates + userTemplates
    }

    func add(_ template: TrainingTemplate) {
        var t = template
        t.ownerId = currentUID ?? guestOwnerId()
        insertOrReplaceInMemory(t)
        persistCurrent()
        mirrorIntoTrainingStore()
    }

    func update(_ template: TrainingTemplate) {
        var t = template
        t.ownerId = currentUID ?? guestOwnerId()
        insertOrReplaceInMemory(t)
        persistCurrent()
        mirrorIntoTrainingStore()
    }

    func delete(_ template: TrainingTemplate) {
        removeFromMemory(template.id)
        persistCurrent()
        mirrorIntoTrainingStore()
    }

    // MARK: - Local load/save

    private func loadForCurrentAccount() {
        let key = storageKey(for: currentUID)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TrainingTemplate].self, from: data) {
            self.userTemplates = decoded
        } else {
            self.userTemplates = []
        }
        mirrorIntoTrainingStore()
    }

    private func persistCurrent() {
        let key = storageKey(for: currentUID)
        if let data = try? JSONEncoder().encode(userTemplates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - In-Memory Helpers

    private func insertOrReplaceInMemory(_ t: TrainingTemplate) {
        if let idx = userTemplates.firstIndex(where: { $0.id == t.id }) {
            userTemplates[idx] = t
        } else {
            userTemplates.append(t)
        }
    }

    private func removeFromMemory(_ id: String) {
        if let idx = userTemplates.firstIndex(where: { $0.id == id }) {
            userTemplates.remove(at: idx)
        }
    }

    // MARK: - Bridge zu TrainingStore
    /// Nur **User-Templates** (ohne Defaults) werden in TrainingStore gespiegelt.
    /// Der SyncService pusht später `training.templates`.
    private func mirrorIntoTrainingStore() {
        // setze Flag, damit der training.$templates-Sink nicht zurückfeuert
        isMirroringToTraining = true
        training.templates = userTemplates
        isMirroringToTraining = false
    }
}
