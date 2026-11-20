// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Unchecked items first, then oldest first.
    @Query(sort: [
        SortDescriptor(\GroceryItem.isChecked),
        SortDescriptor(\GroceryItem.createdAt)
    ])
    private var allItems: [GroceryItem]

    @State private var searchText = ""
    @State private var isPresentingEditor = false
    @State private var itemBeingEdited: GroceryItem?

    private var visibleItems: [GroceryItem] {
        if searchText.isEmpty { return allItems }
        return allItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var sections: [CategorySection] {
        let grouped = Dictionary(grouping: visibleItems, by: { $0.category })
        return Category.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return CategorySection(category: category, items: items)
        }
    }

    private var checkedCount: Int { visibleItems.filter(\.isChecked).count }
    private var totalCheckedCount: Int { allItems.filter(\.isChecked).count }

    var body: some View {
        NavigationStack {
            List {
                if !visibleItems.isEmpty {
                    Section {
                        ProgressHeaderView(done: checkedCount, total: visibleItems.count)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowBackground(Color.clear)
                    }
                }

                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            ItemRow(item: item) {
                                toggle(item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggle(item)
                                } label: {
                                    Label(
                                        item.isChecked ? "Uncheck" : "Check",
                                        systemImage: item.isChecked ? "circle" : "checkmark.circle.fill"
                                    )
                                }
                                .tint(.green)
                            }
                            .contextMenu {
                                Button {
                                    itemBeingEdited = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Menu {
                                    ForEach(Category.allCases) { category in
                                        Button {
                                            withAnimation { item.category = category }
                                        } label: {
                                            Label(
                                                category.rawValue,
                                                systemImage: item.category == category ? "checkmark" : category.symbol
                                            )
                                        }
                                    }
                                } label: {
                                    Label("Move to…", systemImage: "folder")
                                }
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        CategorySectionHeader(
                            category: section.category,
                            remaining: section.items.filter { !$0.isChecked }.count
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Groceries")
            .searchable(text: $searchText, prompt: "Search groceries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if totalCheckedCount > 0 {
                        Button("Clear Checked", role: .destructive) {
                            clearChecked()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if allItems.isEmpty {
                    ContentUnavailableView {
                        Label("Your list is empty", systemImage: "cart")
                    } description: {
                        Text("Tap the + button to add your first grocery item.")
                    } actions: {
                        Button("Add Item") {
                            isPresentingEditor = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if visibleItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                ItemEditorView()
            }
            .sheet(item: $itemBeingEdited) { item in
                ItemEditorView(item: item)
            }
        }
    }

    private func toggle(_ item: GroceryItem) {
        withAnimation(.snappy(duration: 0.25)) {
            item.isChecked.toggle()
        }
    }

    private func delete(_ item: GroceryItem) {
        if itemBeingEdited === item { itemBeingEdited = nil }
        withAnimation(.easeInOut) {
            modelContext.delete(item)
        }
    }

    private func clearChecked() {
        withAnimation {
            for item in allItems where item.isChecked {
                modelContext.delete(item)
            }
        }
    }
}

/// A category plus the items currently shown in its section.
private struct CategorySection: Identifiable {
    let category: Category
    let items: [GroceryItem]
    var id: String { category.id }
}
