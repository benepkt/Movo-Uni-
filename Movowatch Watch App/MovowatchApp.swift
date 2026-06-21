import SwiftUI

#if os(watchOS)
import UserNotifications
#endif

@main
struct MovoWatch_Watch_AppApp: App {

    init() {
        // ✅ WatchConnectivity beim Start aktivieren
        WatchConnectivity.shared.activate()
        
        // ✅ Notification-Berechtigung anfordern (inkl. Critical Alerts für Wake-Up)
        #if os(watchOS)
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .criticalAlert] // ✅ Critical Alert weckt Watch auf!
        ) { granted, error in
            if granted {
                print("✅ Watch Notifications erlaubt (inkl. Critical Alerts)")
            } else if let error = error {
                print("❌ Notification permission error:", error.localizedDescription)
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 🔒 Erzwingt Englisch in der gesamten Watch-App
                .environment(\.locale, Locale(identifier: "en_US"))
        }
    }
}
