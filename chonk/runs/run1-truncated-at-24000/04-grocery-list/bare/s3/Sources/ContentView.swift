// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \GroceryItem.createdAt) private var items: [GroceryItem]

    @State private var isShowingAddItem = false
    @State private var isShowingCategories = false

    private let seedFlagKey = "com.grocerylist.didSeedDefaultCategories"

    private var remainingCount: Int {
        items.filter { !$0.isChecked }.count
    }

    private var uncategorizedItems: [GroceryItem] {
        items.filter { $0.category == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Section {
                        ForEach(items(in: category)) { item in
                            ItemRow(item: item)
                        }
                        .onDelete { offsets in
                            deleteItems(in: category, at: offsets)
                        }
                    } header: {
                        Text(category.name)
                    }
                }

                if !uncategorizedItems.isEmpty {
                    Section {
                        ForEach(uncategorizedItems) { item in
                            ItemRow(item: item)
                        }
                        .onDelete(perform: deleteUncategorized)
                    } header: {
                        Text("Uncategorized")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Groceries")
            .navigationSubtitle("\(remainingCount) of \(items.count) remaining")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingCategories = true
                    } label: {
                        Label("Categories", systemImage: "folder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddItem = true
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Your list is empty",
                        systemImage: "cart",
                        description: Text("Tap the + button to add your first grocery.")
                    )
                }
            }
            .sheet(isPresented: $isShowingAddItem) {
                AddItemView(categories: categories)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isShowingCategories) {
                CategoryManagerView()
            }
            .onAppear(perform: seedDefaultCategoriesIfNeeded)
        }
    }

    /// Items belonging to a category, in the order they were added.
    private func items(in category: Category) -> [GroceryItem] {
        items.filter { $0.category == category }
    }

    private func deleteItems(in category: Category, at offsets: IndexSet) {
        let list = items(in: category)
        for index in offsets {
            modelContext.delete(list[index])
        }
    }

    private func deleteUncategorized(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(uncategorizedItems[index])
        }
    }

    /// On first launch only, pre-populate a sensible set of categories.
    private func seedDefaultCategoriesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: seedFlagKey) else { return }
        UserDefaults.standard.set(true, forKey: seedFlagKey)
        guard categories.isEmpty else { return }

        let defaults = [
            "Produce", "Dairy & Eggs", "Bakery", "Meat & Seafood",
            "Pantry", "Frozen", "Beverages", "Household"
        ]
        for (index, name) in defaults.enumerated() {
            modelContext.insert(Category(name: name, sortOrder: index))
        }
    }
}
