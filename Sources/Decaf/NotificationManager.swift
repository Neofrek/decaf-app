import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    private var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func requestAuthorization() {
        guard canUseUserNotifications else {
            NSLog("Decaf notifications disabled for unbundled development run.")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("Decaf notification authorization failed: \(error.localizedDescription)")
            } else {
                NSLog("Decaf notification authorization: \(granted)")
            }
        }
    }

    func notifyModeChange(mode: DecafMode, reason: String) {
        guard canUseUserNotifications else {
            NSLog("Decaf automatic mode change: \(mode.shortTitle) - \(reason)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Decaf changed to \(mode.shortTitle)"
        content.body = reason
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "decaf.mode-change.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Decaf notification failed: \(error.localizedDescription)")
            }
        }
    }
}
