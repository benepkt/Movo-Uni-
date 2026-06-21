// TemplateSharing.swift
import Foundation
import UniformTypeIdentifiers
import FirebaseAuth

// Ein kleiner, versionierter Container für den Austausch
struct TemplateExportEnvelope: Codable {
    let version: Int
    let appId: String
    let exportedAt: Date
    let items: [TrainingTemplateDTO]

    static let currentVersion = 1
}

// Hilfsfunktionen für Export/Import
enum TemplateSharing {

    // Optional: eigener Dateiname/Endung
    static let fileExtension = "movo-tpl" // z. B. foo.movo-tpl

    // MARK: - Export

    static func exportURL(for templates: [TrainingTemplate]) throws -> URL {
        let dtos = templates.map { TrainingTemplateDTO(from: $0, updatedAt: $0.updatedAt) }
        let envelope = TemplateExportEnvelope(
            version: TemplateExportEnvelope.currentVersion,
            appId: Bundle.main.bundleIdentifier ?? "app.movo",
            exportedAt: Date(),
            items: dtos
        )
        let data = try JSONEncoder().encode(envelope)
        let filename = safeFilename(from: exportTitle(for: templates)) + "." + fileExtension
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func exportTitle(for templates: [TrainingTemplate]) -> String {
        if templates.count == 1 { return templates.first?.name ?? "template" }
        return "templates-\(templates.count)"
    }

    private static func safeFilename(from name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let clean = name.components(separatedBy: invalid).joined(separator: "_")
        return clean.isEmpty ? "templates" : String(clean.prefix(80))
    }

    // MARK: - Import

    struct ImportResult {
        let templates: [TrainingTemplate]
        let sourceApp: String?
        let version: Int
    }

    static func loadFromFile(url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        // Versuche erst den Envelope zu dekodieren
        if let env = try? JSONDecoder().decode(TemplateExportEnvelope.self, from: data) {
            let uid = Auth.auth().currentUser?.uid ?? "guest"
            let mapped: [TrainingTemplate] = env.items.map {
                TrainingTemplate(id: $0.templateId,
                                 name: $0.name,
                                 exercises: $0.exercises,
                                 activities: $0.activities.map { $0.toModel() },
                                 ownerId: uid,
                                 updatedAt: $0.updatedAt)
            }
            return ImportResult(templates: mapped, sourceApp: env.appId, version: env.version)
        }
        // Fallback: evtl. direkt ein Array von TrainingTemplate
        if let arr = try? JSONDecoder().decode([TrainingTemplate].self, from: data) {
            return ImportResult(templates: arr, sourceApp: nil, version: 0)
        }
        // Fallback 2: evtl. direkt ein Array von DTOs
        if let arr = try? JSONDecoder().decode([TrainingTemplateDTO].self, from: data) {
            let uid = Auth.auth().currentUser?.uid ?? "guest"
            let mapped = arr.map {
                TrainingTemplate(id: $0.templateId,
                                 name: $0.name,
                                 exercises: $0.exercises,
                                 activities: $0.activities.map { $0.toModel() },
                                 ownerId: uid,
                                 updatedAt: $0.updatedAt)
            }
            return ImportResult(templates: mapped, sourceApp: nil, version: 0)
        }
        throw NSError(domain: "TemplateSharing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file format"])
    }
}
