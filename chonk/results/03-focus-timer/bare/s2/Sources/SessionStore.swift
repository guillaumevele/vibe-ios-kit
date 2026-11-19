// FILE: SessionStore.swift
import Foundation
import Observation

@Observable
final class SessionStore {
    private(set) var sessions: [FocusSession] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = directory.appendingPathComponent("focus-sessions.json")
        load()
    }

    // MARK: - Derived stats

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.actualDuration }
    }

    var totalToday: TimeInterval {
        total(since: Calendar.current.startOfDay(for: Date()))
    }

    var totalThisWeek: TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        return total(since: start)
    }

    func total(since date: Date) -> TimeInterval {
        sessions.filter { $0.endedAt >= date }.reduce(0) { $0 + $1.actualDuration }
    }

    // MARK: - Mutations

    func add(_ session: FocusSession) {
        sessions.insert(session, at: 0)
        save()
    }

    func delete(_ session: FocusSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func clear() {
        sessions.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try decoder.decode([FocusSession].self, from: data)
        } catch {
            sessions = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort — history is non-critical.
        }
    }
}
