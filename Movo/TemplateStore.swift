import Foundation
import Combine
import FirebaseAuth
import SwiftUI

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

    private func pinnedKey(for uid: String?) -> String {
        let id = uid ?? guestOwnerId()
        return "templates.pinned.\(id).v1"
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
    
    // Pinned IDs (persisted locally)
    @Published private(set) var pinnedTemplateIds: Set<String> = []

    // MARK: - Init
    init(training: TrainingStore) {
        self.training = training

        // Eingebaute Defaults (erweitert)
        self.defaultTemplates = [
            TrainingTemplate(name: "Push", exercises: ["Bench press (Barbell)", "Incline Dumbbell Press", "Shoulder Press (Dumbbell)", "Lateral Raises (Dumbbell)", "Triceps Pushdown (Cable)", "Overhead Triceps Extension (Cable)"], ownerId: "builtin"),
            TrainingTemplate(name: "Pull", exercises: ["Lat Pulldown", "Seated Row (Cable)", "Hammer Curls (Dumbbells)", "Bicep Curls (Dumbbells)", "Face Pulls"], ownerId: "builtin"),
            TrainingTemplate(name: "Legs", exercises: ["Squats", "Leg Press", "Leg Extension", "Leg Curl", "Calf Raises"], ownerId: "builtin"),
            TrainingTemplate(name: "Upper Body", exercises: ["Bench Press (Barbell)", "Bent Over Row (Barbell)", "Overhead Press (Barbell)", "Pull Ups", "Skullcrushers"], ownerId: "builtin"),
            TrainingTemplate(name: "Lower Body", exercises: ["Deadlift (Barbell)", "Front Squat", "Lunges", "Hip Thrusts", "Standing Calf Raises"], ownerId: "builtin"),
            TrainingTemplate(name: "Full Body A", exercises: ["Squats", "Bench Press (Barbell)", "Bent Over Row (Barbell)", "Overhead Press (Barbell)", "Plank"], ownerId: "builtin"),
            TrainingTemplate(name: "Full Body B", exercises: ["Deadlift (Barbell)", "Incline Dumbbell Press", "Lat Pulldown", "Lateral Raises (Dumbbell)", "Hanging Leg Raises"], ownerId: "builtin"),
            TrainingTemplate(name: "Cardio & Core", exercises: ["Running (Treadmill)", "Bicycle Crunches", "Russian Twists", "Leg Raises", "Plank"], ownerId: "builtin"),
            TrainingTemplate(name: "Arms", exercises: ["Barbell Curl", "Triceps Pushdown (Cable)", "Hammer Curls", "Skullcrushers"], ownerId: "builtin")
        ]

        // Initial laden
        loadForCurrentAccount()

        // Auf Account-Wechsel reagieren
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            self?.loadForCurrentAccount()
        }

        // Mirroring from TrainingStore
        training.$templates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTemplates in
                guard let self = self else { return }
                if self.isMirroringToTraining { return }

                let shouldAdopt = (!newTemplates.isEmpty) || self.userTemplates.isEmpty

                if shouldAdopt, self.userTemplates != newTemplates {
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
    
    // Check if user can create more custom templates (max 3 without premium)
    func canCreateCustomTemplate(isPremium: Bool) -> Bool {
        if isPremium { return true }
        return userTemplates.count < 3
    }
    
    // Get remaining free template slots
    func remainingFreeTemplates(isPremium: Bool) -> Int {
        if isPremium { return Int.max }
        return max(0, 3 - userTemplates.count)
    }
    
    func isPinned(_ template: TrainingTemplate) -> Bool {
        pinnedTemplateIds.contains(template.id)
    }
    
    func togglePin(for template: TrainingTemplate) {
        if pinnedTemplateIds.contains(template.id) {
            pinnedTemplateIds.remove(template.id)
        } else {
            pinnedTemplateIds.insert(template.id)
        }
        persistPinned()
    }

    func add(_ template: TrainingTemplate) {
        var t = template
        t.ownerId = currentUID ?? guestOwnerId()
        t.updatedAt = Date()
        insertOrReplaceInMemory(t)
        persistCurrent()
        mirrorIntoTrainingStore()
        AnalyticsService.trackTemplateCreated(t, source: "template_store")
    }

    func update(_ template: TrainingTemplate) {
        var t = template
        t.ownerId = currentUID ?? guestOwnerId()
        t.updatedAt = Date()
        insertOrReplaceInMemory(t)
        persistCurrent()
        mirrorIntoTrainingStore()
    }

    func delete(_ template: TrainingTemplate) {
        AnalyticsService.trackTemplateDeleted(template)
        removeFromMemory(template.id)
        if pinnedTemplateIds.contains(template.id) {
             pinnedTemplateIds.remove(template.id)
             persistPinned()
        }
        persistCurrent()
        mirrorIntoTrainingStore()
    }
    
    func isDefault(_ template: TrainingTemplate) -> Bool {
        // Initiale Prüfung über ownerId oder Existenz in defaults
        return template.ownerId == "builtin" || defaultTemplates.contains(where: { $0.id == template.id })
    }

    // MARK: - Local load/save

    private func loadForCurrentAccount() {
        // Templates laden
        let key = storageKey(for: currentUID)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TrainingTemplate].self, from: data) {
            self.userTemplates = decoded
        } else {
            self.userTemplates = []
        }
        
        // Pinned IDs laden
        let pKey = pinnedKey(for: currentUID)
        if let pData = UserDefaults.standard.data(forKey: pKey),
           let pDecoded = try? JSONDecoder().decode(Set<String>.self, from: pData) {
            self.pinnedTemplateIds = pDecoded
        } else {
            self.pinnedTemplateIds = []
        }
        
        mirrorIntoTrainingStore()
    }

    private func persistCurrent() {
        let key = storageKey(for: currentUID)
        if let data = try? JSONEncoder().encode(userTemplates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func persistPinned() {
        let key = pinnedKey(for: currentUID)
        if let data = try? JSONEncoder().encode(pinnedTemplateIds) {
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
        isMirroringToTraining = true
        training.templates = userTemplates
        isMirroringToTraining = false
    }
}
