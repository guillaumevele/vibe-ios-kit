// FILE: AddItemView.swift
import Foundation
import SwiftUI

struct AddItemSheet: Identifiable, Sendable {
    let id = UUID()
}

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: GroceryCategory = .produce

    let onAdd: (String, GroceryCategory) async -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Item name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(GroceryCategory.allCases) { option in
                            Label(option.title, systemImage: option.symbolName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
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
                        Task {
                            await onAdd(name, category)
                            dismiss()
                        }
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
