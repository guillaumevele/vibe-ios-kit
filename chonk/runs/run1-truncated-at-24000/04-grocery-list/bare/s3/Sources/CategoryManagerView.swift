// FILE: CategoryManagerView.swift
import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    HStack {
                        Text(category.name)
                        Spacer()
                        Text("\(category.items.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteCategories)
                .onMove(perform: moveCategories)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton() // enables swipe-to-delete and drag-to-reorder
                }
            }
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView(
                        "No categories",
                        systemImage: "folder",
                        description: Text("Create one from the New Item screen.")
                    )
                }
            }
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        // Items in a deleted category become "Uncategorized" (nullify delete rule).
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index // persisted; the @Query re-sorts the list
        }
    }
}
