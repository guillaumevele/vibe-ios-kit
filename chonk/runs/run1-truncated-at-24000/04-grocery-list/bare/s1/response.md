Here's a complete SwiftUI grocery list app targeting iOS 26, using SwiftData (Apple's built-in persistence framework) so everything is saved between launches automatically. It includes categories (with custom icons/colors), tap or swipe to check off items, swipe/edit-mode to delete, and first-launch sample data.

```swift
// FILE: GroceryListApp.swift
// Deployment target: iOS 26.0 — SwiftUI + SwiftData only, no third-party packages.
import SwiftUI
import SwiftData

@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Default ModelContainer persists to disk, so data survives between launches.
        .modelContainer(for: [Category.self, GroceryItem.self])
    }
}
```

```swift
// FILE: Models.swift
import Foundation
import SwiftData
import SwiftUI

/// Preset accent colors a category can pick from.
enum CategoryColor: String, CaseIterable, Identifiable {
    case green, blue, orange, purple, pink, red, teal, brown

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .green:  return .green
        case .blue:   return .blue
        case .orange: return .orange
        case .purple: return .purple
        case .pink:   return .pink
        case .red:    return .red
        case .teal:   return .teal
        case .brown:  return .brown
        }
    }
}

@Model
final class Category {
    var name: String
    var symbolName: String
    var colorRaw: String
    var createdAt: Date

    // Deleting a category cascades to all of its items.
    @Relationship(deleteRule: .cascade, inverse: \GroceryItem.category)
    var items: [GroceryItem] = []

    init(name: String, symbolName: String, color: CategoryColor) {
        self.name = name
        self.symbolName = symbolName
        self.colorRaw = color.rawValue
        self.createdAt = Date()
    }

    var tint: Color {
        CategoryColor(rawValue: colorRaw)?.color ?? .blue
    }

    var uncheckedCount: Int {
        items.filter { !$0.isChecked }.count
    }
}

@Model
final class GroceryItem {
    var name: String
    var isChecked: Bool
    var createdAt: Date
    var category: Category?

    init(name: String, category: Category? = nil) {
        self.name = name
        self.isChecked = false
        self.createdAt = Date()
        self.category = category
    }
}
```

```swift
// FILE: SeedData.swift
import Foundation
import SwiftData

/// Inserts a set of starter categories/items exactly once, on first launch.
enum SeedData {
    private static let hasSeededKey = "GroceryList.hasSeededDefaultCategories"

    static func seedDefaultCategoriesIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasSeededKey) else { return }
        UserDefaults.standard.set(true, forKey: hasSeededKey)

        let definitions: [(name: String, symbol: String, color: CategoryColor, items: [String])] = [
            ("Produce",        "leaf.fill",            .green,  ["Bananas", "Spinach", "Cherry tomatoes"]),
            ("Dairy & Eggs",   "egg.fill",             .blue,   ["Milk", "Eggs", "Greek yogurt"]),
            ("Bakery",         "birthday.cake.fill",   .orange, ["Sourdough bread"]),
            ("Meat & Seafood", "fish.fill",            .red,    ["Salmon fillet"]),
            ("Pantry",         "archivebox.fill",      .brown,  ["Olive oil", "Pasta", "Rice"]),
            ("Frozen",         "snowflake",            .teal,   ["Frozen peas", "Ice cream"]),
            ("Beverages",      "cup.and.saucer.fill",  .purple, ["Coffee beans", "Orange juice"]),
            ("Household",      "sparkles",             .pink,   ["Dish soap", "Paper towels"]),
        ]

        for definition in definitions {
            let category = Category(name: definition.name,
                                    symbolName: definition.symbol,
                                    color: definition.color)
            modelContext.insert(category)
            for itemName in definition.items {
                modelContext.insert(GroceryItem(name: itemName, category: category))
            }
        }
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]

    @State private var showAddCategory = false

    private var totalItems: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }

    private var checkedItems: Int {
        categories.reduce(0) { total, category in
            total + category.items.filter(\.isChecked).count
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    ContentUnavailableView {
                        Label("No categories yet", systemImage: "cart")
                    } description: {
                        Text("Create a category to start your grocery list.")
                    } actions: {
                        Button("Add Category") {
                            showAddCategory = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("Shopping progress", systemImage: "list.bullet.clipboard")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(checkedItems) of \(totalItems) checked")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: Double(checkedItems),
                                             total: Double(max(totalItems, 1)))
                                    .tint(.green)
                            }
                            .padding(.vertical, 4)
                        }

                        Section("Categories") {
                            ForEach(categories) { category in
                                NavigationLink(value: category) {
                                    CategoryRow(category: category)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(category)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete(perform: deleteCategories)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView()
            }
            .navigationDestination(for: Category.self) { category in
                CategoryDetailView(category: category)
            }
            .task {
                SeedData.seedDefaultCategoriesIfNeeded(modelContext: modelContext)
            }
        }
    }

    private func delete(_ category: Category) {
        withAnimation {
            modelContext.delete(category)
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(categories[index])
            }
        }
    }
}

private struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.symbolName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(category.tint.gradient,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.headline)
                let total = category.items.count
                let done = total - category.uncheckedCount
                Text(total == 0 ? "No items yet" : "\(done) of \(total) picked up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if category.uncheckedCount > 0 {
                Text("\(category.uncheckedCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(category.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(category.tint.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
```

```swift
// FILE: CategoryDetailView.swift
import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let category: Category

    @State private var newItemName = ""
    @FocusState private var isInputFocused: Bool

    /// Unchecked items first, then alphabetical within each group.
    private var sortedItems: [GroceryItem] {
        category.items.sorted { lhs, rhs in
            if lhs.isChecked != rhs.isChecked {
                return !lhs.isChecked
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var trimmedNewItemName: String {
        newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                    TextField("Add an item…", text: $newItemName)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                    Button {
                        addItem()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(trimmedNewItemName.isEmpty ? .secondary : category.tint)
                    }
                    .disabled(trimmedNewItemName.isEmpty)
                    .buttonStyle(.plain)
                }
            }

            Section {
                ForEach(sortedItems) { item in
                    ItemRow(item: item)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                toggle(item)
                            } label: {
                                Label(item.isChecked ? "Uncheck" : "Check",
                                      systemImage: item.isChecked ? "circle" : "checkmark.circle.fill")
                            }
                            .tint(item.isChecked ? .orange : .green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                }
                .onDelete(perform: deleteItems)
            } header: {
                Text("\(category.uncheckedCount) remaining")
            } footer: {
                if sortedItems.isEmpty {
                    Text("No items yet — add your first one above.")
                }
            }
        }
        .tint(category.tint)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(category.name)
        .navigationSubtitle("\(category.items.count) items")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    clearChecked()
                } label: {
                    Label("Clear Checked", systemImage: "trash")
                }
                .disabled(category.items.allSatisfy { !$0.isChecked })
            }
        }
    }

    private func addItem() {
        guard !trimmedNewItemName.isEmpty else { return }
        let item = GroceryItem(name: trimmedNewItemName, category: category)
        withAnimation {
            modelContext.insert(item)
        }
        newItemName = "" // keyboard stays focused for rapid entry
    }

    private func toggle(_ item: GroceryItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            item.isChecked.toggle()
        }
    }

    private func delete(_ item: GroceryItem) {
        withAnimation {
            modelContext.delete(item)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sortedItems[index])
            }
        }
    }

    private func clearChecked() {
        withAnimation {
            for item in category.items where item.isChecked {
                modelContext.delete(item)
            }
        }
    }
}

private struct ItemRow: View {
    @Bindable var item: GroceryItem

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                item.isChecked.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                    .symbolEffect(.bounce, value: item.isChecked)
                Text(item.name)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked, color: .secondary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: item.isChecked)
    }
}
```

```swift
// FILE: AddCategoryView.swift
import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedSymbol = "cart.fill"
    @State private var selectedColor: CategoryColor = .green

    private let symbols = [
        "cart.fill", "basket.fill", "leaf.fill", "carrot.fill",
        "egg.fill", "fish.fill", "birthday.cake.fill", "archivebox.fill",
        "snowflake", "cup.and.saucer.fill", "mug.fill", "sparkles"
    ]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Produce", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6),
                              spacing: 10) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button {
                                selectedSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .foregroundStyle(selectedSymbol == symbol ? .white : .primary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selectedSymbol == symbol
                                                  ? selectedColor.color
                                                  : Color.secondary.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    HStack(spacing: 14) {
                        ForEach(CategoryColor.allCases) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color.color.gradient)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let category = Category(name: trimmedName,
                                symbolName: selectedSymbol,
                                color: selectedColor)
        modelContext.insert(category)
        dismiss()
    }
}
```

**How it works:**
- **Persistence** — SwiftData's default `ModelContainer` writes to disk automatically; check-offs, additions, and deletions survive relaunches with no extra code.
- **Categories** — seeded on first launch (guarded by a `UserDefaults` flag so they don't reappear after you delete them), and you can add your own with a custom SF Symbol icon and color. Deleting a category cascades to its items.
- **Check-off** — tap a row, or swipe right on it; checked items get a strikethrough, bounce animation, and haptic feedback, and sort below unchecked ones.
- **Delete** — swipe left on an item or category, use Edit mode, or "Clear Checked" in the bottom (Liquid Glass) toolbar.
- **iOS 26** — uses `NavigationStack` value-based navigation, `ContentUnavailableView`, `symbolEffect`, `sensoryFeedback`, and the system glass toolbars available on iOS 26.