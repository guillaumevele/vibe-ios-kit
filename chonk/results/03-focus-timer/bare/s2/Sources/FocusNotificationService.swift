// FILE: FocusNotificationService.swift
import Foundation
import UserNotifications

final class FocusNotificationService {
    private let center = UNUserNotificationCenter.current()
    private let identifier = "com.focustimer.session-complete"

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleCompletion(at date: Date, title: String) {
        cancel()
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete"
        content.body = "\"\(title)\" is done — nice work!"
        content.sound = .default
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
