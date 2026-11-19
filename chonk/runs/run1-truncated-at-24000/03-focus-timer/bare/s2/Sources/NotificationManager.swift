// FILE: NotificationManager.swift
import Foundation
import UserNotifications

/// Schedules a local notification for when the focus session ends,
/// so completion is signaled even if the app is in the background.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    func scheduleCompletion(at date: Date, title: String) {
        let content = UNNotificationContent()
        content.title = "Focus session complete"
        content.body = "“\(title)” is done. Great work!"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "focus-completion-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
