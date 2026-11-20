// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var filter: BookFilter = .all
    @State private var searchText = ""
    @State private var isPresentingAddBook = false

    private var visibleBooks: [Book] {
        books.filter { book in
            if filter == .favorites && !book.isFavorite { return false }
            guard !searchText.isEmpty else { return true }
            return book.title.localizedCaseInsensitiveContains(searchText)
                || book.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleBooks) { book in
                    NavigationLink(value: book) {
                        BookRowView(book: book)
                    }
                    .swipeActions {
                        Button {
                            withAnimation { book.isFavorite.toggle() }
                        } label: {
                            Label(
                                book.isFavorite ? "Remove Favorite" : "Favorite",
                                systemImage: book.isFavorite ? "star.slash.fill" : "star.fill"
                            )
                        }
                        .tint(.yellow)

                        Button(role: .destructive) {
                            withAnimation { modelContext.delete(book) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Reading List")
            .navigationSubtitle("\(visibleBooks.count) \(visibleBooks.count == 1 ? "book" : "books")")
            .searchable(text: $searchText, prompt: "Title or author")
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddBook = true
                    } label: {
                        Label("Add Book", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Picker("Filter", selection: $filter) {
                        ForEach(BookFilter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
            }
            .sheet(isPresented: $isPresentingAddBook) {
                BookFormView()
            }
            .overlay {
                if visibleBooks.isEmpty {
                    ContentUnavailableView {
                        Label(
                            filter == .favorites ? "No Favorites" : "No Books Yet",
                            systemImage: filter == .favorites ? "star" : "book.closed"
                        )
                    } description: {
                        Text(filter == .favorites
                             ? "Star a book to see it here."
                             : "Add a book to start tracking your reading progress.")
                    } actions: {
                        if filter == .all && searchText.isEmpty {
                            Button("Add Your First Book") {
                                isPresentingAddBook = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
    }
}
