// FILE: FocusSession.swift
import Foundation

struct FocusSession: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let duration: TimeInterval
    let startedAt: Date
    let endedAt: Date
    let completed: Bool
}
