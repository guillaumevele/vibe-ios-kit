// FILE: SessionStore.swift
import Foundation

protocol SessionStoring: Sendable {
    func load() async throws -> [Session]
    func save(_ sessions: [Session]) async throws
}

struct FileSessionStore: SessionStoring {
    let url: URL

    static func makeDefault() -> FileSessionStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileSessionStore(url: directory.appendingPathComponent("focus-sessions.json"))
    }

    static func makePreview() -> FileSessionStore {
        FileSessionStore(url: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("focus-sessions-preview-\(UUID().uuidString).json"))
    }

    func load() async throws -> [Session] {
        let data = try await Task.detached {
            guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
            return try Data(contentsOf: url)
        }.value
        guard let data else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Session].self, from: data)
    }

    func save(_ sessions: [Session]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sessions)
        try await Task.detached {
            try data.write(to: url, options: .atomic)
        }.value
    }
}
