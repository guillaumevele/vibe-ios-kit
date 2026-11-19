// FILE: BookListView.swift
import SwiftUI

struct BookListView: View {
    @Environment(BookStore.self) private var store

    @State private var filter: LibraryFilter = .all
    @State private var searchText = ""
    @State private var showingAddBook = false

    private var books: [Book] {
        store.visibleBooks(filter: filter, searchText: searchText)
    }

    var body: some View {
        List {
            if books.isEmpty {
                ContentUnavailableView {
                    Label("No books found", systemImage: "book.closed")
                } description: {
                    Text(searchText.isEmpty
                         ? "Add a book to start tracking your reading."
                         : "No books match your search.")
                } actions: {
                    if searchText.isEmpty {
                        Button("Add Book") { showingAddBook = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            ForEach(books) { book in
                NavigationLink(value: book.id) {
                    BookRowView(book: book)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        store.toggleFavourite(book.id)
                    } label: {
                        Label(
                            book.isFavourite ? "Unfavourite" : "Favourite",
                            systemImage: book.isFavourite ? "star.slash" : "star.fill"
                        )
                    }
                    .tint(book.isFavourite ? .gray : .yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.delete(book.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                store.delete(at: offsets, from: books)
            }
        }
        .navigationTitle("My Library")
        .searchable(text: $searchText, prompt: "Search title or author")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Filter", selection: $filter) {
                    ForEach(LibraryFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddBook = true
                } label: {
                    Label("Add Book", systemImage: "plus")
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            if store.book(with: id) != nil {
                BookDetailView(bookID: id)
            } else {
                ContentUnavailableView("Book not found", systemImage: "questionmark.book")
            }
        }
        .sheet(isPresented: $showingAddBook) {
            BookFormView(mode: .add)
        }
    }
}
