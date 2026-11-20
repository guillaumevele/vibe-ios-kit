// FILE: BookDetailView.swift
import SwiftUI

struct BookDetailView: View {
    let bookID: Book.ID
    let library: LibraryViewModel

    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private var book: Book? {
        library.book(with: bookID)
    }

    var body: some View {
        Group {
            if let book {
                bookForm(book)
            } else {
                ContentUnavailableView {
                    Label("Book not found", systemImage: "book")
                } description: {
                    Text("This book is no longer in your library.")
                }
            }
        }
        .alert("Remove this book?", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                if let book {
                    Task {
                        await library.delete([book])
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let book {
                Text("\"\(book.title)\" and its reading progress will be removed. This cannot be undone.")
            } else {
                Text("This book and its reading progress will be removed.")
            }
        }
    }

    private func bookForm(_ book: Book) -> some View {
        Form {
            Section {
                Text(book.title)
                    .font(.title2)
                    .bold()
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Added")
                    Spacer()
                    Text(book.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            Section("Progress") {
                HStack {
                    Text(book.progress.formatted(.percent))
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    if book.isFinished {
                        Label("Finished", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressTrack(progress: book.progress)
                    .frame(height: 10)
                    .accessibilityHidden(true)
                Stepper(
                    value: Binding(
                        get: { book.pagesRead },
                        set: { newValue in
                            Task { await library.setPagesRead(newValue, for: book.id) }
                        }
                    ),
                    in: 0...book.totalPages
                ) {
                    Text("\(book.pagesRead) of \(book.totalPages) pages read")
                }
                .accessibilityValue("\(book.pagesRead) of \(book.totalPages) pages")
            }

            Section("Quick actions") {
                Button("Add 10 pages", systemImage: "plus") {
                    Task { await library.adjustPages(by: 10, for: book.id) }
                }
                Button("Remove 10 pages", systemImage: "minus") {
                    Task { await library.adjustPages(by: -10, for: book.id) }
                }
                Button("Mark as finished", systemImage: "checkmark") {
                    Task { await library.markFinished(id: book.id) }
                }
                .disabled(book.isFinished)
            }

            Section {
                Button {
                    Task { await library.toggleFavourite(id: book.id) }
                } label: {
                    Label(
                        book.isFavourite ? "Remove from favourites" : "Add to favourites",
                        systemImage: book.isFavourite ? "star.fill" : "star"
                    )
                }
                .sensoryFeedback(.selection, trigger: book.isFavourite)
            }

            Section {
                Button("Remove book", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(book.title)
    }
}
