// FILE: BookStore.swift
import Foundation
import Observation

enum BookStoreError: LocalizedError, Sendable, Equatable {
    case storeUnavailable
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .storeUnavailable:
            "The library could not be loaded, so changes are paused to protect your saved books. Retry loading first."
        case .saveFailed(let detail):
            "The change could not be saved. \(detail)"
        }
    }
}

@MainActor
@Observable
final class BookStore {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    enum ViewState: Equatable {
        case loading
        case failed(String)
        case empty
        case content
    }

    var books: [Book] = []
    var phase: Phase = .loading
    var filter: BookFilter = .all
    var errorText: String?

    private let repository: BookRepository

    init(repository: BookRepository) {
        self.repository = repository
    }

    var state: ViewState {
        switch phase {
        case .loading:
            return .loading
        case .failed(let message):
            return .failed(message)
        case .loaded:
            return visibleBooks.isEmpty ? .empty : .content
        }
    }

    var visibleBooks: [Book] {
        let filtered = filter == .favourites ? books.filter(\.isFavourite) : books
        return filtered.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    var emptyShowsFavouritesHint: Bool {
        filter == .favourites && !books.isEmpty
    }

    func load() async {
        phase = .loading
        do {
            books = try await repository.load()
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func save(_ draft: BookDraft, editing existing: Book?) async throws {
        var updated = books
        let book = Book(
            id: existing?.id ?? UUID(),
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: draft.author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: draft.totalPages,
            pagesRead: draft.pagesRead,
            isFavourite: draft.isFavourite,
            lastUpdated: .now
        )
        if let existing, let index = updated.firstIndex(where: { $0.id == existing.id }) {
            updated[index] = book
        } else {
            updated.append(book)
        }
        try await commit(updated)
    }

    func toggleFavourite(_ book: Book) async {
        var updated = books
        guard let index = updated.firstIndex(where: { $0.id == book.id }) else { return }
        updated[index].isFavourite.toggle()
        updated[index].lastUpdated = .now
        do {
            try await commit(updated)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func delete(_ book: Book) async {
        var updated = books
        updated.removeAll { $0.id == book.id }
        do {
            try await commit(updated)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func commit(_ updated: [Book]) async throws {
        guard case .loaded = phase else {
            throw BookStoreError.storeUnavailable
        }
        do {
            try await repository.save(updated)
        } catch {
            throw BookStoreError.saveFailed(error.localizedDescription)
        }
        books = updated
    }
}
