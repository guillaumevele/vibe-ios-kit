// FILE: SessionStore.swift
import Foundation

protocol SessionStoring: Sendable {
    func load() async throws -> [Session]
    func save(_ sessions: [Session]) async throws
}

struct FileSessionStore: SessionStoring {
    let url: URL

    static func makeDefault() -> FileSessionStore {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        return FileSessionStore(url: directory.appendingPathComponent("focus-sessions.json"))
    }

    static func makePreview() -> FileSessionStore {
        FileSessionStore(url: URL.temporaryDirectory
            .appendingPathComponent("focus-sessions-preview-\(UUID().uuidString).json"))
    }

    func load() async throws -> [Session] {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Session].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }
    }

    func save(_ sessions: [Session]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sessions)
        try data.write(to: url, options: .atomic)
    }
}
