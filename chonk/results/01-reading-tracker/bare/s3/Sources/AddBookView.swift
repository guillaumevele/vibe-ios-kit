// FILE: AddBookView.swift
import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var totalPagesText = ""
    @State private var startPageText = "0"

    private var totalPages: Int {
        Int(totalPagesText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var startPage: Int {
        Int(startPageText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && totalPages > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                }

                Section("Pages") {
                    TextField("Total pages", text: $totalPagesText)
                        .keyboardType(.numberPad)
                    TextField("Start at page", text: $startPageText)
                        .keyboardType(.numberPad)
                }

                Section {
                    Button("Add to library") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("New book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespaces),
            author: author.trimmingCharacters(in: .whitespaces),
            totalPages: totalPages,
            currentPage: min(max(0, startPage), totalPages)
        )
        modelContext.insert(book)
        dismiss()
    }
}
