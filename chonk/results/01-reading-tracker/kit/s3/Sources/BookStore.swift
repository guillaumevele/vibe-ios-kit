// FILE: BookStore.swift
import Foundation

protocol BookStore: Sendable {
    func load() async throws -> [Book]
    func save(_ books: [Book]) async throws
}

struct FileBookStore: BookStore {
    let url: URL

    func load() async throws -> [Book] {
        guard FileManager.default.fileExists(atPath: url.path()) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Book].self, from: data)
    }

    func save(_ books: [Book]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(books)
        try data.write(to: url, options: .atomic)
    }
}

struct PreviewBookStore: BookStore {
    var books: [Book]

    init(books: [Book] = Book.samples) {
        self.books = books
    }

    func load() async throws -> [Book] {
        books
    }

    func save(_ books: [Book]) async throws { }
}
