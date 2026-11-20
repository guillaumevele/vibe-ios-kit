// FILE: LibraryViewModel.swift
import Foundation

@Observable
@MainActor
final class LibraryViewModel {
    enum LoadState {
        case loading
        case loaded
        case failed(Error)
    }

    var state: LoadState = .loading
    var books: [Book] = []
    var visibleBooks: [Book] = []
    var favouritesOnly = false
    var bookToAdd: BookDraft?
    var showSaveError = false
    var saveErrorMessage = ""

    private let store: BookStore
    private var hasReadStore = false

    init(store: BookStore) {
        self.store = store
    }

    var favouriteCount: Int {
        books.filter(\.isFavourite).count
    }

    func book(with id: Book.ID) -> Book? {
        books.first { $0.id == id }
    }

    func load() async {
        state = .loading
        do {
            books = try await store.load()
            hasReadStore = true
            refreshVisible()
            state = .loaded
        } catch {
            // The store read failed: keep whatever is in memory and refuse
            // to write anything back until a read succeeds again.
            state = .failed(error)
        }
    }

    func toggleFavouritesFilter() {
        favouritesOnly.toggle()
        refreshVisible()
    }

    func add(_ draft: BookDraft) async {
        let book = Book(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: draft.author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: draft.totalPages,
            pagesRead: draft.pagesRead
        )
        books.append(book)
        bookToAdd = nil
        refreshVisible()
        await persist()
    }

    func toggleFavourite(id: Book.ID) async {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].isFavourite.toggle()
        refreshVisible()
        await persist()
    }

    func setPagesRead(_ pages: Int, for id: Book.ID) async {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].pagesRead = min(max(0, pages), books[index].totalPages)
        await persist()
    }

    func adjustPages(by delta: Int, for id: Book.ID) async {
        guard let book = book(with: id) else { return }
        await setPagesRead(book.pagesRead + delta, for: id)
    }

    func markFinished(id: Book.ID) async {
        guard let book = book(with: id) else { return }
        await setPagesRead(book.totalPages, for: id)
    }

    func delete(_ toDelete: [Book]) async {
        let ids = Set(toDelete.map(\.id))
        books.removeAll { ids.contains($0.id) }
        refreshVisible()
        await persist()
    }

    func retrySave() async {
        await persist()
    }

    private func persist() async {
        guard hasReadStore else { return }
        do {
            try await store.save(books)
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func refreshVisible() {
        let filtered = favouritesOnly ? books.filter(\.isFavourite) : books
        visibleBooks = filtered.sorted { $0.dateAdded > $1.dateAdded }
    }
}
