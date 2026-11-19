Here's the complete app — SwiftUI + SwiftData (persisted to disk, so the list survives relaunches), with categories, check-off, swipe/context-menu delete, and category management. Set the deployment target to iOS 26 in Xcode.

```swift
// FILE: GroceryListApp.swift
import SwiftUI
import SwiftData

@main
struct GroceryListApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([Category.self, GroceryItem.self])
        do {
            // The default configuration stores data on disk, so the
            // grocery list is saved between launches.
            modelContainer = try ModelContainer(for: schema)
        } catch {
            // Fall back to an in-memory store if the disk store can't be opened.
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

```swift
// FILE: ColorHex.swift
import SwiftUI

extension Color {
    /// Creates a color from a hex string such as `"#34C759"`, `"34C759"`,
    /// or an 8-digit `"FF34C759"` (alpha last).
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if cleaned.count == 3 {
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        }

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        if cleaned.count >= 8 {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        } else {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
```

```swift
// FILE: Category.swift
import SwiftUI
import SwiftData

@Model
final class Category {
    var name: String
    var symbolName: String
    var colorHex: String
    var sortOrder: Int

    // Deleting a category also deletes all of its items.
    @Relationship(deleteRule: .cascade, inverse: \GroceryItem.category)
    var items: [GroceryItem]?

    init(name: String, symbolName: String = "cart", colorHex: String = "#007AFF", sortOrder: Int = 0) {
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.items = []
    }

    var color: Color { Color(hex: colorHex) }

    var itemCount: Int { items?.count ?? 0 }

    var remainingCount: Int { (items ?? []).filter { !$0.isChecked }.count }

    /// SF Symbols offered when creating a category.
    static let symbolOptions: [String] = [
        "cart", "leaf", "carrot", "fish", "egg",
        "cup.and.saucer", "snowflake", "birthday.cake",
        "cabinet", "basket", "takeoutbag.and.cup.and.straw", "drop"
    ]

    /// Preset colors offered when creating a category (stored as hex).
    static let colorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#8E8E93", "#A2845E"
    ]
}
```

```swift
// FILE: GroceryItem.swift
import Foundation
import SwiftData

@Model
final class GroceryItem {
    var name: String
    var isChecked: Bool
    var addedAt: Date
    var sortOrder: Int

    @Relationship(inverse: \Category.items)
    var category: Category?

    init(name: String, category: Category? = nil, sortOrder: Int = 0) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isChecked = false
        self.addedAt = Date()
        self.sortOrder = sortOrder
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

    @State private var showAddItem = false
    @State private var showManageCategories = false
    @AppStorage("com.grocerylist.hasSeededDefaults") private var hasSeededDefaults = false

    private var allItems: [GroceryItem] {
        categories.flatMap { $0.items ?? [] }
    }

    private var remainingCount: Int {
        allItems.filter { !$0.isChecked }.count
    }

    private var subtitle: String {
        let total = allItems.count
        if total == 0 { return "Tap + to add your first item" }
        if remainingCount == 0 { return "All \(total) items checked off" }
        return "\(remainingCount) of \(total) remaining"
    }

    /// Categories with their items sorted so unchecked items come first.
    private var grouped: [(category: Category, items: [GroceryItem])] {
        categories.map { category in
            let items = (category.items ?? []).sorted { lhs, rhs in
                (lhs.isChecked, lhs.sortOrder) < (rhs.isChecked, rhs.sortOrder)
            }
            return (category, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.category) { group in
                    Section {
                        ForEach(group.items) { item in
                            GroceryItemRow(item: item) {
                                toggle(item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    toggle(item)
                                } label: {
                                    Label(
                                        item.isChecked ? "Mark as not bought" : "Mark as bought",
                                        systemImage: item.isChecked ? "circle" : "checkmark.circle.fill"
                                    )
                                }
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        CategorySectionHeader(category: group.category)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Groceries")
            .navigationSubtitle(subtitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Check off all", systemImage: "checkmark.circle") {
                            setAll(checked: true)
                        }
                        Button("Uncheck all", systemImage: "circle") {
                            setAll(checked: false)
                        }
                        Divider()
                        Button("Delete checked items", role: .destructive, systemImage: "trash") {
                            deleteChecked()
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showManageCategories = true
                    } label: {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }
                    Button {
                        showAddItem = true
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $showManageCategories) {
                ManageCategoriesView()
            }
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView {
                        Label("No categories yet", systemImage: "cart")
                    } description: {
                        Text("Add a category, then fill it with groceries.")
                    } actions: {
                        Button("Add category") { showManageCategories = true }
                    }
                }
            }
            .onAppear(perform: seedDefaultsIfNeeded)
        }
    }

    private func toggle(_ item: GroceryItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            item.isChecked.toggle()
        }
    }

    private func delete(_ item: GroceryItem) {
        withAnimation(.default) {
            modelContext.delete(item)
        }
    }

    private func deleteChecked() {
        withAnimation(.default) {
            for item in allItems where item.isChecked {
                modelContext.delete(item)
            }
        }
    }

    private func setAll(checked: Bool) {
        withAnimation(.default) {
            for item in allItems {
                item.isChecked = checked
            }
        }
    }

    /// Seeds a starter set of categories and items on first launch only.
    private func seedDefaultsIfNeeded() {
        guard !hasSeededDefaults else { return }
        hasSeededDefaults = true

        let defaults: [(name: String, symbol: String, hex: String, items: [String])] = [
            ("Produce", "leaf", "#34C759", ["Bananas", "Baby spinach", "Avocados"]),
            ("Dairy & Eggs", "egg", "#FFCC00", ["Whole milk", "Free-range eggs", "Greek yogurt"]),
            ("Bakery", "birthday.cake", "#FF9500", ["Sourdough loaf"]),
            ("Meat & Seafood", "fish", "#FF3B30", ["Salmon fillets"]),
            ("Pantry", "cabinet", "#8E8E93", ["Olive oil", "Pasta", "Rice", "Canned tomatoes"]),
            ("Frozen", "snowflake", "#007AFF", ["Frozen blueberries"]),
            ("Beverages", "cup.and.saucer", "#A2845E", ["Coffee beans"])
        ]

        for (index, entry) in defaults.enumerated() {
            let category = Category(
                name: entry.name,
                symbolName: entry.symbol,
                colorHex: entry.hex,
                sortOrder: index
            )
            modelContext.insert(category)
            for (itemIndex, itemName) in entry.items.enumerated() {
                modelContext.insert(GroceryItem(name: itemName, category: category, sortOrder: itemIndex))
            }
        }
    }
}

// MARK: - Row

private struct GroceryItemRow: View {
    let item: GroceryItem
    let onToggle: () -> Void

    private var accent: Color {
        item.category?.color ?? .accentColor
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isChecked ? .green : accent)
                Text(item.name)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .animation(.default, value: item.isChecked)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section header

private struct CategorySectionHeader: View {
    let category: Category

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.symbolName)
                .font(.subheadline)
                .foregroundStyle(category.color)
            Text(category.name)
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
            Spacer()
            if category.remainingCount > 0 {
                Text("\(category.remainingCount) left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            } else if category.itemCount > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
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
```

```swift
// FILE: AddCategoryView.swift
import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var name = ""
    @State private var symbolName = Category.symbolOptions[0]
    @State private var colorHex = Category.colorOptions[3]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Snacks", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                        ForEach(Category.symbolOptions, id: \.self) { symbol in
                            Button {
                                symbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title2)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        symbolName == symbol ? Color.accentColor.opacity(0.18) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(symbolName == symbol ? Color.accentColor : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(Category.colorOptions, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .bold()
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("New Category")
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
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let sortOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(Category(
            name: trimmedName,
            symbolName: symbolName,
            colorHex: colorHex,
            sortOrder: sortOrder
        ))
        dismiss()
    }
}
```

```swift
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
```