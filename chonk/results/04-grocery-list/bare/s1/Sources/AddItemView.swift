// FILE: AddItemView.swift
import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var name = ""
    @State private var selectedCategory: Category?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("e.g. Milk", text: $name)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { if isValid { addItem() } }
                }

                Section("Category") {
                    if categories.isEmpty {
                        Text("Create a category first from the main screen's menu.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categories) { category in
                                Label(category.name, systemImage: category.symbolName)
                                    .tag(category as Category?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .bold()
                        .disabled(!isValid)
                }
            }
            .onAppear {
                selectedCategory = categories.first
                isFocused = true
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addItem() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(GroceryItem(name: trimmed, category: selectedCategory))
        try? modelContext.save()
        dismiss()
    }
}
