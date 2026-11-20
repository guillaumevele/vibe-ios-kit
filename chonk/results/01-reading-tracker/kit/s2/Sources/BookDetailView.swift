// FILE: BookDetailView.swift
import SwiftUI

struct BookDetailView: View {
    let model: LibraryModel
    let bookID: UUID

    @State private var pages: Double = 0
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    private var book: Book? {
        model.book(with: bookID)
    }

    var body: some View {
        Group {
            if let book {
                Form {
                    progressSection(book)
                    detailsSection(book)
                    actionsSection(book)
                }
                .navigationTitle(book.title)
            } else {
                ContentUnavailableView {
                    Label("Book not found", systemImage: "book.closed")
                } description: {
                    Text("This book may have been deleted.")
                }
            }
        }
        .task {
            if let book {
                pages = Double(book.pagesRead)
            }
        }
        .onChange(of: pages) { _, newValue in
            model.setPagesRead(bookID, Int(newValue))
        }
        .alert("Delete this book?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                model.delete(bookID)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Remove this book from your library. This cannot be undone.")
        }
    }

    private func progressSection(_ book: Book) -> some View {
        Section("Progress") {
            Slider(
                value: $pages,
                in: 0...Double(book.totalPages),
                step: 1
            ) {
                Text("Pages read")
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("\(book.totalPages)")
            }
            HStack {
                Text("\(book.pagesRead) of \(book.totalPages) pages")
                Spacer()
                Text(book.fraction.formatted(.percent))
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if book.isFinished {
                Label("Finished", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppDesign.Color.accent)
            } else {
                Button("Mark as finished") {
                    model.setPagesRead(bookID, book.totalPages)
                    pages = Double(book.totalPages)
                }
            }
        }
    }

    private func detailsSection(_ book: Book) -> some View {
        Section("Details") {
            LabeledContent("Author", value: book.author)
            LabeledContent("Total pages", value: "\(book.totalPages)")
            LabeledContent("Added", value: book.dateAdded.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private func actionsSection(_ book: Book) -> some View {
        Section {
            Button {
                model.toggleFavorite(bookID)
            } label: {
                Label(
                    book.isFavorite ? "Remove from favourites" : "Add to favourites",
                    systemImage: book.isFavorite ? "star.fill" : "star"
                )
            }
            .sensoryFeedback(.selection, trigger: book.isFavorite)
            Button("Delete book", role: .destructive) {
                showDeleteAlert = true
            }
        }
    }
}

#Preview("Book detail") {
    NavigationStack {
        BookDetailView(
            model: LibraryModel(store: MemoryBookStore(books: Book.samples), initialBooks: Book.samples),
            bookID: Book.samples[0].id
        )
    }
}
