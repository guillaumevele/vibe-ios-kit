// FILE: SessionStore.swift
import Foundation

protocol SessionStore: Sendable {
    func load() async throws -> [FocusSession]
    func save(_ sessions: [FocusSession]) async throws
}

struct FileSessionStore: SessionStore {
    let fileURL: URL

    static var `default`: FileSessionStore {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return FileSessionStore(fileURL: directory.appendingPathComponent("focus-sessions.json"))
    }

    func load() async throws -> [FocusSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try await Task { try Data(contentsOf: fileURL) }.value
        return try JSONDecoder().decode([FocusSession].self, from: data)
    }

    func save(_ sessions: [FocusSession]) async throws {
        let data = try JSONEncoder().encode(sessions)
        _ = try await Task { try data.write(to: fileURL, options: .atomic) }.value
    }
}

actor InMemorySessionStore: SessionStore {
    private var sessions: [FocusSession]

    init(sessions: [FocusSession] = []) {
        self.sessions = sessions
    }

    func load() async throws -> [FocusSession] {
        sessions
    }

    func save(_ sessions: [FocusSession]) async throws {
        self.sessions = sessions
    }
}
