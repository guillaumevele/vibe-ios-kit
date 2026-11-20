// FILE: Session.swift
import Foundation

struct Session: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let duration: TimeInterval
    let startedAt: Date
    let completedAt: Date?
}
