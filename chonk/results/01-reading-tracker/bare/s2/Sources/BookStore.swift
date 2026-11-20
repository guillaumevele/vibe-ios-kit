// FILE: BookStore.swift
import Foundation

@Observable
final class BookStore {
    var books: [Book] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("books.json")
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        books = (try? decoder.decode([Book].self, from: data)) ?? []
    }

    private func save() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(books) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Lookup

    func book(with id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    func visibleBooks(filter: LibraryFilter, searchText: String) -> [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return books
            .filter(filter.predicate)
            .filter {
                query.isEmpty
                || $0.title.lowercased().contains(query)
                || $0.author.lowercased().contains(query)
            }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    // MARK: - Mutations

    func add(_ book: Book) {
        books.append(book)
        save()
    }

    func update(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index] = book
        save()
    }

    func delete(_ id: UUID) {
        books.removeAll { $0.id == id }
        save()
    }

    func delete(at offsets: IndexSet, from list: [Book]) {
        let ids = offsets.map { list[$0].id }
        books.removeAll { ids.contains($0.id) }
        save()
    }

    func toggleFavourite(_ id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].isFavourite.toggle()
        save()
    }

    func setStatus(_ status: ReadingStatus, for id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].status = status
        if status == .finished {
            books[index].dateFinished = Date()
            if books[index].totalPages > 0 {
                books[index].pagesRead = books[index].totalPages
            }
        }
        save()
    }

    func setPagesRead(_ pages: Int, for id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        let clamped = max(0, min(pages, books[index].totalPages))
        books[index].pagesRead = clamped
        if books[index].totalPages > 0 && clamped >= books[index].totalPages {
            books[index].status = .finished
            books[index].dateFinished = Date()
        } else if clamped > 0 && books[index].status == .wantToRead {
            books[index].status = .reading
        }
        save()
    }

    func addPages(_ pages: Int, to id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }), pages > 0 else { return }
        var book = books[index]
        var newValue = book.pagesRead + pages
        if book.totalPages > 0 {
            newValue = min(newValue, book.totalPages)
        }
        let delta = newValue - book.pagesRead
        guard delta > 0 else { return }
        book.pagesRead = newValue
        book.history.append(ReadingEntry(date: Date(), pages: delta))
        if book.totalPages > 0 && newValue >= book.totalPages {
            book.status = .finished
            book.dateFinished = Date()
        } else if book.status == .wantToRead {
            book.status = .reading
        }
        books[index] = book
        save()
    }

    func setNotes(_ notes: String, for id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].notes = notes
        save()
    }

    // MARK: - Stats

    var totalPagesRead: Int {
        books.reduce(0) { $0 + $1.pagesRead }
    }

    var pagesReadThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return books
            .flatMap(\.history)
            .filter { $0.date >= weekAgo }
            .reduce(0) { $0 + $1.pages }
    }

    var finishedCount: Int  { books.filter { $0.status == .finished }.count }
    var readingCount: Int   { books.filter { $0.status == .reading }.count }
    var favouriteCount: Int { books.filter(\.isFavourite).count }
}
