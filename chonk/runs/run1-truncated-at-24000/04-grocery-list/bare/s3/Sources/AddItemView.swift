// FILE: AddItemView.swift
import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]

    @State private var name = ""
    @State private var quantity = ""
    @State private var pickerSelection = 0
    @State private var newCategoryName = ""

    /// Picker indices: 0 = no category, 1...count = existing categories, last = "New category…"
    private var categoryOptions: [String] {
        ["None"] + categories.map(\.name) + ["New category…"]
    }

    private var isNewCategorySelected: Bool {
        pickerSelection == categoryOptions.count - 1
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (!isNewCategorySelected
            || !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name, e.g. Milk", text: $name)
                        .textInputAutocapitalization(.sentences)
                    TextField("Quantity, e.g. 2 cartons (optional)", text: $quantity)
                }

                Section("Category") {
                    Picker("Category", selection: $pickerSelection) {
                        ForEach(Array(categoryOptions.enumerated()), id: \.offset) { index, label in
                            Text(label).tag(index)
                        }
                    }
                    if isNewCategorySelected {
                        TextField("New category name", text: $newCategoryName)
                            .textInputAutocapitalization(.words)
                    }
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func addItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var category: Category?
        if pickerSelection >= 1 && pickerSelection <= categories.count {
            category = categories[pickerSelection - 1]
        } else if isNewCategorySelected {
            let trimmedCategory = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedCategory.isEmpty else { return }
            let newCategory = Category(name: trimmedCategory, sortOrder: categories.count)
            modelContext.insert(newCategory)
            category = newCategory
        }

        let item = GroceryItem(
            name: trimmedName,
            quantity: quantity.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category
        )
        modelContext.insert(item)
        dismiss()
    }
}
