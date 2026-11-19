// FILE: ItemEditorView.swift
import SwiftUI
import SwiftData

/// Sheet for adding a new item or editing an existing one.
struct ItemEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: Category

    private let item: GroceryItem?

    init(item: GroceryItem? = nil) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _category = State(initialValue: item?.category ?? .other)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Bananas", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit {
                            if canSave { save() }
                        }
                } header: {
                    Text(item == nil ? "New item" : "Edit item")
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { option in
                            Label {
                                Text(option.rawValue)
                            } icon: {
                                Image(systemName: option.symbol)
                                    .foregroundStyle(option.color)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle(item == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(item == nil ? "Add" : "Save") {
                        save()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        if let item {
            item.name = trimmedName
            item.category = category
        } else {
            modelContext.insert(GroceryItem(name: trimmedName, category: category))
        }
        dismiss()
    }
}
