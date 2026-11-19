// FILE: BookStore.swift
import Foundation

protocol BookStore: Sendable {
    func load() async throws -> [Book]
    func save(_ books: [Book]) async throws
}

actor FileBookStore: BookStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = base.appendingPathComponent("ReadingList", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("books.json")
        }
    }

    func load() async throws -> [Book] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Book].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    func save(_ books: [Book]) async throws {
        let data = try JSONEncoder().encode(books)
        try data.write(to: fileURL, options: .atomic)
    }
}

actor MemoryBookStore: BookStore {
    private var stored: [Book]

    init(books: [Book] = []) {
        stored = books
    }

    func load() async throws -> [Book] {
        stored
    }

    func save(_ books: [Book]) async throws {
        stored = books
    }
}

actor FailingBookStore: BookStore {
    func load() async throws -> [Book] {
        throw CocoaError(.fileReadCorruptFile)
    }

    func save(_ books: [Book]) async throws {
        // Preview-only store; nothing to persist.
    }
}
