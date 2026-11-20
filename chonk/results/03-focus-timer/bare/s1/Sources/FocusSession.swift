// FILE: FocusSession.swift
import Foundation
import SwiftData

@Model
final class FocusSession {
    var title: String
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    var startedAt: Date
    var endedAt: Date
    var wasCompleted: Bool

    init(
        title: String,
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval,
        startedAt: Date,
        endedAt: Date,
        wasCompleted: Bool
    ) {
        self.title = title
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.wasCompleted = wasCompleted
    }
}
