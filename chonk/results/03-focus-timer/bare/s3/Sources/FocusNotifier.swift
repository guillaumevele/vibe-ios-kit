// FILE: FocusNotifier.swift
import UserNotifications

enum FocusNotifier {
    private static let identifier = "focus-timer.session-complete"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Fires a local notification when the timer ends, e.g. while the app is in the background.
    static func scheduleCompletion(in seconds: TimeInterval) {
        cancel()
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete"
        content.body = "Great work — your timer has finished."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
