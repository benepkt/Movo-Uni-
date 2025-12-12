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
        cardioType: String? = nil

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
            cardioType: e.cardioType

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
                cardioType: data["cardioType"] as? String
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
            return dict
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
    var updatedAt: Date

    var id: String { templateId }

    init(docId: String?, templateId: String, name: String, exercises: [String], updatedAt: Date) {
        self.docId = docId
        self.templateId = templateId
        self.name = name
        self.exercises = exercises
        self.updatedAt = updatedAt
    }

    init(from t: TrainingTemplate, updatedAt: Date = Date()) {
        self.init(docId: nil, templateId: t.id, name: t.name, exercises: t.exercises, updatedAt: updatedAt)
    }

    static func fromSnapshot(_ doc: DocumentSnapshot) throws -> TrainingTemplateDTO {
        guard let data = doc.data() else { throw NSError(domain: "decode.template", code: 0) }
        return TrainingTemplateDTO(
            docId: doc.documentID,
            templateId: data["templateId"] as? String ?? doc.documentID,
            name: data["name"] as? String ?? "",
            exercises: data["exercises"] as? [String] ?? [],
            updatedAt: FSConv.date(data["updatedAt"])
        )
    }

    func toDict() -> [String: Any] {
        [
            "templateId": templateId,
            "name": name,
            "exercises": exercises,
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
            cardioType: r.cardioType
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
            cardioType: r.cardioType ?? self.cardioType
        )
    }
}
