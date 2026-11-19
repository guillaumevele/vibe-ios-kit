// FILE: AddBookView.swift
import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = 320
    @State private var isFavorite = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Author", text: $author)
                        .textInputAutocapitalization(.words)
                    Stepper(value: $totalPages, in: 1...20000, step: 10) {
                        Text("Total pages: \(totalPages)")
                    }
                    Toggle(isOn: $isFavorite) {
                        Label("Favourite", systemImage: "star.fill")
                    }
                    .tint(.yellow)
                }
            }
            .navigationTitle("New Book")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addBook() }
                        .bold()
                        .disabled(!isValid)
                }
            }
        }
    }

    private func addBook() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: totalPages,
            isFavorite: isFavorite
        )
        modelContext.insert(book)
        dismiss()
    }
}
