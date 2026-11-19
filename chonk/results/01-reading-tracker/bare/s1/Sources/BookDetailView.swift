// FILE: BookDetailView.swift
import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    /// Two-way binding for the progress slider, clamped to 0...totalPages.
    private var pagesReadBinding: Binding<Double> {
        Binding(
            get: { Double(book.pagesRead) },
            set: { newValue in
                book.pagesRead = min(max(Int(newValue.rounded()), 0), book.totalPages)
            }
        )
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $book.title)
                TextField("Author", text: $book.author)
                Toggle(isOn: $book.isFavorite) {
                    Label("Favourite", systemImage: "star.fill")
                }
                .tint(.yellow)
                LabeledContent("Added") {
                    Text(book.dateAdded, style: .date)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Progress") {
                Stepper(value: $book.totalPages, in: 1...20000, step: 10) {
                    Text("Total pages: \(book.totalPages)")
                }
                Stepper(value: $book.pagesRead, in: 0...book.totalPages) {
                    Text("Pages read: \(book.pagesRead)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: pagesReadBinding, in: 0...Double(book.totalPages), step: 1)
                    HStack(spacing: 8) {
                        ProgressView(value: book.progress)
                            .tint(book.isFinished ? .green : .blue)
                        Text(book.progress, format: .percent)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                if book.isFinished {
                    Button("Reset progress") {
                        book.pagesRead = 0
                    }
                } else {
                    Button("Mark as finished") {
                        book.pagesRead = book.totalPages
                    }
                    .foregroundStyle(.green)
                }
            }

            Section("Notes") {
                TextField("Notes…", text: $book.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Book", systemImage: "trash")
                }
            }
        }
        .navigationTitle(book.title.isEmpty ? "Book Details" : book.title)
        .onChange(of: book.totalPages) { _, newValue in
            if book.pagesRead > newValue {
                book.pagesRead = newValue
            }
        }
        .confirmationDialog(
            "Delete “\(book.title)”? This cannot be undone.",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(book)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
