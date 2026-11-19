// FILE: Formatters.swift
import Foundation

enum Formatters {
    /// "MM:SS" countdown format, e.g. 25:00 -> 24:59 ...
    static func mmss(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Human readable duration for history, e.g. "25 min", "1 hr 5 min"
    static func long(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) hr \(minutes) min" : "\(hours) hr"
        }
        if minutes > 0 {
            return seconds >= 30 ? "\(minutes + 1) min" : "\(minutes) min"
        }
        return "\(seconds) sec"
    }
}
