// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.lastUpdated, order: .reverse) private var books: [Book]

    @State private var showFavoritesOnly = false
    @State private var searchText = ""
    @State private var isPresentingAddBook = false

    private var visibleBooks: [Book] {
        books.filter { book in
            let matchesFilter = !showFavoritesOnly || book.isFavorite
            let matchesSearch = searchText.isEmpty
                || book.title.localizedCaseInsensitiveContains(searchText)
                || book.author.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $showFavoritesOnly) {
                        Text("All").tag(false)
                        Text("Favorites").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    if visibleBooks.isEmpty {
                        ContentUnavailableView {
                            Label(
                                showFavoritesOnly ? "No favorite books" : "No books yet",
                                systemImage: showFavoritesOnly ? "star.slash" : "book.closed"
                            )
                        } description: {
                            Text(showFavoritesOnly
                                 ? "Tap the star on a book to add it to your favorites."
                                 : "Tap + to add your first book.")
                        }
                    } else {
                        ForEach(visibleBooks) { book in
                            NavigationLink(value: book) {
                                BookRowView(book: book)
                            }
                            .contextMenu {
                                Button {
                                    book.isFavorite.toggle()
                                    book.lastUpdated = Date()
                                } label: {
                                    Label(
                                        book.isFavorite ? "Remove from favorites" : "Add to favorites",
                                        systemImage: book.isFavorite ? "star.slash" : "star"
                                    )
                                }
                            }
                        }
                        .onDelete(perform: deleteBooks)
                    }
                }
            }
            .navigationTitle("My Library")
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddBook = true
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddBook) {
                AddBookView()
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
        }
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleBooks[index])
        }
    }
}
