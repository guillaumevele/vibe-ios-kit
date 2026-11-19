// FILE: TimeFormat.swift
import Foundation

enum TimeFormat {
    /// "25:00", or "1:30:00" for sessions over an hour.
    static func hms(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// "25 min", "1 hr", "1 hr 30 min".
    static func minutes(_ seconds: TimeInterval) -> String {
        let total = Int(seconds / 60)
        if total < 60 { return "\(total) min" }
        let hours = total / 60
        let remainder = total % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }

    /// "Today", "Yesterday", or an abbreviated date.
    static func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
