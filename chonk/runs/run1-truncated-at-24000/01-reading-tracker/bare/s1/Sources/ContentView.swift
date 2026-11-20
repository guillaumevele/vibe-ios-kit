// FILE: ContentView.swift
import Foundation
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var showFavoritesOnly = false
    @State private var showAddBook = false
    @State private var searchText = ""
    @State private var sort: SortOption = .dateAdded

    enum SortOption: String, CaseIterable {
        case dateAdded = "Recently added"
        case title = "Title A–Z"
        case progress = "Progress"
    }

    private var visibleBooks: [Book] {
        let filtered = books.filter { book in
            (!showFavoritesOnly || book.isFavorite) &&
            (searchText.isEmpty ||
             book.title.localizedCaseInsensitiveContains(searchText) ||
             book.author.localizedCaseInsensitiveContains(searchText))
        }
        switch sort {
        case .dateAdded:
            return filtered.sorted { $0.dateAdded > $1.dateAdded }
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            return filtered.sorted { $0.progress > $1.progress }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !books.isEmpty {
                    Section {
                        StatsHeaderView(books: books)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    ForEach(visibleBooks) { book in
                        NavigationLink(value: book) {
                            BookRowView(book: book)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(book)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
                        .contextMenu {
                            Button {
                                book.isFavorite.toggle()
                            } label: {
                                Label(
                                    book.isFavorite ? "Remove from favourites" : "Add to favourites",
                                    systemImage: book.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                        }
                    }
                } header: {
                    if !visibleBooks.isEmpty {
                        HStack {
                            Text(showFavoritesOnly ? "Favourites" : "All books")
                            Spacer()
                            Text("\(visibleBooks.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reading Tracker")
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { showFavoritesOnly.toggle() }
                    } label: {
                        Label(
                            showFavoritesOnly ? "Show all" : "Favourites",
                            systemImage: showFavoritesOnly ? "star.fill" : "star"
                        )
                    }
                    .tint(showFavoritesOnly ? .yellow : .primary)
                    .accessibilityLabel(showFavoritesOnly
                                        ? "Showing favourites only, tap to show all books"
                                        : "Show favourites only")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Sort by") {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button {
                                    sort = option
                                } label: {
                                    if sort == option {
                                        Label(option.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        }
                        Button {
                            showAddBook = true
                        } label: {
                            Label("Add book", systemImage: "plus")
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBook = true
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                    .accessibilityLabel("Add book")
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
                    .presentationDetents([.medium, .large])
            }
            .overlay {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("No books yet", systemImage: "book.closed")
                    } description: {
                        Text("Tap + to add the first book you're reading.")
                    } actions: {
                        Button("Add book") { showAddBook = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if visibleBooks.isEmpty {
                    if showFavoritesOnly && searchText.isEmpty {
                        ContentUnavailableView {
                            Label("No favourites yet", systemImage: "star")
                        } description: {
                            Text("Tap the star on any book to add it to your favourites.")
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
    }
}
