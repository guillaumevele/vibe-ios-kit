// FILE: ClockFormat.swift
import Foundation

enum ClockFormat {
    static func string(for interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func minutesText(for interval: TimeInterval) -> String {
        Duration.seconds(interval).formatted(.units(allowed: [.minutes]))
    }
}
