import Foundation
import UserNotifications
import UIKit

enum NotificationHelper {

    // Optional: call once on app launch, or we’ll request on first schedule
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    /// Schedules a local notification immediately (small delay to ensure delivery).
    /// Honors the "notificationsEnabled" user default used by AppSettings.
    static func schedule(title: String, body: String) {
        // Respect user preference from AppSettings
        let enabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        guard enabled else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                scheduleNow(title: title, body: body)

            case .denied:
                // User denied notifications; do nothing
                break

            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        scheduleNow(title: title, body: body)
                    }
                }

            @unknown default:
                break
            }
        }
    }

    private static func scheduleNow(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Fire immediately (slight delay to ensure delivery even if called from foreground)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "movo.local.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
 
