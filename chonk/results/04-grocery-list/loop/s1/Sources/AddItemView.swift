// FILE: AddItemView.swift
import SwiftUI
import Foundation

struct AddItemView: View {
    let model: GroceryListModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var newCategoryName = ""
    @State private var isNewCategory = false
    @State private var selectedCategoryID: UUID?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCategoryName: String {
        newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        guard !trimmedName.isEmpty else { return false }
        if isNewCategory {
            return !trimmedCategoryName.isEmpty
        }
        return selectedCategoryID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Milk", text: $name)
                }
                Section("Category") {
                    if isNewCategory || model.categories.isEmpty {
                        TextField("Produce", text: $newCategoryName)
                    } else {
                        Picker("Category", selection: $selectedCategoryID) {
                            ForEach(model.categories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .pickerStyle(.menu)
                        Button("New category") {
                            isNewCategory = true
                        }
                    }
                }
            }
            .navigationTitle("New item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        add()
                    }
                    .disabled(!canAdd)
                }
            }
            .task {
                if model.categories.isEmpty {
                    isNewCategory = true
                }
                if selectedCategoryID == nil {
                    selectedCategoryID = model.categories.first?.id
                }
            }
        }
    }

    private func add() {
        Task {
            await model.addItem(
                name: trimmedName,
                categoryID: isNewCategory ? nil : selectedCategoryID,
                newCategoryName: isNewCategory ? trimmedCategoryName : nil
            )
            dismiss()
        }
    }
}
