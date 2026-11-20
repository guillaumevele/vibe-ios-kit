// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var library: LibraryViewModel

    init(store: BookStore) {
        _library = State(wrappedValue: LibraryViewModel(store: store))
    }

    private enum DisplayState {
        case loading
        case empty
        case failed(Error)
        case content
    }

    private var displayState: DisplayState {
        switch library.state {
        case .loading:
            return .loading
        case .failed(let error):
            return .failed(error)
        case .loaded:
            return library.visibleBooks.isEmpty ? .empty : .content
        }
    }

    private var isLoaded: Bool {
        if case .loaded = library.state { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Group {
                switch displayState {
                case .loading:
                    ProgressView("Loading your library")
                case .empty:
                    emptyView
                case .failed(let error):
                    failedView(error)
                case .content:
                    bookList
                }
            }
            .navigationTitle("Reading List")
            .navigationSubtitle(
                library.favouritesOnly
                    ? "Showing \(library.favouriteCount) of \(library.books.count) books"
                    : ""
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        library.toggleFavouritesFilter()
                    } label: {
                        Label("Favourites", systemImage: library.favouritesOnly ? "star.fill" : "star")
                            .foregroundStyle(library.favouritesOnly ? Theme.accent : .primary)
                    }
                    .accessibilityLabel("Favourites filter")
                    .accessibilityValue(library.favouritesOnly ? "On" : "Off")
                    .sensoryFeedback(.selection, trigger: library.favouritesOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        library.bookToAdd = BookDraft()
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                    .accessibilityLabel("Add a book")
                    .disabled(!isLoaded)
                }
            }
            .task {
                await library.load()
            }
            .sheet(item: $library.bookToAdd) { draft in
                AddBookView(
                    draft: draft,
                    onSave: { await library.add($0) },
                    onCancel: { library.bookToAdd = nil }
                )
            }
            .alert("Couldn't save your changes", isPresented: $library.showSaveError) {
                Button("Retry") {
                    Task { await library.retrySave() }
                }
                Button("Dismiss", role: .cancel) { }
            } message: {
                Text("Your changes are still on screen, but writing them to storage failed: \(library.saveErrorMessage)")
            }
            .navigationDestination(for: Book.ID.self) { id in
                BookDetailView(bookID: id, library: library)
            }
        }
    }

    private var bookList: some View {
        List {
            ForEach(library.visibleBooks) { book in
                NavigationLink(value: book.id) {
                    BookRowView(book: book) {
                        await library.toggleFavourite(id: book.id)
                    }
                }
            }
            .onDelete { offsets in
                let targets = offsets.map { library.visibleBooks[$0] }
                Task { await library.delete(targets) }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyView: some View {
        Group {
            if library.favouritesOnly {
                ContentUnavailableView {
                    Label("No favourites yet", systemImage: "star")
                } description: {
                    Text("Tap the star on a book to pin it here.")
                } actions: {
                    Button("Show all books") {
                        library.toggleFavouritesFilter()
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No books yet", systemImage: "book")
                } description: {
                    Text("Add the first book you are reading to start tracking progress.")
                } actions: {
                    Button("Add a book", systemImage: "plus") {
                        library.bookToAdd = BookDraft()
                    }
                }
            }
        }
    }

    private func failedView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Couldn't load your library", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Reading your saved books failed: \(error.localizedDescription). Nothing on disk was changed.")
        } actions: {
            Button("Retry", systemImage: "arrow.clockwise") {
                Task { await library.load() }
            }
        }
    }
}

#Preview("With books") {
    ContentView(store: PreviewBookStore())
}

#Preview("Empty library") {
    ContentView(store: PreviewBookStore(books: []))
}
