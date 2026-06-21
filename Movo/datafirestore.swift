// =====================================================
// QR View + DTOs etc. (dein unveränderter Code unten falls benötigt)
// =====================================================

import Foundation
import FirebaseFirestore

// MARK: - Firestore <-> Swift Date Conversion
enum FSConv {
    static func ts(_ date: Date) -> Timestamp { Timestamp(date: date) }
    static func date(_ raw: Any?) -> Date {
        if let t = raw as? Timestamp { return t.dateValue() }
        if let d = raw as? Date { return d }
        if let s = raw as? String, let d = ISO8601DateFormatter().date(from: s) { return d }
        if let secs = raw as? Double { return Date(timeIntervalSince1970: secs) }
        if let secs = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(secs)) }
        return .distantPast
    }
}

// MARK: - DTOs

// Training Entry DTO
struct TrainingEntryDTO: Identifiable, Codable {
    var docId: String?
    var entryId: String
    var date: Date
    var title: String
    var exercises: [ExerciseDTO]
    var duration: TimeInterval
    var totalWeight: Double
    var emoji: String?
    var updatedAt: Date
    var id: String { entryId }
    var cardioType: String?      // "Outdoor Walk", "Outdoor Run", ...
    var distanceKm: Double?
    var activeCalories: Double?
    var averageHeartRate: Double?
    var elevationGainM: Double?
    var perceivedEffort: Int?
    var activityNote: String?
    var healthSourceName: String?
    var healthDeviceName: String?
    var healthWorkoutActivityRaw: UInt?
    var isIndoorWorkout: Bool?
    var activities: [WorkoutActivityBlockDTO]


    // optional route polyline
    var routePolyline: String?

    init(
        docId: String?,
        entryId: String,
        date: Date,
        title: String,
        exercises: [ExerciseDTO],
        duration: TimeInterval,
        totalWeight: Double,
        emoji: String?,
        updatedAt: Date,
        routePolyline: String? = nil, // optional param
        cardioType: String? = nil,
        distanceKm: Double? = nil,
        activeCalories: Double? = nil,
        averageHeartRate: Double? = nil,
        elevationGainM: Double? = nil,
        perceivedEffort: Int? = nil,
        activityNote: String? = nil,
        healthSourceName: String? = nil,
        healthDeviceName: String? = nil,
        healthWorkoutActivityRaw: UInt? = nil,
        isIndoorWorkout: Bool? = nil,
        activities: [WorkoutActivityBlockDTO] = []

    ) {
        self.docId = docId
        self.entryId = entryId
        self.date = date
        self.title = title
        self.exercises = exercises
        self.duration = duration
        self.totalWeight = totalWeight
        self.emoji = emoji
        self.updatedAt = updatedAt
        self.routePolyline = routePolyline
        self.cardioType = cardioType
        self.distanceKm = distanceKm
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.elevationGainM = elevationGainM
        self.perceivedEffort = perceivedEffort
        self.activityNote = activityNote
        self.healthSourceName = healthSourceName
        self.healthDeviceName = healthDeviceName
        self.healthWorkoutActivityRaw = healthWorkoutActivityRaw
        self.isIndoorWorkout = isIndoorWorkout
        self.activities = activities

    }

    // Converts TrainingEntry to DTO
    init(from e: TrainingEntry) {
        self.init(
            docId: nil,
            entryId: e.id.uuidString,
            date: e.date,
            title: e.title,
            exercises: e.exercises.map(ExerciseDTO.init),
            duration: e.duration,
            totalWeight: e.totalWeight,
            emoji: e.emoji,
            updatedAt: e.updatedAt,
            routePolyline: e.routePolyline,
            cardioType: e.cardioType,
            distanceKm: e.loggedDistanceKm,
            activeCalories: e.activeCalories,
            averageHeartRate: e.averageHeartRate,
            elevationGainM: e.elevationGainM,
            perceivedEffort: e.perceivedEffort,
            activityNote: e.activityNote,
            healthSourceName: e.healthSourceName,
            healthDeviceName: e.healthDeviceName,
            healthWorkoutActivityRaw: e.healthWorkoutActivityRaw,
            isIndoorWorkout: e.isIndoorWorkout,
            activities: e.activities.map(WorkoutActivityBlockDTO.init)

        )
    }
    static func fromSnapshot(_ doc: DocumentSnapshot) throws -> TrainingEntryDTO {
            guard let data = doc.data() else { throw NSError(domain: "decode.trainingEntry", code: 0) }
            return TrainingEntryDTO(
                docId: doc.documentID,
                entryId: data["entryId"] as? String ?? doc.documentID,
                date: FSConv.date(data["date"]),
                title: data["title"] as? String ?? "",
                exercises: (data["exercises"] as? [[String: Any]] ?? []).map(ExerciseDTO.fromDict),
                duration: data["duration"] as? TimeInterval ?? 0,
                totalWeight: data["totalWeight"] as? Double ?? 0,
                emoji: data["emoji"] as? String,
                updatedAt: FSConv.date(data["updatedAt"]),
                routePolyline: data["routePolyline"] as? String,
                cardioType: data["cardioType"] as? String,
                distanceKm: data["distanceKm"] as? Double,
                activeCalories: data["activeCalories"] as? Double,
                averageHeartRate: data["averageHeartRate"] as? Double,
                elevationGainM: data["elevationGainM"] as? Double,
                perceivedEffort: data["perceivedEffort"] as? Int,
                activityNote: data["activityNote"] as? String,
                healthSourceName: data["healthSourceName"] as? String,
                healthDeviceName: data["healthDeviceName"] as? String,
                healthWorkoutActivityRaw: (data["healthWorkoutActivityRaw"] as? UInt) ?? (data["healthWorkoutActivityRaw"] as? NSNumber)?.uintValue,
                isIndoorWorkout: data["isIndoorWorkout"] as? Bool,
                activities: (data["activities"] as? [[String: Any]] ?? []).map(WorkoutActivityBlockDTO.fromDict)
            )
        }

        func toDict() -> [String: Any] {
            var dict: [String: Any] = [
                "entryId": entryId,
                "date": FSConv.ts(date),
                "title": title,
                "exercises": exercises.map { $0.toDict() },
                "duration": duration,
                "totalWeight": totalWeight,
                "emoji": emoji as Any,
                "updatedAt": FieldValue.serverTimestamp()
            ]

            if let routePolyline {
                dict["routePolyline"] = routePolyline
            }
            if let cardioType {
                dict["cardioType"] = cardioType
            }
            if let distanceKm { dict["distanceKm"] = distanceKm }
            if let activeCalories { dict["activeCalories"] = activeCalories }
            if let averageHeartRate { dict["averageHeartRate"] = averageHeartRate }
            if let elevationGainM { dict["elevationGainM"] = elevationGainM }
            if let perceivedEffort { dict["perceivedEffort"] = perceivedEffort }
            if let activityNote, !activityNote.isEmpty { dict["activityNote"] = activityNote }
            if let healthSourceName, !healthSourceName.isEmpty { dict["healthSourceName"] = healthSourceName }
            if let healthDeviceName, !healthDeviceName.isEmpty { dict["healthDeviceName"] = healthDeviceName }
            if let healthWorkoutActivityRaw { dict["healthWorkoutActivityRaw"] = healthWorkoutActivityRaw }
            if let isIndoorWorkout { dict["isIndoorWorkout"] = isIndoorWorkout }
            if !activities.isEmpty { dict["activities"] = activities.map { $0.toDict() } }
            return dict
        }
    }

struct WorkoutActivityBlockDTO: Codable {
    var id: String
    var title: String
    var kindRaw: String?
    var emoji: String?
    var duration: TimeInterval
    var distanceKm: Double?
    var resistanceLevel: Double?
    var inclinePercent: Double?
    var averageWatts: Double?
    var activeCalories: Double?
    var averageHeartRate: Double?
    var elevationGainM: Double?
    var perceivedEffort: Int?
    var note: String?

    init(from block: WorkoutActivityBlock) {
        self.id = block.id.uuidString
        self.title = block.title
        self.kindRaw = block.kindRaw
        self.emoji = block.emoji
        self.duration = block.duration
        self.distanceKm = block.distanceKm
        self.resistanceLevel = block.resistanceLevel
        self.inclinePercent = block.inclinePercent
        self.averageWatts = block.averageWatts
        self.activeCalories = block.activeCalories
        self.averageHeartRate = block.averageHeartRate
        self.elevationGainM = block.elevationGainM
        self.perceivedEffort = block.perceivedEffort
        self.note = block.note
    }

    static func fromDict(_ d: [String: Any]) -> WorkoutActivityBlockDTO {
        WorkoutActivityBlockDTO(
            id: d["id"] as? String ?? UUID().uuidString,
            title: d["title"] as? String ?? "",
            kindRaw: d["kindRaw"] as? String,
            emoji: d["emoji"] as? String,
            duration: d["duration"] as? TimeInterval ?? 0,
            distanceKm: d["distanceKm"] as? Double,
            resistanceLevel: d["resistanceLevel"] as? Double,
            inclinePercent: d["inclinePercent"] as? Double,
            averageWatts: d["averageWatts"] as? Double,
            activeCalories: d["activeCalories"] as? Double,
            averageHeartRate: d["averageHeartRate"] as? Double,
            elevationGainM: d["elevationGainM"] as? Double,
            perceivedEffort: d["perceivedEffort"] as? Int,
            note: d["note"] as? String
        )
    }

    init(
        id: String,
        title: String,
        kindRaw: String? = nil,
        emoji: String?,
        duration: TimeInterval,
        distanceKm: Double?,
        resistanceLevel: Double?,
        inclinePercent: Double?,
        averageWatts: Double?,
        activeCalories: Double?,
        averageHeartRate: Double?,
        elevationGainM: Double?,
        perceivedEffort: Int?,
        note: String?
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kindRaw
        self.emoji = emoji
        self.duration = duration
        self.distanceKm = distanceKm
        self.resistanceLevel = resistanceLevel
        self.inclinePercent = inclinePercent
        self.averageWatts = averageWatts
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.elevationGainM = elevationGainM
        self.perceivedEffort = perceivedEffort
        self.note = note
    }

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "duration": duration
        ]
        if let kindRaw { dict["kindRaw"] = kindRaw }
        if let emoji { dict["emoji"] = emoji }
        if let distanceKm { dict["distanceKm"] = distanceKm }
        if let resistanceLevel { dict["resistanceLevel"] = resistanceLevel }
        if let inclinePercent { dict["inclinePercent"] = inclinePercent }
        if let averageWatts { dict["averageWatts"] = averageWatts }
        if let activeCalories { dict["activeCalories"] = activeCalories }
        if let averageHeartRate { dict["averageHeartRate"] = averageHeartRate }
        if let elevationGainM { dict["elevationGainM"] = elevationGainM }
        if let perceivedEffort { dict["perceivedEffort"] = perceivedEffort }
        if let note, !note.isEmpty { dict["note"] = note }
        return dict
    }

    func toModel() -> WorkoutActivityBlock {
        WorkoutActivityBlock(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            kindRaw: kindRaw,
            emoji: emoji,
            duration: duration,
            distanceKm: distanceKm,
            resistanceLevel: resistanceLevel,
            inclinePercent: inclinePercent,
            averageWatts: averageWatts,
            activeCalories: activeCalories,
            averageHeartRate: averageHeartRate,
            elevationGainM: elevationGainM,
            perceivedEffort: perceivedEffort,
            note: note
        )
    }
}


// Exercise DTO
struct ExerciseDTO: Codable {
    var name: String
    var sets: [ExerciseSetDTO]

    init(name: String, sets: [ExerciseSetDTO]) {
        self.name = name
        self.sets = sets
    }

    init(from e: Exercise) {
        self.name = e.name
        self.sets = e.sets.map { .init(weight: $0.weight, reps: $0.reps, isCompleted: $0.isCompleted) }
    }

    static func fromDict(_ d: [String: Any]) -> ExerciseDTO {
        ExerciseDTO(
            name: d["name"] as? String ?? "",
            sets: (d["sets"] as? [[String: Any]] ?? []).map(ExerciseSetDTO.fromDict)
        )
    }

    func toDict() -> [String: Any] {
        ["name": name, "sets": sets.map { $0.toDict() }]
    }
}

// ExerciseSet DTO
struct ExerciseSetDTO: Codable {
    var weight: String
    var reps: String
    var isCompleted: Bool

    init(weight: String, reps: String, isCompleted: Bool) {
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }

    static func fromDict(_ d: [String: Any]) -> ExerciseSetDTO {
        .init(
            weight: d["weight"] as? String ?? "",
            reps: d["reps"] as? String ?? "",
            isCompleted: d["isCompleted"] as? Bool ?? false
        )
    }

    func toDict() -> [String: Any] {
        ["weight": weight, "reps": reps, "isCompleted": isCompleted]
    }
}

// TrainingTemplate DTO
struct TrainingTemplateDTO: Identifiable, Codable {
    var docId: String?
    var templateId: String
    var name: String
    var exercises: [String]
    var activities: [WorkoutActivityBlockDTO]
    var updatedAt: Date

    var id: String { templateId }

    enum CodingKeys: String, CodingKey {
        case docId, templateId, name, exercises, activities, updatedAt
    }

    init(docId: String?, templateId: String, name: String, exercises: [String], activities: [WorkoutActivityBlockDTO] = [], updatedAt: Date) {
        self.docId = docId
        self.templateId = templateId
        self.name = name
        self.exercises = exercises
        self.activities = activities
        self.updatedAt = updatedAt
    }

    init(from t: TrainingTemplate, updatedAt: Date = Date()) {
        self.init(docId: nil, templateId: t.id, name: t.name, exercises: t.exercises, activities: t.activities.map(WorkoutActivityBlockDTO.init), updatedAt: updatedAt)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        docId = try container.decodeIfPresent(String.self, forKey: .docId)
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        exercises = try container.decodeIfPresent([String].self, forKey: .exercises) ?? []
        activities = try container.decodeIfPresent([WorkoutActivityBlockDTO].self, forKey: .activities) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    static func fromSnapshot(_ doc: DocumentSnapshot) throws -> TrainingTemplateDTO {
        guard let data = doc.data() else { throw NSError(domain: "decode.template", code: 0) }
        return TrainingTemplateDTO(
            docId: doc.documentID,
            templateId: data["templateId"] as? String ?? doc.documentID,
            name: data["name"] as? String ?? "",
            exercises: data["exercises"] as? [String] ?? [],
            activities: (data["activities"] as? [[String: Any]] ?? []).map(WorkoutActivityBlockDTO.fromDict),
            updatedAt: FSConv.date(data["updatedAt"])
        )
    }

    func toDict() -> [String: Any] {
        [
            "templateId": templateId,
            "name": name,
            "exercises": exercises,
            "activities": activities.map { $0.toDict() },
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

// ChallengeState DTO
struct ChallengeStateDTO: Identifiable, Codable {
    var docId: String?
    var challenges: [Challenge]
    var trainingUnits: [TrainingUnit]
    var liftLog: [LiftEntry]
    var stepsLog: [String: Int]
    var updatedAt: Date

    var id: String { docId ?? "active" }

    init(
        docId: String?,
        challenges: [Challenge],
        trainingUnits: [TrainingUnit],
        liftLog: [LiftEntry],
        stepsLog: [String: Int],
        updatedAt: Date
    ) {
        self.docId = docId
        self.challenges = challenges
        self.trainingUnits = trainingUnits
        self.liftLog = liftLog
        self.stepsLog = stepsLog
        self.updatedAt = updatedAt
    }

    static func fromSnapshot(_ doc: DocumentSnapshot) throws -> ChallengeStateDTO {
        guard let data = doc.data() else { throw NSError(domain: "decode.challengeState", code: 0) }
        let decoder = JSONDecoder()
        func decode<T: Decodable>(_ any: Any, as: T.Type) -> T? {
            guard JSONSerialization.isValidJSONObject(any),
                  let json = try? JSONSerialization.data(withJSONObject: any)
            else { return nil }
            return try? decoder.decode(T.self, from: json)
        }
        return .init(
            docId: doc.documentID,
            challenges: decode(data["challenges"] as Any, as: [Challenge].self) ?? [],
            trainingUnits: decode(data["trainingUnits"] as Any, as: [TrainingUnit].self) ?? [],
            liftLog: decode(data["liftLog"] as Any, as: [LiftEntry].self) ?? [],
            stepsLog: data["stepsLog"] as? [String: Int] ?? [:],
            updatedAt: FSConv.date(data["updatedAt"])
        )
    }

    func toDict() -> [String: Any] {
        let encoder = JSONEncoder()
        func enc<E: Encodable>(_ v: E) -> Any {
            (try? JSONSerialization.jsonObject(with: encoder.encode(v))) ?? NSNull()
        }
        return [
            "challenges": enc(challenges),
            "trainingUnits": enc(trainingUnits),
            "liftLog": enc(liftLog),
            "stepsLog": stepsLog,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

// MARK: - Domain-Mapping (Mapping DTOs to Domain Model)

extension TrainingEntry {
    static func fromRemote(_ r: TrainingEntryDTO) -> TrainingEntry {
        TrainingEntry(
            id: UUID(uuidString: r.entryId) ?? UUID(),
            date: r.date,
            title: r.title,
            exercises: r.exercises.map { dto in
                Exercise(
                    name: dto.name,
                    sets: dto.sets.map {
                        ExerciseSet(weight: $0.weight, reps: $0.reps, isCompleted: $0.isCompleted)
                    }
                )
            },
            duration: r.duration,
            totalWeight: r.totalWeight,
            emoji: r.emoji,
            updatedAt: r.updatedAt,
            routePolyline: r.routePolyline,
            cardioType: r.cardioType,
            distanceKm: r.distanceKm,
            activeCalories: r.activeCalories,
            averageHeartRate: r.averageHeartRate,
            elevationGainM: r.elevationGainM,
            perceivedEffort: r.perceivedEffort,
            activityNote: r.activityNote,
            healthSourceName: r.healthSourceName,
            healthDeviceName: r.healthDeviceName,
            healthWorkoutActivityRaw: r.healthWorkoutActivityRaw,
            isIndoorWorkout: r.isIndoorWorkout,
            activities: r.activities.map { $0.toModel() }
        )
    }

    func withRemote(_ r: TrainingEntryDTO) -> TrainingEntry {
        TrainingEntry(
            id: UUID(uuidString: r.entryId) ?? self.id,
            date: r.date,
            title: r.title,
            exercises: r.exercises.map { dto in
                Exercise(
                    name: dto.name,
                    sets: dto.sets.map {
                        ExerciseSet(weight: $0.weight, reps: $0.reps, isCompleted: $0.isCompleted)
                    }
                )
            },
            duration: r.duration,
            totalWeight: r.totalWeight,
            emoji: r.emoji,
            updatedAt: r.updatedAt,
            routePolyline: r.routePolyline ?? self.routePolyline,
            cardioType: r.cardioType ?? self.cardioType,
            distanceKm: r.distanceKm ?? self.loggedDistanceKm,
            activeCalories: r.activeCalories ?? self.activeCalories,
            averageHeartRate: r.averageHeartRate ?? self.averageHeartRate,
            elevationGainM: r.elevationGainM ?? self.elevationGainM,
            perceivedEffort: r.perceivedEffort ?? self.perceivedEffort,
            activityNote: r.activityNote ?? self.activityNote,
            healthSourceName: r.healthSourceName ?? self.healthSourceName,
            healthDeviceName: r.healthDeviceName ?? self.healthDeviceName,
            healthWorkoutActivityRaw: r.healthWorkoutActivityRaw ?? self.healthWorkoutActivityRaw,
            isIndoorWorkout: r.isIndoorWorkout ?? self.isIndoorWorkout,
            activities: r.activities.isEmpty ? self.activities : r.activities.map { $0.toModel() }
        )
    }
}
