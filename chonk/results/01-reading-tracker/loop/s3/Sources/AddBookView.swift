// FILE: AddBookView.swift
import SwiftUI

struct AddBookView: View {
    let onSave: (BookDraft) async -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var author: String
    @State private var totalPages: Int
    @State private var pagesRead: Int

    init(
        draft: BookDraft,
        onSave: @escaping (BookDraft) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: draft.title)
        _author = State(initialValue: draft.author)
        _totalPages = State(initialValue: draft.totalPages)
        _pagesRead = State(initialValue: draft.pagesRead)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && totalPages >= 1
            && pagesRead >= 0
            && pagesRead <= totalPages
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                }
                Section("Progress") {
                    TextField("Total pages", value: $totalPages, format: .number)
                    TextField("Pages already read", value: $pagesRead, format: .number)
                }
            }
            .navigationTitle("New book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var draft = BookDraft()
                        draft.title = title
                        draft.author = author
                        draft.totalPages = totalPages
                        draft.pagesRead = pagesRead
                        Task { await onSave(draft) }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
