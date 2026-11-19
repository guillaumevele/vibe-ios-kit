// FILE: SessionStore.swift
import Foundation

protocol SessionStore: Sendable {
    func load() async throws -> [FocusSession]
    func save(_ sessions: [FocusSession]) async throws
}

struct FileSessionStore: SessionStore {
    let fileURL: URL

    static let `default`: FileSessionStore = {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return FileSessionStore(fileURL: directory.appendingPathComponent("focus-sessions.json"))
    }()

    func load() async throws -> [FocusSession] {
        do {
            let data = try await Data(contentsOf: fileURL, options: .mappedIfSafe)
            return try JSONDecoder().decode([FocusSession].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    func save(_ sessions: [FocusSession]) async throws {
        let data = try JSONEncoder().encode(sessions)
        try await Task.detached {
            try FileManager.default.createDirectory(
                at: self.fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: self.fileURL, options: .atomic)
        }.value
    }
}

actor MemorySessionStore: SessionStore {
    private var storage: [FocusSession]

    init(sessions: [FocusSession] = []) {
        storage = sessions
    }

    func load() async throws -> [FocusSession] {
        storage
    }

    func save(_ sessions: [FocusSession]) async throws {
        storage = sessions
    }
}
