// FILE: AddItemView.swift
import SwiftUI

struct AddItemView: View {
    let viewModel: GroceryListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var category: Category = .pantry

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $name)
                        .font(.body)
                } header: {
                    Text("Item")
                }
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { option in
                            Label(option.title, systemImage: option.symbolName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Category")
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await viewModel.add(name: name, category: category)
                            dismiss()
                        }
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
