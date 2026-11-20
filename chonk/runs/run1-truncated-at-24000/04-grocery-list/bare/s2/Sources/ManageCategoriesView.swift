// FILE: ManageCategoriesView.swift
import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showAddCategory = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                            Text(summary(for: category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: category.symbolName)
                            .foregroundStyle(category.color)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(category)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(category)
                        } label: {
                            Label("Delete category", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add category", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView()
            }
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView {
                        Label("No categories", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Add a category to start organizing your groceries.")
                    } actions: {
                        Button("New category") { showAddCategory = true }
                    }
                }
            }
        }
    }

    private func summary(for category: Category) -> String {
        let total = category.itemCount
        let remaining = category.remainingCount
        if total == 0 { return "Empty" }
        if remaining == 0 { return "All \(total) checked off" }
        return "\(remaining) of \(total) remaining"
    }

    private func delete(_ category: Category) {
        withAnimation(.default) {
            // The cascade delete rule removes the category's items too.
            modelContext.delete(category)
        }
    }
}
