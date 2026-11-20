// FILE: FocusSession.swift
import Foundation

struct FocusSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let duration: TimeInterval
    let startedAt: Date
    let endedAt: Date

    init(id: UUID = UUID(), duration: TimeInterval, startedAt: Date, endedAt: Date) {
        self.id = id
        self.duration = duration
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var minutes: Int { max(1, Int(duration / 60)) }
}

extension FocusSession {
    var timeRange: String {
        let style = Date.FormatStyle().hour().minute()
        return "\(startedAt.formatted(style)) – \(endedAt.formatted(style))"
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours) hr \(minutes) min" }
        if hours > 0 { return "\(hours) hr" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(total) sec"
    }
}
