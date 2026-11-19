// FILE: FocusSession.swift
import Foundation

struct FocusSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let plannedDuration: TimeInterval
    let actualDuration: TimeInterval
    let startedAt: Date
    let endedAt: Date
    let completed: Bool

    init(
        id: UUID = UUID(),
        title: String,
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval,
        startedAt: Date,
        endedAt: Date,
        completed: Bool
    ) {
        self.id = id
        self.title = title
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.completed = completed
    }
}
