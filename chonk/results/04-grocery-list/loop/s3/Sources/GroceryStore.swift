// FILE: GroceryStore.swift
import Foundation

protocol GroceryStore: Sendable {
    func load() async throws -> [GroceryItem]
    func save(_ items: [GroceryItem]) async throws
}

struct FileGroceryStore: GroceryStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func makeDefault() -> FileGroceryStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileGroceryStore(fileURL: directory.appendingPathComponent("grocery-list.json"))
    }

    func load() async throws -> [GroceryItem] {
        do {
            let data = try await Data(contentsOf: fileURL)
            return try JSONDecoder().decode([GroceryItem].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    func save(_ items: [GroceryItem]) async throws {
        let directory = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(items)
        try await data.write(to: fileURL, options: .atomic)
    }
}

actor InMemoryGroceryStore: GroceryStore {
    private var stored: [GroceryItem]

    init(items: [GroceryItem] = []) {
        stored = items
    }

    func load() async throws -> [GroceryItem] {
        stored
    }

    func save(_ items: [GroceryItem]) async throws {
        stored = items
    }
}
