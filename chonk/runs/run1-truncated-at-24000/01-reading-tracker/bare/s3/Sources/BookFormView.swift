// FILE: BookFormView.swift
import SwiftUI
import SwiftData

struct BookFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// When non-nil the form edits this book; otherwise it creates a new one.
    let book: Book?

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = 300
    @State private var pagesRead = 0
    @State private var isFavorite = false
    @State private var notes = ""

    init(book: Book? = nil) {
        self.book = book
    }

    private var isEditing: Bool { book != nil }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewProgress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(min(pagesRead, totalPages)) / Double(totalPages)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                    TextField("Author", text: $author)
                        .textContentType(.name)
                }

                Section("Reading progress") {
                    Stepper(value: $totalPages, in: 1...10_000, step: 10) {
                        Text("Total pages: \(totalPages)")
                    }
                    Stepper(value: $pagesRead, in: 0...max(1, totalPages)) {
                        Text("Pages read: \(pagesRead)")
                    }
                    .onChange(of: totalPages) { _, newValue in
                        pagesRead = min(pagesRead, max(1, newValue))
                    }

                    ProgressView(value: previewProgress)
                    Text("\(Int(previewProgress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Options") {
                    Toggle(isOn: $isFavorite) {
                        Label("Favorite", systemImage: "star.fill")
                    }
                    .tint(.yellow)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Book" : "New Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadExistingValues)
        }
    }

    private func loadExistingValues() {
        guard let book else { return }
        title = book.title
        author = book.author
        totalPages = book.totalPages
        pagesRead = book.pagesRead
        isFavorite = book.isFavorite
        notes = book.notes ?? ""
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTotal = max(1, totalPages)
        let safeRead = min(max(0, pagesRead), safeTotal)
        let finalAuthor = cleanAuthor.isEmpty ? "Unknown" : cleanAuthor
        let finalNotes = cleanNotes.isEmpty ? nil : cleanNotes

        if let book {
            book.title = cleanTitle
            book.author = finalAuthor
            book.totalPages = safeTotal
            book.pagesRead = safeRead
            book.isFavorite = isFavorite
            book.notes = finalNotes
        } else {
            modelContext.insert(Book(
                title: cleanTitle,
                author: finalAuthor,
                totalPages: safeTotal,
                pagesRead: safeRead,
                isFavorite: isFavorite,
                notes: finalNotes
            ))
        }
        dismiss()
    }
}
