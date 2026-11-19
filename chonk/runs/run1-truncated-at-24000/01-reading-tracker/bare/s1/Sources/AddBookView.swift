// FILE: AddBookView.swift
import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = ""
    @State private var pagesRead = ""
    @State private var isFavorite = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Label("Favourite", systemImage: isFavorite ? "star.fill" : "star")
                    }
                    .tint(.yellow)
                }

                Section("Progress") {
                    TextField("Total pages", text: $totalPages)
                        .keyboardType(.numberPad)
                    TextField("Pages already read", text: $pagesRead)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let total = max(0, Int(totalPages) ?? 0)
        let read = min(max(0, Int(pagesRead) ?? 0), total > 0 ? total : max(0, Int(pagesRead) ?? 0))

        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: total,
            pagesRead: read,
            isFavorite: isFavorite
        )
        modelContext.insert(book)
        try? modelContext.save()
        dismiss()
    }
}
