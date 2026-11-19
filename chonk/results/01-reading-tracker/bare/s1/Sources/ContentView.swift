// FILE: ContentView.swift
import SwiftUI
import SwiftData

/// Filter for the book list: everything, or only favourites.
enum ReadingFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favourites = "Favourites"

    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var filter: ReadingFilter = .all
    @State private var searchText = ""
    @State private var showingAddBook = false

    private var visibleBooks: [Book] {
        books.filter { book in
            let matchesFilter = filter == .all || book.isFavorite
            let matchesSearch = searchText.isEmpty
                || book.title.localizedCaseInsensitiveContains(searchText)
                || book.author.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    private var averageProgress: Double {
        guard !visibleBooks.isEmpty else { return 0 }
        return visibleBooks.reduce(0.0) { $0 + $1.progress } / Double(visibleBooks.count)
    }

    private var summaryText: String {
        let count = visibleBooks.count
        let noun = count == 1 ? "book" : "books"
        return "\(count) \(noun) · \(Int(averageProgress * 100))% average progress"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(ReadingFilter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ForEach(visibleBooks) { book in
                        NavigationLink(value: book) {
                            BookRowView(book: book)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                book.pagesRead = min(book.pagesRead + 10, book.totalPages)
                            } label: {
                                Label("Read 10 pages", systemImage: "plus.circle.fill")
                            }
                            .tint(.green)

                            Button {
                                book.isFavorite.toggle()
                            } label: {
                                Label(
                                    book.isFavorite ? "Remove favourite" : "Favourite",
                                    systemImage: book.isFavorite ? "star.slash.fill" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(book)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                } header: {
                    if !visibleBooks.isEmpty {
                        Text(summaryText)
                    }
                }
            }
            .navigationTitle("My Books")
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Label("Add Book", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
            .overlay {
                if visibleBooks.isEmpty {
                    emptyState
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if filter == .favourites {
            ContentUnavailableView {
                Label("No Favourites", systemImage: "star.slash")
            } description: {
                Text("Tap the star on any book to add it to your favourites.")
            }
        } else {
            ContentUnavailableView {
                Label("No Books Yet", systemImage: "book.closed")
            } description: {
                Text("Tap the + button to start tracking your first book.")
            } actions: {
                Button("Add a Book") { showingAddBook = true }
            }
        }
    }
}
