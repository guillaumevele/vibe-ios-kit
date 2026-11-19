// FILE: GroceryStore.swift
import Foundation

protocol GroceryStore: Sendable {
    func load() async throws -> [GroceryItem]
    func save(_ items: [GroceryItem]) async throws
}

struct FileGroceryStore: GroceryStore {
    private let fileURL: URL

    init() {
        let supportDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        fileURL = supportDirectory.appendingPathComponent("grocery-list.json")
    }

    func load() async throws -> [GroceryItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([GroceryItem].self, from: data)
    }

    func save(_ items: [GroceryItem]) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}

struct InMemoryGroceryStore: GroceryStore {
    let initial: [GroceryItem]

    func load() async throws -> [GroceryItem] {
        initial
    }

    func save(_ items: [GroceryItem]) async throws { }
}
