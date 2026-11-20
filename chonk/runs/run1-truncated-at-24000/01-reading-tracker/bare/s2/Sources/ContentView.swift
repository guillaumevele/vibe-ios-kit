// FILE: ContentView.swift
import SwiftUI
import SwiftData

enum BookFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favourites = "Favourites"
    var id: String { rawValue }
}

enum BookSortOrder: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently added"
    case title = "Title A–Z"
    case progress = "Progress"
    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var searchText = ""
    @State private var filter: BookFilter = .all
    @State private var sortOrder: BookSortOrder = .recentlyAdded
    @State private var showingAddBook = false

    private var filteredBooks: [Book] {
        var result = books

        if filter == .favourites {
            result = result.filter { $0.isFavorite }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.author.localizedCaseInsensitiveContains(query)
            }
        }

        switch sortOrder {
        case .recentlyAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            result.sort { $0.progress > $1.progress }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("No books yet", systemImage: "books.vertical")
                    } description: {
                        Text("Tap the + button to add the first book you're reading.")
                    } actions: {
                        Button("Add a book") { showingAddBook = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 0) {
                        Picker("Filter", selection: $filter) {
                            ForEach(BookFilter.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        List {
                            Section("Overview") {
                                LibrarySummaryView(books: books)
                            }

                            Section(filter == .favourites ? "Favourites" : "Books") {
                                ForEach(filteredBooks) { book in
                                    NavigationLink {
                                        BookDetailView(book: book)
                                    } label: {
                                        BookRowView(book: book)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            withAnimation { book.isFavorite.toggle() }
                                        } label: {
                                            Label(
                                                book.isFavorite ? "Unfavourite" : "Favourite",
                                                systemImage: book.isFavorite ? "star.slash.fill" : "star.fill"
                                            )
                                        }
                                        .tint(.yellow)
                                    }
                                }
                                .onDelete(perform: deleteBooks)
                            }
                        }
                        .overlay {
                            if filteredBooks.isEmpty {
                                ContentUnavailableView {
                                    Label(
                                        filter == .favourites ? "No favourites yet" : "No results",
                                        systemImage: filter == .favourites ? "star" : "magnifyingglass"
                                    )
                                } description: {
                                    Text(filter == .favourites
                                         ? "Swipe right on a book, or tap the star, to mark it as a favourite."
                                         : "Try a different search or filter.")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reading Tracker")
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(BookSortOrder.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
        }
    }

    private func deleteBooks(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(filteredBooks[offset])
        }
        try? modelContext.save()
    }
}
