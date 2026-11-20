// FILE: AddItemView.swift
import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var name = ""
    @State private var selectedCategory: Category?
    @State private var showAddCategory = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    ContentUnavailableView {
                        Label("No categories yet", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Create a category first, then add items to it.")
                    } actions: {
                        Button("New category") { showAddCategory = true }
                    }
                } else {
                    Form {
                        Section("Item") {
                            TextField("e.g. Bananas", text: $name)
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.done)
                                .onSubmit(save)
                        }
                        Section("Category") {
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(categories) { category in
                                    Label(category.name, systemImage: category.symbolName)
                                        .tag(category as Category?)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                    }
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .bold()
                        .disabled(trimmedName.isEmpty)
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView()
            }
            .onAppear {
                if selectedCategory == nil {
                    selectedCategory = categories.first
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty, let category = selectedCategory ?? categories.first else { return }
        let nextOrder = ((category.items ?? []).map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(GroceryItem(name: trimmedName, category: category, sortOrder: nextOrder))
        dismiss()
    }
}
