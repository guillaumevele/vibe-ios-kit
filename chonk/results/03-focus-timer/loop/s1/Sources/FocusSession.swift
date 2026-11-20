// FILE: FocusSession.swift
import Foundation

struct FocusSession: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let startedAt: Date
    let plannedDuration: TimeInterval
    let completed: Bool
    let endedAt: Date

    var actualDuration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }

    var plannedDurationText: String {
        Duration.seconds(plannedDuration).formatted(.units(allowed: [.minutes, .seconds]))
    }

    var actualDurationText: String {
        Duration.seconds(actualDuration).formatted(.units(allowed: [.minutes, .seconds]))
    }
}
