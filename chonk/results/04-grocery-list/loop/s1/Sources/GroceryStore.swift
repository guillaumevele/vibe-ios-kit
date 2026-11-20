// FILE: GroceryStore.swift
import Foundation

/// Anything that reads and writes the list. Replaced by MemoryGroceryStore in previews.
protocol GroceryStore: Sendable {
    func load() async throws -> [Category]
    func save(_ categories: [Category]) async throws
}

/// Persists the list as JSON in Application Support, so it survives relaunches.
struct FileGroceryStore: GroceryStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func persisted() -> FileGroceryStore {
        let directory = URL.applicationSupportDirectory
        // If creating the directory fails, saves will surface an error instead of crashing.
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileGroceryStore(fileURL: directory.appendingPathComponent("groceries.json"))
    }

    func load() async throws -> [Category] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode([Category].self, from: data)
    }

    func save(_ categories: [Category]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(categories)
        try data.write(to: fileURL, options: .atomic)
    }
}

/// In-memory store for previews. An actor, because the protocol's save mutates state
/// and a struct cannot mutate itself in a non-mutating witness.
actor MemoryGroceryStore: GroceryStore {
    private var loaded: [Category]

    init(loaded: [Category] = []) {
        self.loaded = loaded
    }

    func load() async throws -> [Category] {
        loaded
    }

    func save(_ categories: [Category]) async throws {
        loaded = categories
    }
}
