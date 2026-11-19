// FILE: GroceryStore.swift
import Foundation

protocol GroceryStore: Sendable {
    func load() async throws -> [GroceryItem]
    func save(_ items: [GroceryItem]) async throws
}

actor FileGroceryStore: GroceryStore {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    static func makeDefault() -> FileGroceryStore {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileGroceryStore(url: directory.appendingPathComponent("groceries.json"))
    }

    func load() async throws -> [GroceryItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GroceryItem].self, from: data)
    }

    func save(_ items: [GroceryItem]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)
        try data.write(to: url, options: .atomic)
    }
}

actor InMemoryGroceryStore: GroceryStore {
    private var items: [GroceryItem]

    init(items: [GroceryItem] = []) {
        self.items = items
    }

    func load() async throws -> [GroceryItem] {
        items
    }

    func save(_ newItems: [GroceryItem]) async throws {
        items = newItems
    }
}
