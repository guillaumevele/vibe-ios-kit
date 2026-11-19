// FILE: AddItemView.swift
import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var category: GroceryCategory = .produce
    @State private var notes = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("e.g. Bananas", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)

                    Picker("Category", selection: $category) {
                        ForEach(GroceryCategory.allCases) { option in
                            Label(option.rawValue, systemImage: option.symbolName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                    }
                    .disabled(trimmedName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = GroceryItem(
            name: trimmedName,
            category: category,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
