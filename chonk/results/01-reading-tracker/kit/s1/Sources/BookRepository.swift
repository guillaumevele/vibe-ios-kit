// FILE: BookRepository.swift
import Foundation

protocol BookRepository: Sendable {
    func load() async throws -> [Book]
    func save(_ books: [Book]) async throws
}

struct FileBookRepository: BookRepository {
    let fileURL: URL

    func load() async throws -> [Book] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Book].self, from: data)
    }

    func save(_ books: [Book]) async throws {
        let data = try JSONEncoder().encode(books)
        try data.write(to: fileURL, options: .atomic)
    }
}

struct InMemoryBookRepository: BookRepository {
    var books: [Book]

    func load() async throws -> [Book] {
        books
    }

    func save(_ newBooks: [Book]) async throws {
        books = newBooks
    }
}
