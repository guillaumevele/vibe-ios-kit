// FILE: LibraryModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class LibraryModel {
    enum LoadState: Equatable {
        case loading
        case empty
        case failed(String)
        case content
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case favourites = "Favourites"

        var id: String { rawValue }
    }

    private let store: any BookStore
    private var readSucceeded = false

    private(set) var isLoading = false
    private(set) var loadErrorMessage: String?
    var banner: String?
    var books: [Book] = []
    var filter: Filter = .all
    var draft: BookDraft?
    var showDeleteAlert = false
    var pendingDeleteID: UUID?

    init(store: any BookStore = FileBookStore(), initialBooks: [Book] = []) {
        self.store = store
        self.books = initialBooks
    }

    var state: LoadState {
        if isLoading {
            return .loading
        }
        if let loadErrorMessage {
            return .failed(loadErrorMessage)
        }
        if visibleBooks.isEmpty {
            return .empty
        }
        return .content
    }

    var visibleBooks: [Book] {
        switch filter {
        case .all:
            return books
        case .favourites:
            return books.filter { $0.isFavorite }
        }
    }

    var pendingDeleteTitle: String {
        books.first { $0.id == pendingDeleteID }?.title ?? "this book"
    }

    func book(with id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    func load() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            books = try await store.load()
            readSucceeded = true
            banner = nil
            isLoading = false
        } catch {
            readSucceeded = false
            loadErrorMessage = "The saved library could not be read: \(error.localizedDescription). Saved books were left untouched, and new changes will not be saved until a load succeeds."
            banner = "Changes are not being saved until your library loads successfully."
            isLoading = false
        }
    }

    func beginAdd() {
        draft = BookDraft()
    }

    func commitDraft(_ draft: BookDraft) async {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = draft.author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let totalPages = Int(draft.totalPagesText), totalPages > 0 else {
            return
        }
        books.append(Book(title: title, author: author, totalPages: totalPages))
        self.draft = nil
        await persist()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else {
            return
        }
        books[index].isFavorite.toggle()
        Task { await persist() }
    }

    func setPagesRead(_ id: UUID, _ pages: Int) {
        guard let index = books.firstIndex(where: { $0.id == id }) else {
            return
        }
        let clamped = max(0, min(pages, books[index].totalPages))
        guard books[index].pagesRead != clamped else {
            return
        }
        books[index].pagesRead = clamped
        Task { await persist() }
    }

    func requestDelete(_ id: UUID) {
        pendingDeleteID = id
        showDeleteAlert = true
    }

    func confirmDelete() {
        guard let id = pendingDeleteID else {
            return
        }
        pendingDeleteID = nil
        delete(id)
    }

    func delete(_ id: UUID) {
        books.removeAll { $0.id == id }
        Task { await persist() }
    }

    func dismissBanner() {
        banner = nil
    }

    private func persist() async {
        guard readSucceeded else {
            return
        }
        do {
            try await store.save(books)
            banner = nil
        } catch {
            banner = "Could not save changes to disk. They will be lost when the app quits."
        }
    }
}
