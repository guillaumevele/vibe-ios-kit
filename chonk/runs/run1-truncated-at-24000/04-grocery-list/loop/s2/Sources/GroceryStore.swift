// FILE: GroceryStore.swift
import Foundation

/// Anything that reads or writes the grocery list. Replace with an in-memory
/// implementation in previews and tests.
protocol GroceryStore: Sendable {
    func load() async throws -> [GroceryItem]
    func save(_ items: [GroceryItem]) async throws
}

enum StoreError: LocalizedError, Sendable {
    case unreadableFile
    case undecodable(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The saved grocery file could not be read."
        case .undecodable(let detail):
            return "The saved grocery file is damaged (\(detail))."
        }
    }
}

/// Persists the list as JSON in Application Support, so it survives launches.
struct FileGroceryStore: GroceryStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = directory.appendingPathComponent("grocery-list.json")
        }
    }

    func load() async throws -> [GroceryItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw StoreError.unreadableFile
        }

        do {
            return try JSONDecoder().decode([GroceryItem].self, from: data)
        } catch {
            throw StoreError.undecodable(error.localizedDescription)
        }
    }

    func save(_ items: [GroceryItem]) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}

#if DEBUG
/// In-memory store used only by previews.
actor PreviewGroceryStore: GroceryStore {
    private var stored: [GroceryItem]
    private let shouldFail: Bool

    init(stored: [GroceryItem] = [], shouldFail: Bool = false) {
        self.stored = stored
        self.shouldFail = shouldFail
    }

    func load() async throws -> [GroceryItem] {
        if shouldFail {
            throw StoreError.unreadableFile
        }
        return stored
    }

    func save(_ items: [GroceryItem]) async throws {
        stored = items
    }
}
#endif
