import Foundation
import WatchConnectivity

#if os(watchOS)
import UserNotifications
import WatchKit
#endif

extension WatchConnectivity {
    // MARK: - Local Notification
    
    func sendTrainingStartNotification(workoutName: String) {
        #if os(watchOS)
        let content = UNMutableNotificationContent()
        content.title = "🏋️ Training gestartet!"
        content.body = workoutName
        content.sound = .defaultCritical // ✅ Kritischer Sound - weckt Watch auf!
        content.categoryIdentifier = "TRAINING_START"
        
        // ✅ CRITICAL ALERT - weckt Watch aus Standby auf!
        content.interruptionLevel = .critical
        
        // ✅ Relevance Score für sofortige Anzeige
        content.relevanceScore = 1.0
        
        let request = UNNotificationRequest(
            identifier: "training_start_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Sofort
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error:", error.localizedDescription)
            } else {
                print("✅ CRITICAL Training notification sent - Watch sollte aufwachen!")
                // ✅ STÄRKSTE Haptic Vibration
                WKInterfaceDevice.current().play(.notification)
                // Zusätzliche Vibration für mehr Aufmerksamkeit
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    WKInterfaceDevice.current().play(.start)
                }
            }
        }
        #endif
    }
}
