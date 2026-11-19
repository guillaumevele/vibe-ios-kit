// FILE: CategoryManagerView.swift
import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var editorTarget: Category?
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button {
                        editorTarget = category
                        showingEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.symbolName)
                                .foregroundStyle(category.color.color)
                                .frame(width: 26)
                            Text(category.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(category.uncheckedCount) left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(category)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTarget = nil
                        showingEditor = true
                    } label: {
                        Label("Add category", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                CategoryEditorView(existing: editorTarget)
            }
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView(
                        "No categories",
                        systemImage: "folder",
                        description: Text("Tap + to create your first category.")
                    )
                }
            }
        }
    }

    /// Deleting a category cascades to its items (see the relationship delete rule).
    private func delete(_ category: Category) {
        withAnimation {
            modelContext.delete(category)
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
    }
}
