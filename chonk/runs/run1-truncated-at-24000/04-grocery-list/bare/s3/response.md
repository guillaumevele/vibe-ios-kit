Here's a complete SwiftUI + SwiftData grocery list app (SwiftData persists everything to disk automatically, so the list survives relaunches). Create these six files in your Xcode project, set the deployment target to iOS 26, and run:

```swift
// FILE: GroceryListApp.swift
import SwiftUI
import SwiftData

@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // On-disk model container: all data is saved between launches automatically.
        .modelContainer(for: [Category.self, GroceryItem.self])
    }
}
```

```swift
// FILE: Models.swift
import Foundation
import SwiftData

/// A group that grocery items belong to (e.g. "Produce", "Dairy & Eggs").
@Model
final class Category {
    var name: String
    var sortOrder: Int
    var createdAt: Date

    /// Items in this category. Deleting a category nullifies this link,
    /// so its items become "Uncategorized" instead of being deleted.
    @Relationship(inverse: \GroceryItem.category)
    var items: [GroceryItem] = []

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

/// A single grocery list entry.
@Model
final class GroceryItem {
    var name: String
    var quantity: String
    var isChecked: Bool
    var createdAt: Date
    var category: Category?

    init(name: String, quantity: String = "", category: Category? = nil) {
        self.name = name
        self.quantity = quantity
        self.isChecked = false
        self.createdAt = Date()
        self.category = category
    }
}
```

```swift
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
```

```swift
// FILE: ItemRow.swift
import SwiftUI
import SwiftData

struct ItemRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: GroceryItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    item.isChecked.toggle() // persisted automatically by SwiftData
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isChecked ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Uncheck \(item.name)" : "Check off \(item.name)")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation {
                    item.isChecked.toggle()
                }
            } label: {
                Label(
                    item.isChecked ? "Uncheck" : "Check off",
                    systemImage: item.isChecked ? "circle" : "checkmark.circle"
                )
            }
            .tint(item.isChecked ? .orange : .green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
```

```swift
// FILE: AddItemView.swift
import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]

    @State private var name = ""
    @State private var quantity = ""
    @State private var pickerSelection = 0
    @State private var newCategoryName = ""

    /// Picker indices: 0 = no category, 1...count = existing categories, last = "New category…"
    private var categoryOptions: [String] {
        ["None"] + categories.map(\.name) + ["New category…"]
    }

    private var isNewCategorySelected: Bool {
        pickerSelection == categoryOptions.count - 1
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (!isNewCategorySelected
            || !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name, e.g. Milk", text: $name)
                        .textInputAutocapitalization(.sentences)
                    TextField("Quantity, e.g. 2 cartons (optional)", text: $quantity)
                }

                Section("Category") {
                    Picker("Category", selection: $pickerSelection) {
                        ForEach(Array(categoryOptions.enumerated()), id: \.offset) { index, label in
                            Text(label).tag(index)
                        }
                    }
                    if isNewCategorySelected {
                        TextField("New category name", text: $newCategoryName)
                            .textInputAutocapitalization(.words)
                    }
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func addItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var category: Category?
        if pickerSelection >= 1 && pickerSelection <= categories.count {
            category = categories[pickerSelection - 1]
        } else if isNewCategorySelected {
            let trimmedCategory = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedCategory.isEmpty else { return }
            let newCategory = Category(name: trimmedCategory, sortOrder: categories.count)
            modelContext.insert(newCategory)
            category = newCategory
        }

        let item = GroceryItem(
            name: trimmedName,
            quantity: quantity.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category
        )
        modelContext.insert(item)
        dismiss()
    }
}
```

```swift
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
```

How it covers your requirements:

- **Categories** — items are grouped into `Section`s per `Category`; you can create new categories from the Add Item sheet and reorder/delete them in the Categories sheet (deleting a category moves its items to "Uncategorized" rather than deleting them).
- **Check-off** — tap the circle on a row (or swipe right) to toggle; checked items get a strikethrough and dim, with a live "x of y remaining" subtitle.
- **Delete** — swipe left on any row (full swipe works too) to remove the item.
- **Saved between launches** — everything lives in SwiftData models in an on-disk `modelContainer`; check-offs, additions, deletions, and category order all persist automatically with no manual saving.