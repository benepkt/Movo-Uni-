import SwiftUI

@main
struct MovoWatch_Watch_AppApp: App {

    init() {
        // ✅ WatchConnectivity beim Start aktivieren
        WatchConnectivity.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
