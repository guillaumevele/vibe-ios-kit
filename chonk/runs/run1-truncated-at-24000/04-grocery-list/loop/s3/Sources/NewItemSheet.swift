// FILE: NewItemSheet.swift
import SwiftUI

struct NewItemDraft: Identifiable {
    let id = UUID()
}

struct NewItemSheet: View {
    let model: GroceryListModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: GroceryCategory = .produce
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("New item")
                .navigationBarTitleDisplayMode(.inline)
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
                        .disabled(trimmedName.isEmpty)
                    }
                }
        }
        .task {
            isNameFocused = true
        }
    }

    private var form: some View {
        Form {
            Section("Item name") {
                TextField("Milk", text: $name)
                    .focused($isNameFocused)
            }
            Section("Category") {
                Picker("Category", selection: $category) {
                    ForEach(GroceryCategory.all) { option in
                        Label(option.name, systemImage: option.symbolName)
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }

    private func add() {
        model.add(name: name, category: category)
        dismiss()
    }
}
