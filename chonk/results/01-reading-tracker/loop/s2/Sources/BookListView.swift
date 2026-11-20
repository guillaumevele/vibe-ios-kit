// FILE: BookListView.swift
import SwiftUI

struct BookListView: View {
    @Bindable var model: LibraryModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $model.filter) {
                    ForEach(LibraryModel.Filter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppDesign.Space.medium)
                .padding(.vertical, AppDesign.Space.small)
                .sensoryFeedback(.selection, trigger: model.filter)

                switch model.state {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .failed(let message):
                    failedView(message)
                case .content:
                    listView
                }
            }
            .navigationTitle("Reading list")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.beginAdd()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a book")
                }
            }
            .sheet(item: $model.draft) { draft in
                AddBookView(draft: draft) {
                    Task { await model.commitDraft(draft) }
                }
            }
            .alert("Delete this book?", isPresented: $model.showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    model.confirmDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Remove \(model.pendingDeleteTitle) from your library. This cannot be undone.")
            }
            .task {
                await model.load()
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading your library")
            Spacer()
        }
    }

    private var emptyView: some View {
        Group {
            if model.filter == .favourites {
                ContentUnavailableView {
                    Label("No favourites yet", systemImage: "star")
                } description: {
                    Text("Tap the star on any book to keep it here.")
                } actions: {
                    Button("Show all books") {
                        model.filter = .all
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No books yet", systemImage: "book")
                } description: {
                    Text("Add the first book you are reading.")
                } actions: {
                    Button("Add a book") {
                        model.beginAdd()
                    }
                }
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack {
            Spacer()
            ContentUnavailableView {
                Label("Could not load your library", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await model.load() }
                }
            }
            Spacer()
        }
    }

    private var listView: some View {
        List {
            if let banner = model.banner {
                HStack(spacing: AppDesign.Space.small) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(AppDesign.Color.accent)
                        .accessibilityHidden(true)
                    Text(banner)
                        .font(.footnote)
                    Spacer()
                    Button {
                        model.dismissBanner()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Dismiss message")
                }
            }
            ForEach(model.visibleBooks) { book in
                NavigationLink(value: book.id) {
                    BookRow(book: book) {
                        model.toggleFavorite(book.id)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        model.toggleFavorite(book.id)
                    } label: {
                        Label(
                            book.isFavorite ? "Remove favourite" : "Mark as favourite",
                            systemImage: book.isFavorite ? "star.slash" : "star"
                        )
                    }
                    .tint(book.isFavorite ? .secondary : AppDesign.Color.accent)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        model.requestDelete(book.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: UUID.self) { id in
            BookDetailView(model: model, bookID: id)
        }
    }
}

#Preview("Library with books") {
    BookListView(model: LibraryModel(store: MemoryBookStore(books: Book.samples), initialBooks: Book.samples))
}

#Preview("Empty library") {
    BookListView(model: LibraryModel(store: MemoryBookStore()))
}

#Preview("Failed to load") {
    BookListView(model: LibraryModel(store: FailingBookStore()))
}
