// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \GroceryItem.createdAt) private var allItems: [GroceryItem]

    @State private var searchText = ""
    @State private var showingAddItem = false
    @State private var showingCategoryManager = false

    var body: some View {
        NavigationStack {
            list
                .navigationTitle("Groceries")
                .navigationSubtitle(subtitle)
                .searchable(text: $searchText, prompt: "Search your list")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button("Manage categories", systemImage: "folder") {
                                showingCategoryManager = true
                            }
                            Divider()
                            Button("Check off everything", systemImage: "checkmark.circle") {
                                setAllChecked(true)
                            }
                            Button("Uncheck everything", systemImage: "circle") {
                                setAllChecked(false)
                            }
                            Button("Remove checked items", systemImage: "trash", role: .destructive) {
                                removeCheckedItems()
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }

                        Button {
                            showingAddItem = true
                        } label: {
                            Label("Add item", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddItem) {
                    AddItemView()
                }
                .sheet(isPresented: $showingCategoryManager) {
                    CategoryManagerView()
                }
                .overlay {
                    if categories.isEmpty && uncategorizedItems.isEmpty {
                        ContentUnavailableView(
                            "Your list is empty",
                            systemImage: "cart",
                            description: Text("Tap + to add your first item, or create a category from the menu.")
                        )
                    }
                }
        }
    }

    private var list: some View {
        List {
            ForEach(visibleCategories) { category in
                Section {
                    ForEach(sortedItems(in: category)) { item in
                        ItemRow(item: item)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    toggle(item)
                                } label: {
                                    Label(item.isChecked ? "Uncheck" : "Check off",
                                          systemImage: item.isChecked ? "circle" : "checkmark.circle.fill")
                                }
                                .tint(item.isChecked ? .orange : .green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(item.isChecked ? "Uncheck" : "Check off",
                                       systemImage: item.isChecked ? "circle" : "checkmark.circle") {
                                    toggle(item)
                                }
                                if !categories.isEmpty {
                                    Section("Move to") {
                                        ForEach(categories) { destination in
                                            Button {
                                                item.category = destination
                                            } label: {
                                                Label(destination.name, systemImage: destination.symbolName)
                                            }
                                        }
                                    }
                                }
                            }
                    }
                } header: {
                    CategoryHeaderView(category: category)
                }
            }

            let uncategorized = uncategorizedItems
            if !uncategorized.isEmpty {
                Section("Uncategorized") {
                    ForEach(uncategorized) { item in
                        ItemRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Derived data

    private var visibleCategories: [Category] {
        if searchText.isEmpty { return categories }
        return categories.filter { !sortedItems(in: $0).isEmpty }
    }

    private var uncategorizedItems: [GroceryItem] {
        allItems
            .filter { $0.category == nil }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { lhs, rhs in
                if lhs.isChecked != rhs.isChecked { return !lhs.isChecked }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// Unchecked items first, then alphabetical.
    private func sortedItems(in category: Category) -> [GroceryItem] {
        let items = category.items ?? []
        let filtered = searchText.isEmpty
            ? items
            : items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted { lhs, rhs in
            if lhs.isChecked != rhs.isChecked { return !lhs.isChecked }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var subtitle: String {
        guard !allItems.isEmpty else { return "Nothing on your list yet" }
        let done = allItems.filter(\.isChecked).count
        return "\(done) of \(allItems.count) checked off"
    }

    // MARK: - Actions

    private func toggle(_ item: GroceryItem) {
        withAnimation(.spring(response: 0.25)) {
            item.isChecked.toggle()
        }
    }

    private func delete(_ item: GroceryItem) {
        withAnimation {
            modelContext.delete(item)
        }
    }

    private func setAllChecked(_ checked: Bool) {
        for item in allItems where item.isChecked != checked {
            item.isChecked = checked
        }
    }

    private func removeCheckedItems() {
        for item in allItems where item.isChecked {
            modelContext.delete(item)
        }
    }
}
