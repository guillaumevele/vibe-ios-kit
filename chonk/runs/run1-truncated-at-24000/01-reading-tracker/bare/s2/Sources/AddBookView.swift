// FILE: AddBookView.swift
import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var totalPagesText = ""
    @State private var pagesReadText = ""
    @State private var isFavorite = false
    @State private var notes = ""

    private var totalPages: Int { Int(totalPagesText) ?? 0 }
    private var pagesRead: Int { min(Int(pagesReadText) ?? 0, max(totalPages, 0)) }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && totalPages > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Author", text: $author)
                        .textInputAutocapitalization(.words)
                    Toggle(isOn: $isFavorite) {
                        Label("Favourite", systemImage: "star.fill")
                            .foregroundStyle(isFavorite ? .yellow : .primary)
                    }
                }

                Section("Progress") {
                    TextField("Total pages", text: $totalPagesText)
                        .keyboardType(.numberPad)
                    TextField("Pages already read", text: $pagesReadText)
                        .keyboardType(.numberPad)
                    if totalPages > 0 {
                        ProgressBarView(progress: Double(pagesRead) / Double(totalPages))
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("Add book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        let book = Book(
            title: cleanTitle,
            author: cleanAuthor.isEmpty ? "Unknown author" : cleanAuthor,
            totalPages: totalPages,
            pagesRead: pagesRead,
            isFavorite: isFavorite,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(book)
        try? modelContext.save()
        dismiss()
    }
}
