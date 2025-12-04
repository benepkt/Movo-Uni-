import Foundation
import Combine
import FirebaseCore
import FirebaseFirestore

@MainActor
final class SyncService: ObservableObject {
    // MARK: - Firestore
    private var db: Firestore {
        precondition(FirebaseApp.app() != nil, "Firebase ist noch nicht konfiguriert")
        return Firestore.firestore()
    }

    // MARK: - Cancellables
    private var authCancellable: AnyCancellable?
    private var syncCancellables = Set<AnyCancellable>()
    private var autoSyncCancellable: AnyCancellable?

    // MARK: - AutoSync Toggle
    #if DEBUG
    private var autoSyncEnabled = false
    #else
    private var autoSyncEnabled = true
    #endif

    // MARK: - Manual sync switch (persisted)
    private let kManualKey = "cloud.manualSyncOnly"
    private let lastManualKey = "cloud.lastManualSyncAt"

    public var isManualSyncOnly: Bool {
        UserDefaults.standard.bool(forKey: kManualKey) // default: false
    }

    /// Umschalten „Nur manuell synchronisieren“
    /// - Im Manual-Mode bleiben Read-Listener aktiv, Auto-Push wird gestoppt.
    public func setManualSync(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: kManualKey)
        if on {
            // Manual: AutoSync aus, Read-Listener an
            autoSyncCancellable?.cancel()
            autoSyncCancellable = nil
            resumeListeners()
            Task { await fetchProfileOnce() }
            print("[ManualSync] enabled → auto-push OFF, read listeners ON")
        } else {
            // Auto: Listener + AutoSync an
            resumeListeners()
            startAutoSync()
            Task { await fetchProfileOnce() }
            print("[ManualSync] disabled → auto-push ON, read listeners ON")
        }
    }

    // MARK: - Cloud gates
    private var hasCloudAccount: Bool { self.activeUid != nil && self.isGuestUser == false }
    private func canCloudRead()  -> Bool { hasCloudAccount }                                  // Lesen immer erlaubt
    private func canCloudWrite() -> Bool { hasCloudAccount && (self.isManualSyncOnly == false) } // Auto-Write nur ohne Manual
    private func canCloudReadManual()  -> Bool { hasCloudAccount }
    private func canCloudWriteManual() -> Bool { hasCloudAccount }

    // MARK: - Dependencies
    private let auth: AuthService
    private let training: TrainingStore
    private let challenges: ChallengeStore
    private let notes: GlobalExerciseNotesStore
    private let purchaseManager: PurchaseManager

    // MARK: - Listener
    private var trainingListener: ListenerRegistration?
    private var templateListener: ListenerRegistration?
    private var pulseListener: ListenerRegistration?
    private var entitlementsListener: ListenerRegistration?

    // MARK: - UI State
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var isSyncing: Bool = false

    // MARK: - Internal State
    private var isImporting = false
    private var activeUid: String?
    private var isGuestUser: Bool = true

    // MARK: - Snapshot Keys
    private let guestHistoryKey   = "guest.trainingHistory.v1"
    private let guestTemplatesKey = "guest.trainingTemplates.v1"
    private func historyKey(for uid: String?, isGuest: Bool) -> String {
        (isGuest || uid == nil) ? guestHistoryKey : "local.\(uid!).trainingHistory.v1"
    }
    private func templatesKey(for uid: String?, isGuest: Bool) -> String {
        (isGuest || uid == nil) ? guestTemplatesKey : "local.\(uid!).trainingTemplates.v1"
    }

    // MARK: - Device ID (for Pulse)
    private let deviceId: String = {
        let k = "sync.deviceId"
        if let v = UserDefaults.standard.string(forKey: k) { return v }
        let v = UUID().uuidString
        UserDefaults.standard.set(v, forKey: k)
        return v
    }()

    // MARK: - Outbox (vorbereitet)
    private actor Outbox {
        private var ids = Set<UUID>()
        func add(_ new: [UUID]) { ids.formUnion(new) }
        func drain(max n: Int) -> [UUID] {
            guard !ids.isEmpty else { return [] }
            let picked = Array(ids.prefix(n))
            ids.subtract(picked)
            return picked
        }
        var isEmpty: Bool { ids.isEmpty }
    }
    private let outbox = Outbox()

    // MARK: - UI Op Infrastruktur
    private enum SyncOpError: Error, LocalizedError {
        case timeout
        var errorDescription: String? { "Zeitüberschreitung (Timeout)." }
    }

    private actor UiOpLock {
        private var busy = false
        func lock() async {
            while busy { try? await Task.sleep(nanoseconds: 50_000_000) }
            busy = true
        }
        func unlock() { busy = false }
    }
    private let uiOpLock = UiOpLock()

    @discardableResult
    private func withTimeout<T>(_ seconds: Double = 20,
                                _ op: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw SyncOpError.timeout
            }
            guard let res = try await group.next() else { throw SyncOpError.timeout }
            group.cancelAll()
            return res
        }
    }

    private func pauseListeners() {
        self.trainingListener?.remove();     self.trainingListener = nil
        self.templateListener?.remove();     self.templateListener = nil
        self.pulseListener?.remove();        self.pulseListener = nil
        self.entitlementsListener?.remove(); self.entitlementsListener = nil
    }

    private func resumeListeners() {
        guard self.canCloudRead() else { return }
        self.startTrainingListener()
        self.startTemplateListener()
        self.startPulseListener()
        self.startEntitlementsListener()
    }

    // MARK: - Wrappers
    private func uiWrappedManual(_ label: String,
                                 _ work: @escaping () async throws -> Void) async {
        print("[uiWrappedManual] start \(label)")
        await self.uiOpLock.lock()
        defer { Task { await self.uiOpLock.unlock() } }

        // Manuell: Listener kurz pausieren, um Echo zu vermeiden
        self.pauseListeners()
        self.isImporting = true
        self.isSyncing = true
        defer {
            self.isImporting = false
            self.isSyncing = false
            self.resumeListeners()
            print("[uiWrappedManual] end \(label) ✅")
        }

        do {
            try await self.withTimeout(20) { try await work() }
            let now = Date()
            self.lastSyncAt = now
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastManualKey)
        } catch {
            print("[uiWrappedManual] \(label) ❌ error:", error.localizedDescription)
        }
    }

    private func uiWrappedBackground(_ label: String,
                                     _ work: @escaping () async throws -> Void) async {
        print("[uiWrappedBg] start \(label)")
        self.isImporting = true
        defer {
            self.isImporting = false
            print("[uiWrappedBg] end \(label) ✅")
        }
        do {
            try await self.withTimeout(20) { try await work() }
        } catch {
            print("[uiWrappedBg] \(label) ❌ error:", error.localizedDescription)
        }
    }

    // MARK: - Soft Firestore Reset
    private actor ResetGate {
        private var busy = false
        func enter() async {
            while busy { try? await Task.sleep(nanoseconds: 50_000_000) }
            busy = true
        }
        func leave() { busy = false }
    }
    private let resetGate = ResetGate()

    private func resetFirestorePersistence() async {
        await self.resetGate.enter()
        defer { Task { await self.resetGate.leave() } }

        self.pauseListeners()
        self.autoSyncCancellable?.cancel()
        self.autoSyncCancellable = nil

        let fs = Firestore.firestore()
        var settings = fs.settings
        settings.isPersistenceEnabled = true
        fs.settings = settings

        print("[SyncService] Firestore settings refreshed (soft reset).")
    }

    // MARK: - Init
    init(auth: AuthService,
         training: TrainingStore,
         challenges: ChallengeStore,
         notes: GlobalExerciseNotesStore,
         purchaseManager: PurchaseManager) {
        self.auth = auth
        self.training = training
        self.challenges = challenges
        self.notes = notes
        self.purchaseManager = purchaseManager

        // Manual-Sync standardmäßig aktivieren (nur beim allerersten Start)
        if UserDefaults.standard.object(forKey: kManualKey) == nil {
            UserDefaults.standard.set(true, forKey: kManualKey)
        }

        
        if let ts = UserDefaults.standard.object(forKey: lastManualKey) as? Double {
            self.lastSyncAt = Date(timeIntervalSince1970: ts)
        }

        self.authCancellable = auth.$user
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleAuthChange()
                }
            }
    }

    // MARK: - Firestore Paths & Pulse
    private func col(_ name: String) -> CollectionReference {
        guard let uid = self.activeUid else { preconditionFailure("col(\(name)) ohne aktiven User") }
        return self.db.collection("users").document(uid).collection(name)
    }
    private func doc(_ name: String) -> DocumentReference {
        guard let uid = self.activeUid else { preconditionFailure("doc(\(name)) ohne aktiven User") }
        return self.db.collection("users").document(uid).collection("state").document(name)
    }
    private func pulseRef() -> DocumentReference? {
        guard let uid = self.activeUid else { return nil }
        return self.db.collection("users").document(uid).collection("state").document("pulse")
    }
    private func bumpPulse() async throws {
        guard let ref = self.pulseRef() else { return }
        try await ref.setData([
            "updatedAt": FieldValue.serverTimestamp(),
            "by": self.deviceId
        ], merge: true)
    }

    // MARK: - Öffentliche Save-API (lokal als Standard)
    public func uiSaveTraining(_ entry: TrainingEntry) async {
        await self.uiWrappedBackground("saveTraining") {
            // Manual oder Gast → nur lokal
            guard self.canCloudWrite() else {
                await MainActor.run {
                    if let i = self.training.history.firstIndex(where: { $0.id == entry.id }) {
                        self.training.history[i] = entry
                    } else {
                        self.training.history.insert(entry, at: 0)
                    }
                }
                await self.saveLocalSnapshot()
                return
            }

            let ref = self.col("trainingHistory").document(entry.id.uuidString)
            let dto = TrainingEntryDTO(from: entry)
            try await ref.setData(dto.toDict(), merge: true)
            try await self.awaitPendingWrites()
            try await self.bumpPulse()

            await MainActor.run {
                if let idx = self.training.history.firstIndex(where: { $0.id == entry.id }) {
                    self.training.history[idx] = entry
                } else {
                    self.training.history.insert(entry, at: 0)
                }
            }
            await self.saveLocalSnapshot()
        }
    }

    // MARK: - Profile (Level / XP / Coins)
    public func saveProfile(level: Int, xp: Int, coins: Int) async {
        guard self.canCloudWrite() else { return }
        let ref = self.doc("profile")
        do {
            try await ref.setData([
                "level": level,
                "xp": xp,
                "coins": coins,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            try await self.awaitPendingWrites()
        } catch { print("[SyncService] saveProfile error:", error) }
    }

    // MARK: - Auth Change
    private func handleAuthChange() async {
        let rawUid = self.auth.user?.uid
        let rawIsGuest = self.auth.isGuest

        let isGuest = rawIsGuest || rawUid == nil
        let uid = isGuest ? nil : rawUid

        self.isGuestUser = isGuest
        self.activeUid = uid

        UserDefaults.standard.set(isGuest ? "guest" : (uid ?? "guest"),
                                  forKey: "active.uid")

        print("[AuthChange] start uid=\(uid ?? "nil") guest=\(self.isGuestUser)")

        self.pauseListeners()
        self.syncCancellables.removeAll(keepingCapacity: true)
        self.autoSyncCancellable?.cancel()
        self.autoSyncCancellable = nil

        // 🔹 Gast → nur lokale Guest-Snapshots laden
        if isGuest {
            await self.resetFirestorePersistence()
            await self.loadLocalSnapshot(for: nil, isGuest: true)

            UserDefaults.standard.removeObject(forKey: "profile.imageData")
            UserDefaults.standard.removeObject(forKey: "gm.level.cloud")
            UserDefaults.standard.removeObject(forKey: "gm.xp.cloud")
            UserDefaults.standard.removeObject(forKey: "gm.coins.cloud")

            await MainActor.run { self.purchaseManager.applyRemotePremium(false) }
            NotificationCenter.default.post(name: .gmResetForGuest, object: nil)

            self.wireHistoryPushes()
            self.wireTemplatePushes()

            print("[SyncService] Gastmodus aktiv – nur lokale Guest-Daten.")
            print("[AuthChange] end (guest)")
            return
        }

        // 🔹 Eingeloggt
        await self.resetFirestorePersistence()

        if self.isManualSyncOnly {
            if let uid = self.activeUid { await self.loadLoggedInLocalSnapshot(uid: uid) }

            // Read-Listener einschalten (ziehen automatisch)
            self.resumeListeners()

            // Initialer Pull (überschreibt nichts Neueres lokal)
            await self.uiWrappedBackground("initialPullMergeManual") {
                try await self.mergeHistory(allowManual: true)
                try? await self.pullTemplatesOnce(allowManual: true)
            }

            await self.fetchProfileOnce()
            self.wireHistoryPushes()
            self.wireTemplatePushes()

            print("[AuthChange] manualSyncOnly=true → read listeners ON, auto-push OFF")
            return
        }

        // Auto-Modus (Cloud erlaubt) – HINTERGRUND
        await self.uiWrappedBackground("initialPullReplace") {
            try await self.mergeHistory(allowManual: false)
            try? await self.pullTemplatesOnce(allowManual: false)
        }
        await self.fetchProfileOnce()
        self.bootstrapFor()
        self.startAutoSync()
        print("[AuthChange] end uid=\(self.activeUid ?? "nil") guest=\(self.isGuestUser)")
    }

    // MARK: - One-shot Pull: Templates
    private func pullTemplatesOnce(allowManual: Bool) async throws {
        guard allowManual ? self.canCloudReadManual() : self.canCloudRead() else { return }
        let snap = try await self.col("templates").getDocuments()
        let remote: [TrainingTemplateDTO] = snap.documents.compactMap { try? TrainingTemplateDTO.fromSnapshot($0) }
        let mapped: [TrainingTemplate] = remote.map {
            TrainingTemplate(id: $0.templateId, name: $0.name, exercises: $0.exercises, ownerId: self.activeUid ?? "", updatedAt: $0.updatedAt)
        }
        print("[pullTemplatesOnce] fetched \(mapped.count) templates")
        await MainActor.run {
            self.training.templates = mapped
        }
        await self.saveLocalSnapshot()
    }

    // MARK: - Bootstrap (Auto/Pull)
    private func bootstrapFor() {
        guard self.canCloudRead() else { return }
        self.startTrainingListener()
        self.startTemplateListener()
        self.startPulseListener()
        self.startEntitlementsListener()
        self.wireHistoryPushes()
        self.wireTemplatePushes()
        Task { [weak self] in await self?.migrateIfNeeded() }
    }

    // MARK: - Entitlements Listener
    private func startEntitlementsListener() {
        guard self.canCloudRead() else { return }
        self.entitlementsListener?.remove()
        self.entitlementsListener = self.doc("entitlements")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self else { return }
                let isPro = (snap?.data()?["pro"] as? Bool) ?? false
                Task { @MainActor in self.purchaseManager.applyRemotePremium(isPro) }
            }
    }

    // MARK: - Pulse Listener
    private func startPulseListener() {
        guard self.canCloudRead() else { return }
        self.pulseListener?.remove()
        self.pulseListener = self.pulseRef()?
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snap, error in
                guard let self = self else { return }
                if let error { print("pulseListener error:", error); return }
                guard let snap = snap else { return }
                if let by = snap.data()?["by"] as? String, by == self.deviceId { return }
                Task { await self.uiWrappedBackground("pulsePull") { try await self.mergeHistory(allowManual: false) } }
            }
    }

    // MARK: - Remote Listeners (ziehen immer, solange Account vorhanden)
    private func startTrainingListener() {
        guard self.canCloudRead() else { return }
        self.trainingListener = self.col("trainingHistory")
            .order(by: "updatedAt", descending: false)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error { print("trainingListener error:", error); return }
                guard let snapshot = snapshot else { return }

                // ⛔️ Während Import/OPs ignorieren
                guard self.isImporting == false else { return }

                let remoteDTOs: [TrainingEntryDTO] = snapshot.documents.compactMap { try? TrainingEntryDTO.fromSnapshot($0) }
                var remoteMap: [UUID: TrainingEntry] = [:]
                remoteMap.reserveCapacity(remoteDTOs.count)
                for dto in remoteDTOs {
                    if let id = UUID(uuidString: dto.entryId) { remoteMap[id] = TrainingEntry.fromRemote(dto) }
                }

                let local = self.training.history
                var merged: [TrainingEntry] = []
                let allIds = Set(local.map(\.id)).union(remoteMap.keys)
                for id in allIds {
                    let l = local.first(where: { $0.id == id })
                    let r = remoteMap[id]
                    switch (l, r) {
                    case (nil, let r?): merged.append(r)
                    case (let l?, nil): merged.append(l)
                    case (let l?, let r?): merged.append(r.updatedAtForSync >= l.updatedAtForSync ? r : l)
                    default: break
                    }
                }

                Task { @MainActor in self.training.history = merged.sorted { $0.date > $1.date } }
                Task { await self.saveLocalSnapshot() }
            }
    }

    private func startTemplateListener() {
        guard self.canCloudRead() else { return }
        self.templateListener = self.col("templates")
            .order(by: "updatedAt", descending: false)
            .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error { print("templateListener error:", error); return }
                guard let snapshot = snapshot else { return }

                let remoteDTOs: [TrainingTemplateDTO] = snapshot.documents.compactMap { try? TrainingTemplateDTO.fromSnapshot($0) }
                var remoteMap: [String: TrainingTemplate] = [:]
                for dto in remoteDTOs {
                    remoteMap[dto.templateId] = TrainingTemplate(
                        id: dto.templateId,
                        name: dto.name,
                        exercises: dto.exercises,
                        ownerId: self.activeUid ?? "",
                        updatedAt: dto.updatedAt
                    )
                }

                // MERGE: remote > local bei Konflikt, aber **stabile Sortierung** unten!
                let local = self.training.templates
                var mergedMap: [String: TrainingTemplate] = remoteMap
                for l in local {
                    if let r = remoteMap[l.id] {
                        mergedMap[l.id] = (r.updatedAt >= l.updatedAt) ? r : l
                    } else {
                        mergedMap[l.id] = l
                    }
                }

                // 🔒 STABILE SORTIERUNG: nach Name (case-insensitiv), dann ID
                let merged = Array(mergedMap.values)
                    .sorted { (a, b) in
                        let na = a.name.lowercased()
                        let nb = b.name.lowercased()
                        return na == nb ? (a.id < b.id) : (na < nb)
                    }

                Task { @MainActor in self.training.templates = merged }
                Task { await self.saveLocalSnapshot() }
            }
    }
    
    // Oben in der Klasse:
    private var lastTemplatesSig: Int = 0
    private func templatesSignature(_ list: [TrainingTemplate]) -> Int {
        var h = Hasher()
        for t in list.sorted(by: { $0.id < $1.id }) {
            h.combine(t.id)
            h.combine(t.name)
            h.combine(t.exercises.count)
            for e in t.exercises.prefix(20) { h.combine(e) }
            // KEIN updatedAt berücksichtigen!
        }
        return h.finalize()
    }

    private func autoSyncOnce() async {
        guard self.canCloudWrite() else { return }
        let sig = await MainActor.run { self.templatesSignature(self.training.templates) }
        guard sig != lastTemplatesSig else {
            // nichts Neues → nichts pushen → kein Resort
            return
        }
        await self.uiWrappedBackground("autoSync") {
            try await self.pushTemplates(allowDuringImport: true)
            self.lastTemplatesSig = sig
        }
    }



    // MARK: - Diff / Push + Local Autosave
    private var lastHistorySig: [UUID: Int] = [:]
    private func signature(for e: TrainingEntry) -> Int {
        var hasher = Hasher()
        hasher.combine(e.id)
        hasher.combine(e.date.timeIntervalSince1970)
        hasher.combine(e.title)
        hasher.combine(e.duration)
        hasher.combine(e.totalWeight)
        hasher.combine(e.emoji ?? "")
        hasher.combine(e.exercises.count)
        for ex in e.exercises.prefix(8) {
            hasher.combine(ex.name)
            hasher.combine(ex.sets.count)
        }
        return hasher.finalize()
    }

    private func wireHistoryPushes() {
        training.$history
            .debounce(for: RunLoop.SchedulerTimeType.Stride.milliseconds(250), scheduler: RunLoop.main)
            .sink(receiveValue: { [weak self] _ in
                guard let self = self, self.isImporting == false else { return }
                Task { await self.saveLocalSnapshot() }
            })
            .store(in: &self.syncCancellables)
    }

    /// 🔥 WICHTIG: Nach jeder lokalen Template-Änderung **sofort** in die Cloud pushen.
    /// Auch im Manual-Mode (weil Löschen „immer möglich“ sein soll).
    private func wireTemplatePushes() {
        training.$templates
            .removeDuplicates()
            .debounce(for: RunLoop.SchedulerTimeType.Stride.milliseconds(250), scheduler: RunLoop.main)
            .sink(receiveValue: { [weak self] _ in
                guard let self = self, self.isImporting == false else { return }
                Task {
                    await self.saveLocalSnapshot()
                    // ⛔️ Kein Autopush im Manual-Mode!
                    guard self.hasCloudAccount, self.isManualSyncOnly == false else { return }
                    try? await self.pushTemplates(allowDuringImport: true)
                }
            })
            .store(in: &self.syncCancellables)
    }


    // MARK: - Bulk Push (inkl. Diff+Delete)
    @discardableResult
    fileprivate func pushHistory(allowDuringImport: Bool = false) async throws {
        guard self.hasCloudAccount, (allowDuringImport || self.isImporting == false) else { return }
        let batch = self.db.batch()
        let list = self.training.history
        for e in list {
            let dto = TrainingEntryDTO(from: e)
            let ref = self.col("trainingHistory").document(e.id.uuidString)
            batch.setData(dto.toDict(), forDocument: ref, merge: true)
        }
        try await batch.commit()
    }

    /// Upsert **und** Delete: Remote-Dokumente, die lokal nicht mehr existieren, werden gelöscht.
    @discardableResult
    fileprivate func pushTemplates(allowDuringImport: Bool = false) async throws {
        guard self.hasCloudAccount, (allowDuringImport || self.isImporting == false) else { return }
        let batch = self.db.batch()
        for t in self.training.templates {
            // DTO ohne clientseitiges updatedAt
            var dict = TrainingTemplateDTO(from: t, updatedAt: t.updatedAt).toDict()
            // überschreibe updatedAt mit serverTimestamp, damit es **einheitlich** ist
            dict["updatedAt"] = FieldValue.serverTimestamp()
            let ref = self.col("templates").document(t.id)
            batch.setData(dict, forDocument: ref, merge: true)
        }
        try await batch.commit()
    }

    // MARK: - Merge (Remote + Local)
    private func mergeHistory(allowManual: Bool) async throws {
        guard allowManual ? self.canCloudReadManual() : self.canCloudRead() else { return }
        let remoteSnap = try await self.col("trainingHistory").getDocuments()
        let remoteDTOs = remoteSnap.documents.compactMap { try? TrainingEntryDTO.fromSnapshot($0) }
        let remoteMap: [UUID: TrainingEntry] = Dictionary(uniqueKeysWithValues:
            remoteDTOs.compactMap { dto in
                guard let id = UUID(uuidString: dto.entryId) else { return nil }
                return (id, TrainingEntry.fromRemote(dto))
            }
        )

        let local = await MainActor.run { self.training.history }
        var merged: [TrainingEntry] = []
        let allIds = Set(local.map(\.id)).union(remoteMap.keys)

        for id in allIds {
            let l = local.first(where: { $0.id == id })
            let r = remoteMap[id]
            switch (l, r) {
            case (nil, let r?): merged.append(r)
            case (let l?, nil): merged.append(l) // lokale-only behalten
            case (let l?, let r?):
                merged.append(r.updatedAtForSync >= l.updatedAtForSync ? r : l)
            default: break
            }
        }

        await MainActor.run { self.training.history = merged.sorted { $0.date > $1.date } }
        await self.saveLocalSnapshot()
    }

    // MARK: - Local Snapshots
    private func loadLocalSnapshot(for uid: String?, isGuest: Bool) async {
        let hKey = self.historyKey(for: uid, isGuest: isGuest)
        let tKey = self.templatesKey(for: uid, isGuest: isGuest)

        // History
        if let data = UserDefaults.standard.data(forKey: hKey),
           let dtos = try? JSONDecoder().decode([TrainingEntryDTO].self, from: data) {
            let items = dtos.map { TrainingEntry.fromRemote($0) }.sorted { $0.date > $1.date }
            await MainActor.run { self.training.history = items }
        } else {
            await MainActor.run { self.training.history = [] }
        }

        // Templates
        if let data = UserDefaults.standard.data(forKey: tKey),
           let dtos = try? JSONDecoder().decode([TrainingTemplateDTO].self, from: data) {
            let items: [TrainingTemplate] = dtos.map {
                TrainingTemplate(id: $0.templateId, name: $0.name, exercises: $0.exercises, ownerId: isGuest ? "guest" : (uid ?? ""), updatedAt: $0.updatedAt)
            }
            await MainActor.run { self.training.templates = items }
        } else {
            await MainActor.run { self.training.templates = [] }
        }
    }

    private func saveLocalSnapshot() async {
        let uid = self.activeUid
        let isGuest = self.isGuestUser

        let hKey = self.historyKey(for: uid, isGuest: isGuest)
        let tKey = self.templatesKey(for: uid, isGuest: isGuest)

        // History
        let hist = await MainActor.run { self.training.history }
        let histDTO = hist.map { TrainingEntryDTO(from: $0) }
        if let data = try? JSONEncoder().encode(histDTO) {
            UserDefaults.standard.set(data, forKey: hKey)
        }

        // Templates
        let tpls = await MainActor.run { self.training.templates }
        let tplsDTO = tpls.map { TrainingTemplateDTO(from: $0, updatedAt: Date()) }
        if let data = try? JSONEncoder().encode(tplsDTO) {
            UserDefaults.standard.set(data, forKey: tKey)
        }
    }

    private func localHistoryKeyForUser(_ uid: String) -> String { "local.\(uid).trainingHistory.v1" }
    private func localTemplatesKeyForUser(_ uid: String) -> String { "local.\(uid).trainingTemplates.v1" }
    private func loadLoggedInLocalSnapshot(uid: String) async { await self.loadLocalSnapshot(for: uid, isGuest: false) }
    private func saveLoggedInLocalSnapshot() async { await self.saveLocalSnapshot() }

    // MARK: - Migration (Legacy)
    fileprivate func migrateIfNeeded() async {
        // Im Manual-Mode niemals schreiben
        guard self.canCloudRead(), self.canCloudWrite(), let uid = self.activeUid else { return }

        let base = self.db.collection("users").document(uid)
        var didWrite = false

        do {
            let hist = try await base.collection("trainingHistory").limit(to: 1).getDocuments()
            if hist.isEmpty {
                try await self.pushHistory(allowDuringImport: true); didWrite = true
            }
        } catch { print("migrateIfNeeded history check error:", error) }

        do {
            let tpl = try await base.collection("templates").limit(to: 1).getDocuments()
            if tpl.isEmpty {
                try await self.pushTemplates(allowDuringImport: true); didWrite = true
            }
        } catch { print("migrateIfNeeded templates check error:", error) }

        if didWrite { try? await self.bumpPulse() }
    }


    // MARK: - Delete Training
    public func uiDeleteTraining(id: UUID) async {
        // Wenn Cloud-Account vorhanden: immer auch remote löschen,
        // damit der Listener es nicht wieder reinzieht (auch im Manual-Mode).
        guard self.hasCloudAccount else {
            await MainActor.run {
                if let idx = self.training.history.firstIndex(where: { $0.id == id }) {
                    self.training.history.remove(at: idx)
                }
            }
            await self.saveLocalSnapshot()
            return
        }

        await self.uiWrappedBackground("deleteTraining") {
            // Während des UI-ops ist isImporting=true -> Listener ignoriert (s. Patch B)
            try? await self.col("trainingHistory").document(id.uuidString).delete()
            try? await self.awaitPendingWrites()
            try? await self.bumpPulse()

            await MainActor.run {
                if let idx = self.training.history.firstIndex(where: { $0.id == id }) {
                    self.training.history.remove(at: idx)
                }
            }
            await self.saveLocalSnapshot()
        }
    }

    // MARK: - Helper
    private func awaitPendingWrites() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.db.waitForPendingWrites { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }
    private func withBackoff<T>(_ op: @escaping () async throws -> T) async throws -> T {
        var delay: UInt64 = 200_000_000
        for _ in 0..<5 {
            do { return try await op() }
            catch {
                let msg = String(describing: error).lowercased()
                if msg.contains("resource exhausted") || msg.contains("quota") {
                    try? await Task.sleep(nanoseconds: delay)
                    delay = min(delay * 2, 3_000_000_000)
                    continue
                }
                throw error
            }
        }
        return try await op()
    }
}

// MARK: - Auto Sync (nur wenn manual==false)
extension SyncService {
    
    public func startAutoSync() {
        // ⛔️ Im Manual-Mode gar nicht erst starten
        guard self.canCloudRead(), self.isManualSyncOnly == false else {
            self.autoSyncCancellable?.cancel()
            self.autoSyncCancellable = nil
            return
        }
        guard self.autoSyncEnabled else {
            print("[AutoSync] disabled (debug)")
            self.autoSyncCancellable?.cancel()
            self.autoSyncCancellable = nil
            return
        }
        if self.autoSyncCancellable != nil { return }

        Task { await self.autoSyncOnce() }
        self.autoSyncCancellable = Timer.publish(every: 120, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { await self.autoSyncOnce() }
            }
    }


}
// MARK: - Manual Hooks (Nutzer-Aktionen)
extension SyncService {
    public func uiManualPullMerge() async {
        guard self.canCloudReadManual() else { return }
        await self.uiWrappedManual("manualPullMerge") {
            try await self.mergeHistory(allowManual: true)
            try await self.pullTemplatesOnce(allowManual: true)
        }
    }

    public func uiPushAll() async {
        guard self.canCloudWriteManual() else { return }
        await self.uiWrappedManual("manualCloudPush") {
            try await self.pushHistory(allowDuringImport: true)
            try await self.pushTemplates(allowDuringImport: true)
            try await self.bumpPulse()
        }
    }

    public func uiManualPushToCloud() async { await self.uiPushAll() }

    public func uiPullReplaceLocal() async {
        guard self.canCloudReadManual(), let uid = self.activeUid else { return }
        await self.uiWrappedManual("pullReplace") {
            let base = self.db.collection("users").document(uid)

            if let snap = try? await base.collection("trainingHistory").getDocuments() {
                let remote = snap.documents.compactMap { try? TrainingEntryDTO.fromSnapshot($0) }
                await MainActor.run {
                    self.training.history = remote.map { TrainingEntry.fromRemote($0) }.sorted { $0.date > $1.date }
                }
            }

            if let snap = try? await base.collection("templates").getDocuments() {
                let remote = snap.documents.compactMap { try? TrainingTemplateDTO.fromSnapshot($0) }
                let mapped: [TrainingTemplate] = remote.map {
                    TrainingTemplate(id: $0.templateId, name: $0.name, exercises: $0.exercises, ownerId: self.activeUid ?? "", updatedAt: $0.updatedAt)
                }
                await MainActor.run { self.training.templates = mapped }
            }
            await self.saveLocalSnapshot()
        }
    }

    public func uiMigrateIfNeeded() async {
        guard self.canCloudRead() else { return }
        await self.uiWrappedBackground("migrate") { try await self.migrateIfNeeded() }
    }

    @MainActor
    public func flushHistoryNow() async {
        guard self.canCloudWriteManual() else { return }
        await self.uiWrappedManual("flushHistoryNow") {
            try await self.pushHistory(allowDuringImport: true)
            try await self.awaitPendingWrites()
            try await self.bumpPulse()
        }
    }
}

// MARK: - Profile (Bild & Level)
extension SyncService {
    public func uiSaveProfileImage(_ data: Data) async {
        guard self.canCloudWrite() else { return }
        let b64 = data.base64EncodedString()
        let ref = self.doc("profile")
        do {
            try await ref.setData([
                "imageB64": b64,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            try await self.awaitPendingWrites()
        } catch { print("[SyncService] uiSaveProfileImage error:", error) }
    }

    public func saveLevel(level: Int, xp: Int) async {
        guard self.canCloudWrite() else { return }
        let ref = self.doc("profile")
        do {
            try await ref.setData([
                "level": level,
                "xp": xp,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            try await self.awaitPendingWrites()
        } catch { print("[SyncService] saveLevel error:", error) }
    }

    internal func fetchProfileOnce() async {
        guard self.canCloudRead() else { return }
        do {
            let snap = try await self.doc("profile").getDocument()
            guard let data = snap.data() else { return }

            if let b64 = data["imageB64"] as? String, let decoded = Data(base64Encoded: b64) {
                UserDefaults.standard.set(decoded, forKey: "profile.imageData")
            }
            if let n = data["level"] as? NSNumber {
                UserDefaults.standard.set(n.intValue, forKey: "gm.level.cloud")
            }
            if let n = data["xp"] as? NSNumber {
                UserDefaults.standard.set(n.intValue, forKey: "gm.xp.cloud")
            }
            if let n = data["coins"] as? NSNumber {
                UserDefaults.standard.set(n.intValue, forKey: "gm.coins.cloud")
            }
        } catch { print("[SyncService] fetchProfileOnce error:", error) }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let gmResetForGuest = Notification.Name("gmResetForGuest")
}

// MARK: - Visibility API
extension SyncService {
    @MainActor
    public func getVisibility(for entryId: UUID,
                              startedAt: Date) async -> String? {
        guard self.canCloudRead(), let uid = self.activeUid else { return nil }
        let trainings = Firestore.firestore().collection("trainings")
        do {
            let deterministic = trainings.document(entryId.uuidString)
            if let snap = try? await deterministic.getDocument(), snap.exists {
                return (snap.data()?["visibility"] as? String) ?? "public"
            }
            let snap = try await trainings
                .whereField("userId", isEqualTo: uid)
                .whereField("startedAt", isEqualTo: Timestamp(date: startedAt))
                .limit(to: 1)
                .getDocuments()
            if let doc = snap.documents.first {
                try? await trainings.document(doc.documentID).setData([
                    "trainingEntryId": entryId.uuidString
                ], merge: true)
                return (doc.data()["visibility"] as? String) ?? "public"
            }
        } catch { print("[SyncService] getVisibility error:", error.localizedDescription) }
        return nil
    }

    @MainActor
    public func setVisibility(for entryId: UUID,
                              startedAt: Date,
                              to newValue: String) async throws {
        guard self.canCloudWrite(), let uid = self.activeUid else { return }
        let trainings = Firestore.firestore().collection("trainings")

        let deterministic = trainings.document(entryId.uuidString)
        if let snap = try? await deterministic.getDocument(), snap.exists {
            try await deterministic.setData([
                "visibility": newValue,
                "trainingEntryId": entryId.uuidString
            ], merge: true)
            try await self.awaitPendingWrites()
            return
        }

        let snap = try await trainings
            .whereField("userId", isEqualTo: uid)
            .whereField("startedAt", isEqualTo: Timestamp(date: startedAt))
            .limit(to: 1)
            .getDocuments()

        if let doc = snap.documents.first {
            try await trainings.document(doc.documentID).setData([
                "visibility": newValue,
                "trainingEntryId": entryId.uuidString
            ], merge: true)
            try await self.awaitPendingWrites()
            return
        }

        try await trainings.document(entryId.uuidString).setData([
            "userId": uid,
            "userDisplayName": "",
            "type": "Training",
            "durationMin": max(1, 0),
            "startedAt": Timestamp(date: startedAt),
            "createdAt": FieldValue.serverTimestamp(),
            "visibility": newValue,
            "trainingEntryId": entryId.uuidString
        ], merge: true)
        try await self.awaitPendingWrites()
    }
}

// MARK: - Social feed (nur Auto-Modus)
extension SyncService {
    public func tryPublishSocialDoc(_ entry: TrainingEntry, visibility: String) async {
        guard self.canCloudWrite(), let uid = self.activeUid else { return }
        let name = self.auth.user?.displayName ?? ""
        let mins = max(1, Int(entry.duration / 60))
        let data: [String: Any] = [
            "userId": uid,
            "userDisplayName": name,
            "type": entry.title,
            "durationMin": mins,
            "startedAt": Timestamp(date: entry.date),
            "createdAt": FieldValue.serverTimestamp(),
            "visibility": visibility,
            "trainingEntryId": entry.id.uuidString
        ]
        do {
            try await Firestore.firestore().collection("trainings").document(entry.id.uuidString).setData(data, merge: true)
            try await self.awaitPendingWrites()
            print("[SOCIAL] ✅ published (\(visibility))")
        } catch {
            print("[SOCIAL] ❌ publish error:", error.localizedDescription)
        }
    }
}

// MARK: - Delete Template (immer möglich)
extension SyncService {
    public func uiDeleteTemplate(id: String) async {
        // Wenn kein Cloud-Account (Gast) oder Manual-Mode: lokal reicht
        guard self.hasCloudAccount else {
            await MainActor.run {
                if let idx = self.training.templates.firstIndex(where: { $0.id == id }) {
                    self.training.templates.remove(at: idx)
                }
            }
            await self.saveLocalSnapshot()
            return
        }

        // Mit Account: remote löschen, danach lokal aufräumen + Snapshot
        await self.uiWrappedBackground("deleteTemplate") {
            try? await self.col("templates").document(id).delete()
            try? await self.awaitPendingWrites()
            try? await self.bumpPulse()

            await MainActor.run {
                if let idx = self.training.templates.firstIndex(where: { $0.id == id }) {
                    self.training.templates.remove(at: idx)
                }
            }
            await self.saveLocalSnapshot()
        }
    }
}
