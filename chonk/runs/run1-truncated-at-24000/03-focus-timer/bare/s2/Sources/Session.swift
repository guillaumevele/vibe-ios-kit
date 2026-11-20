// FILE: Session.swift
import Foundation
import SwiftData

/// A recorded focus session, persisted with SwiftData.
@Model
final class Session {
    var title: String
    var plannedDuration: TimeInterval
    var focusedDuration: TimeInterval
    var startedAt: Date
    var endedAt: Date
    var completed: Bool

    init(
        title: String,
        plannedDuration: TimeInterval,
        focusedDuration: TimeInterval,
        startedAt: Date,
        endedAt: Date,
        completed: Bool
    ) {
        self.title = title
        self.plannedDuration = plannedDuration
        self.focusedDuration = focusedDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.completed = completed
    }
}
