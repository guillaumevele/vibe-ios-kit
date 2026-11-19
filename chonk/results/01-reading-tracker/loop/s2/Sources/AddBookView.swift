// FILE: AddBookView.swift
import SwiftUI

struct AddBookView: View {
    @Bindable var draft: BookDraft
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("New book") {
                    TextField("Title", text: $draft.title)
                    TextField("Author", text: $draft.author)
                    TextField("Total pages", text: $draft.totalPagesText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }
}

#Preview("Add book") {
    AddBookView(draft: BookDraft()) { }
}
