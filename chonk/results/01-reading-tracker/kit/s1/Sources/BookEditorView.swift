// FILE: BookEditorView.swift
import SwiftUI

struct BookEditorView: View {
    let store: BookStore
    let existing: Book?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: BookDraft
    @State private var showingError = false
    @State private var errorMessage = ""

    init(store: BookStore, existing: Book?) {
        self.store = store
        self.existing = existing
        _draft = State(initialValue: existing.map { BookDraft(book: $0) } ?? BookDraft())
    }

    private var pagesReadBinding: Binding<Double> {
        Binding(
            get: { Double(draft.pagesRead) },
            set: { draft.pagesRead = min(draft.totalPages, max(0, Int($0.rounded()))) }
        )
    }

    private var percentRead: Int {
        guard draft.totalPages > 0 else { return 0 }
        return Int((Double(draft.pagesRead) / Double(draft.totalPages) * 100).rounded())
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $draft.title)
                TextField("Author", text: $draft.author)
            }

            Section("Progress") {
                Stepper(value: $draft.totalPages, in: 1...9999) {
                    Text("Total pages: \(draft.totalPages)")
                }
                .onChange(of: draft.totalPages) { _, newValue in
                    if draft.pagesRead > newValue {
                        draft.pagesRead = newValue
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Slider(value: pagesReadBinding, in: 0...Double(draft.totalPages), step: 1) {
                        Text("Pages read")
                    }
                    HStack {
                        Text("Pages read: \(draft.pagesRead)")
                        Spacer()
                        Text("\(percentRead)%")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if draft.pagesRead >= draft.totalPages {
                    Label("All pages read", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
            }

            Section {
                Toggle("Favourite", isOn: $draft.isFavourite)
            }
        }
        .navigationTitle(existing == nil ? "New book" : "Edit book")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(!draft.isValid)
            }
        }
        .alert("Couldn't save the book", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {
                errorMessage = ""
            }
        } message: { message in
            Text(message)
        }
    }

    private func save() async {
        do {
            try await store.save(draft, editing: existing)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    NavigationStack {
        BookEditorView(
            store: BookStore(repository: InMemoryBookRepository(books: Book.samples)),
            existing: Book.samples[0]
        )
    }
}
