import Foundation
import SwiftUI

@MainActor
final class DeepLinkManager: ObservableObject {
    @Published var inviteFrom: String? = nil   // UID aus movo://invite?from=<uid>

    func handle(_ url: URL) {
        guard url.scheme == "movo" else { return }
        guard url.host?.lowercased() == "invite" else { return }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let from = comps.queryItems?.first(where: { $0.name == "from" })?.value,
              !from.isEmpty else { return }
        inviteFrom = from
        print("[DEEPLINK] invite from \(from)")
    }
}
