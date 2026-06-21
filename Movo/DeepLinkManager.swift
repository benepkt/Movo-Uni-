import Foundation
import SwiftUI

@MainActor
final class DeepLinkManager: ObservableObject {
    @Published var inviteFrom: String? = nil   // UID aus movo://invite?from=<uid>
    @Published var templateToImport: TrainingTemplate? = nil  // Template aus movo://template/import
    @Published var programToImport: TrainingProgram? = nil  // Plan aus movo://program/import

    func handle(_ url: URL) {
        guard url.scheme == "movo" else { return }
        
        // Handle invite links
        if url.host?.lowercased() == "invite" {
            handleInvite(url)
            return
        }
        
        // Handle template import links
        if url.host?.lowercased() == "template" {
            handleTemplateImport(url)
            return
        }

        if url.host?.lowercased() == "program" {
            handleProgramImport(url)
            return
        }
    }
    
    private func handleInvite(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let from = comps.queryItems?.first(where: { $0.name == "from" })?.value,
              !from.isEmpty else { return }
        inviteFrom = from
        print("[DEEPLINK] invite from \(from)")
    }
    
    private func handleTemplateImport(_ url: URL) {
        guard url.path == "/import" else {
            print("[DEEPLINK] ❌ Invalid template path: \(url.path)")
            return
        }
        
        guard let template = TemplateSharingService.decodeTemplate(from: url) else {
            print("[DEEPLINK] ❌ Failed to decode template from URL")
            return
        }
        
        templateToImport = template
        print("[DEEPLINK] ✅ Template import ready: \(template.name)")
    }

    private func handleProgramImport(_ url: URL) {
        guard url.path == "/import" else {
            print("[DEEPLINK] ❌ Invalid program path: \(url.path)")
            return
        }

        guard let program = TrainingProgramSharingService.decodeProgram(from: url) else {
            print("[DEEPLINK] ❌ Failed to decode program from URL")
            return
        }

        programToImport = program
        print("[DEEPLINK] ✅ Program import ready: \(program.title)")
    }
}
