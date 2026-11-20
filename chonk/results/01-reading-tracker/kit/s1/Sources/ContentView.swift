// FILE: ContentView.swift
import Foundation
import SwiftUI

struct EditorItem: Identifiable {
    let id = UUID()
    let book: Book?
}

struct ContentView: View {
    @Bindable var store: BookStore

    @State private var editorItem: EditorItem?
    @State private var pendingDeletion: Book?
    @State private var showingDeleteAlert = false
    @State private var showingSaveError = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .loading:
                    loadingView
                case .failed(let message):
                    failedView(message)
                case .empty:
                    emptyView
                case .content:
                    listView
                }
            }
            .navigationTitle("Reading")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorItem = EditorItem(book: nil)
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorItem) { item in
                NavigationStack {
                    BookEditorView(store: store, existing: item.book)
                }
            }
            .alert("Delete this book?", isPresented: $showingDeleteAlert, presenting: pendingDeletion) { book in
                Button("Delete", role: .destructive) {
                    Task { await store.delete(book) }
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletion = nil
                }
            } message: { book in
                Text("This removes “\(book.title)” and its reading progress from this device.")
            }
            .alert("Couldn't save changes", isPresented: $showingSaveError, presenting: store.errorText) { _ in
                Button("OK", role: .cancel) {
                    store.errorText = nil
                }
            } message: { message in
                Text(message)
            }
            .onChange(of: store.errorText) { _, newValue in
                showingSaveError = newValue != nil
            }
        }
        .task {
            await store.load()
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.medium) {
            ProgressView()
                .controlSize(.large)
            Text("Loading your books…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load your books", systemImage: "exclamationmark.triangle")
        } description: {
            Text("\(message) Your saved books are safe, and changes are paused until loading succeeds.")
        } actions: {
            Button("Retry") {
                Task { await store.load() }
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            if store.emptyShowsFavouritesHint {
                Label("No favourites yet", systemImage: "star")
            } else {
                Label("No books yet", systemImage: "book")
            }
        } description: {
            if store.emptyShowsFavouritesHint {
                Text("Tap the star on a book to see it here.")
            } else {
                Text("Add the first book you are reading to start tracking your progress.")
            }
        } actions: {
            if store.emptyShowsFavouritesHint {
                Button("Show all books") {
                    store.filter = .all
                }
            } else {
                Button("Add a book") {
                    editorItem = EditorItem(book: nil)
                }
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            Picker("Filter books", selection: $store.filter) {
                ForEach(BookFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .sensoryFeedback(.selection, trigger: store.filter)

            List {
                ForEach(store.visibleBooks) { book in
                    BookRowView(
                        book: book,
                        onSelect: { editorItem = EditorItem(book: book) },
                        onToggleFavourite: { Task { await store.toggleFavourite(book) } }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            pendingDeletion = book
                            showingDeleteAlert = true
                        }
                        Button(
                            book.isFavourite ? "Remove favourite" : "Favourite",
                            systemImage: book.isFavourite ? "star.slash" : "star"
                        ) {
                            Task { await store.toggleFavourite(book) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(reduceMotion ? nil : .default, value: store.visibleBooks)
        }
    }
}

#Preview {
    ContentView(store: BookStore(repository: InMemoryBookRepository(books: Book.samples)))
}
