import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

/// Service für das Teilen von Trainingsvorlagen via QR-Code
final class TemplateSharingService {
    
    // MARK: - Shareable Template Structure
    
    private struct ShareableTemplate: Codable {
        let name: String
        let exercises: [String]
        let version: Int = 1
    }
    
    // MARK: - Public API
    
    /// Erstellt einen teilbaren Link aus einem TrainingTemplate
    /// - Parameter template: Das zu teilende Template
    /// - Returns: URL-String im Format "movo://template/import?data=..."
    static func createShareLink(from template: TrainingTemplate) -> String? {
        let shareable = ShareableTemplate(
            name: template.name,
            exercises: template.exercises
        )
        
        guard let jsonData = try? JSONEncoder().encode(shareable) else {
            print("[TemplateSharingService] ❌ Failed to encode template")
            return nil
        }
        
        // Base64 encoding (URL-safe)
        let base64 = jsonData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return "movo://template/import?data=\(base64)"
    }
    
    /// Generiert einen QR-Code aus einem TrainingTemplate
    /// - Parameter template: Das zu teilende Template
    /// - Returns: UIImage mit QR-Code oder nil bei Fehler
    static func generateQRCode(from template: TrainingTemplate) -> UIImage? {
        guard let link = createShareLink(from: template) else {
            return nil
        }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(link.utf8)
        filter.correctionLevel = "M" // Medium error correction
        
        guard let outputImage = filter.outputImage else {
            print("[TemplateSharingService] ❌ Failed to generate QR code")
            return nil
        }
        
        // Scale up for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Dekodiert ein Template aus einem Deep Link
    /// - Parameter url: Die Deep Link URL
    /// - Returns: Dekodiertes Template oder nil bei Fehler
    static func decodeTemplate(from url: URL) -> TrainingTemplate? {
        // Prüfe URL-Schema
        guard url.scheme == "movo",
              url.host == "template",
              url.path == "/import" else {
            print("[TemplateSharingService] ❌ Invalid URL scheme")
            return nil
        }
        
        // Extrahiere data-Parameter
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataParam = queryItems.first(where: { $0.name == "data" })?.value else {
            print("[TemplateSharingService] ❌ Missing data parameter")
            return nil
        }
        
        // Dekodiere Base64 (URL-safe zurück zu Standard)
        let base64 = dataParam
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Padding hinzufügen falls nötig
        let paddedBase64: String = {
            let remainder = base64.count % 4
            if remainder > 0 {
                return base64 + String(repeating: "=", count: 4 - remainder)
            }
            return base64
        }()
        
        guard let jsonData = Data(base64Encoded: paddedBase64) else {
            print("[TemplateSharingService] ❌ Failed to decode base64")
            return nil
        }
        
        // Dekodiere JSON
        guard let shareable = try? JSONDecoder().decode(ShareableTemplate.self, from: jsonData) else {
            print("[TemplateSharingService] ❌ Failed to decode JSON")
            return nil
        }
        
        // Validierung
        guard !shareable.name.isEmpty,
              !shareable.exercises.isEmpty else {
            print("[TemplateSharingService] ❌ Invalid template data")
            return nil
        }
        
        // Erstelle TrainingTemplate
        return TrainingTemplate(
            id: UUID().uuidString,
            name: shareable.name,
            exercises: shareable.exercises,
            ownerId: "", // Wird beim Import gesetzt
            updatedAt: Date()
        )
    }
}

/// Service für das Teilen kompletter Trainingspläne via Link/QR-Code.
final class TrainingProgramSharingService {
    private struct ShareableRoutine: Codable {
        let id: String
        let name: String
        let exercises: [String]
        let activities: [WorkoutActivityBlock]

        init(from template: TrainingTemplate) {
            id = template.id
            name = template.name
            exercises = template.exercises
            activities = template.activities
        }

        var template: TrainingTemplate {
            TrainingTemplate(
                id: id,
                name: name,
                exercises: exercises,
                activities: activities,
                ownerId: "",
                updatedAt: Date()
            )
        }
    }

    private struct ShareableProgram: Codable {
        let title: String
        let description: String
        let difficulty: TrainingProgram.ProgramDifficulty
        let durationWeeks: Int
        let isUnlimited: Bool
        let smartOrderingEnabled: Bool
        let routines: [ShareableRoutine]
        let schedule: [Int: String]
        let version: Int = 1

        enum CodingKeys: String, CodingKey {
            case title, description, difficulty, durationWeeks, isUnlimited, smartOrderingEnabled, routines, schedule, version
        }

        init(
            title: String,
            description: String,
            difficulty: TrainingProgram.ProgramDifficulty,
            durationWeeks: Int,
            isUnlimited: Bool,
            smartOrderingEnabled: Bool,
            routines: [ShareableRoutine],
            schedule: [Int: String]
        ) {
            self.title = title
            self.description = description
            self.difficulty = difficulty
            self.durationWeeks = durationWeeks
            self.isUnlimited = isUnlimited
            self.smartOrderingEnabled = smartOrderingEnabled
            self.routines = routines
            self.schedule = schedule
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Trainingsplan"
            description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
            difficulty = try container.decodeIfPresent(TrainingProgram.ProgramDifficulty.self, forKey: .difficulty) ?? .intermediate
            durationWeeks = try container.decodeIfPresent(Int.self, forKey: .durationWeeks) ?? 8
            isUnlimited = try container.decodeIfPresent(Bool.self, forKey: .isUnlimited) ?? false
            smartOrderingEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartOrderingEnabled) ?? true
            routines = try container.decodeIfPresent([ShareableRoutine].self, forKey: .routines) ?? []
            schedule = try container.decodeIfPresent([Int: String].self, forKey: .schedule) ?? [:]
        }
    }

    static func createShareLink(from program: TrainingProgram) -> String? {
        let shareable = ShareableProgram(
            title: program.title,
            description: program.description,
            difficulty: program.difficulty,
            durationWeeks: program.durationWeeks,
            isUnlimited: program.isUnlimited,
            smartOrderingEnabled: program.smartOrderingEnabled,
            routines: program.routines.map { ShareableRoutine(from: $0) },
            schedule: program.schedule
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard let jsonData = try? encoder.encode(shareable) else {
            print("[TrainingProgramSharingService] ❌ Failed to encode program")
            return nil
        }

        let base64 = jsonData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return "movo://program/import?data=\(base64)"
    }

    static func generateQRCode(from program: TrainingProgram) -> UIImage? {
        guard let link = createShareLink(from: program) else { return nil }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(link.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            print("[TrainingProgramSharingService] ❌ Failed to generate QR code")
            return nil
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    static func decodeProgram(from url: URL) -> TrainingProgram? {
        guard url.scheme == "movo",
              url.host == "program",
              url.path == "/import" else {
            print("[TrainingProgramSharingService] ❌ Invalid URL scheme")
            return nil
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value else {
            print("[TrainingProgramSharingService] ❌ Missing data parameter")
            return nil
        }

        return decodeProgram(fromCode: dataParam)
    }

    static func decodeProgram(fromCode code: String) -> TrainingProgram? {
        let rawCode: String
        if let url = URL(string: code.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme == "movo" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let data = components.queryItems?.first(where: { $0.name == "data" })?.value else {
                return nil
            }
            rawCode = data
        } else {
            rawCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let base64 = rawCode
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddedBase64: String = {
            let remainder = base64.count % 4
            if remainder > 0 {
                return base64 + String(repeating: "=", count: 4 - remainder)
            }
            return base64
        }()

        guard let jsonData = Data(base64Encoded: paddedBase64),
              let shareable = try? JSONDecoder().decode(ShareableProgram.self, from: jsonData),
              !shareable.title.isEmpty,
              !shareable.routines.isEmpty else {
            print("[TrainingProgramSharingService] ❌ Failed to decode program")
            return nil
        }

        return TrainingProgram(
            id: UUID().uuidString,
            title: shareable.title,
            description: shareable.description,
            difficulty: shareable.difficulty,
            durationWeeks: shareable.durationWeeks,
            isUnlimited: shareable.isUnlimited,
            smartOrderingEnabled: shareable.smartOrderingEnabled,
            routines: shareable.routines.map(\.template),
            schedule: shareable.schedule
        )
    }
}
