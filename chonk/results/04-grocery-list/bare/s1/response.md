Here's a complete SwiftUI grocery list app targeting iOS 26. Data is persisted with SwiftData (Apple's on-device store), so categories and check-off state survive relaunches. It uses a few iOS 26-only APIs (`.glassEffect`, `.buttonStyle(.glass)`) for the Liquid Glass look.

```swift
// FILE: GroceryApp.swift
import SwiftUI
import SwiftData

/// Deployment target: iOS 26
@main
struct GroceryApp: App {
    /// SwiftData container backed by on-disk storage — the list is saved between launches.
    let container: ModelContainer

    init() {
        let schema = Schema([Category.self, GroceryItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        seedSampleDataIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    /// On first launch only, create a starter set of categories and items.
    private func seedSampleDataIfNeeded() {
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existing == 0 else { return }

        let produce   = Category(name: "Produce",         symbolName: "carrot",         color: .green,  sortOrder: 0)
        let dairy     = Category(name: "Dairy & Eggs",    symbolName: "cup.and.saucer", color: .blue,   sortOrder: 1)
        let bakery    = Category(name: "Bakery",          symbolName: "birthday.cake",  color: .orange, sortOrder: 2)
        let meat      = Category(name: "Meat & Seafood",  symbolName: "fish",           color: .red,    sortOrder: 3)
        let pantry    = Category(name: "Pantry",          symbolName: "bag",            color: .brown,  sortOrder: 4)
        let frozen    = Category(name: "Frozen",          symbolName: "snowflake",      color: .teal,   sortOrder: 5)
        let drinks    = Category(name: "Drinks",          symbolName: "wineglass",      color: .purple, sortOrder: 6)
        let household = Category(name: "Household",       symbolName: "house",          color: .indigo, sortOrder: 7)

        let allCategories = [produce, dairy, bakery, meat, pantry, frozen, drinks, household]
        allCategories.forEach { context.insert($0) }

        let samples: [(String, Category, Bool)] = [
            ("Bananas", produce, false),
            ("Apples", produce, false),
            ("Spinach", produce, true),
            ("Milk", dairy, false),
            ("Eggs", dairy, false),
            ("Cheddar cheese", dairy, true),
            ("Sourdough bread", bakery, false),
            ("Croissants", bakery, false),
            ("Chicken breast", meat, false),
            ("Salmon fillet", meat, true),
            ("Pasta", pantry, false),
            ("Olive oil", pantry, false),
            ("Coffee beans", pantry, true),
            ("Ice cream", frozen, false),
            ("Frozen peas", frozen, true),
            ("Orange juice", drinks, false),
            ("Dish soap", household, false),
            ("Paper towels", household, true),
        ]
        for (name, category, checked) in samples {
            context.insert(GroceryItem(name: name, category: category, isChecked: checked))
        }
        try? context.save()
    }
}
```

```swift
// FILE: Models.swift
import Foundation
import SwiftData
import SwiftUI

/// Preset palette used to tint category icons/headers.
/// Stored as a raw string so it can live inside SwiftData.
enum CategoryColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, teal, blue, indigo, purple, pink, brown

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .teal:   return .teal
        case .blue:   return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink:   return .pink
        case .brown:  return .brown
        }
    }
}

/// Curated SF Symbols offered when creating/editing a category.
enum SymbolLibrary {
    static let icons: [String] = [
        "cart", "basket", "bag", "carrot", "leaf", "fish",
        "cup.and.saucer", "birthday.cake", "wineglass", "drop",
        "snowflake", "house", "flame", "star", "sparkles", "pills"
    ]
}

@Model
final class Category {
    var name: String
    var symbolName: String
    var colorRaw: String
    var sortOrder: Int

    /// Cascade so deleting a category also removes its items.
    @Relationship(deleteRule: .cascade, inverse: \GroceryItem.category)
    var items: [GroceryItem]?

    init(name: String, symbolName: String = "cart", color: CategoryColor = .green, sortOrder: Int = 0) {
        self.name = name
        self.symbolName = symbolName
        self.colorRaw = color.rawValue
        self.sortOrder = sortOrder
    }

    var color: CategoryColor {
        get { CategoryColor(rawValue: colorRaw) ?? .green }
        set { colorRaw = newValue.rawValue }
    }

    var uncheckedCount: Int {
        items?.filter { !$0.isChecked }.count ?? 0
    }
}

@Model
final class GroceryItem {
    var name: String
    var isChecked: Bool
    var createdAt: Date
    var category: Category?

    init(name: String, category: Category? = nil, isChecked: Bool = false, createdAt: Date = .now) {
        self.name = name
        self.category = category
        self.isChecked = isChecked
        self.createdAt = createdAt
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
```

```swift
// FILE: ItemRow.swift
import SwiftUI
import SwiftData

struct ItemRow: View {
    @Bindable var item: GroceryItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.25)) {
                    item.isChecked.toggle()
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isChecked ? .green : .secondary)
            }
            .buttonStyle(.glass) // iOS 26 Liquid Glass
            .accessibilityLabel(item.isChecked ? "Uncheck \(item.name)" : "Check off \(item.name)")

            Text(item.name)
                .strikethrough(item.isChecked, color: .secondary)
                .foregroundStyle(item.isChecked ? .secondary : .primary)
                .animation(.default, value: item.isChecked)

            Spacer()
        }
        .contentShape(.rect)
    }
}
```

```swift
// FILE: CategoryHeaderView.swift
import SwiftUI

struct CategoryHeaderView: View {
    let category: Category

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(category.color.color)
                .frame(width: 30, height: 30)
                .glassEffect(.regular.tint(category.color.color.opacity(0.3)), in: .circle) // iOS 26

            Text(category.name)
                .font(.headline)

            Spacer()

            if category.uncheckedCount > 0 {
                Text("\(category.uncheckedCount) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("e.g. Milk", text: $name)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { if isValid { addItem() } }
                }

                Section("Category") {
                    if categories.isEmpty {
                        Text("Create a category first from the main screen's menu.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categories) { category in
                                Label(category.name, systemImage: category.symbolName)
                                    .tag(category as Category?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .bold()
                        .disabled(!isValid)
                }
            }
            .onAppear {
                selectedCategory = categories.first
                isFocused = true
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addItem() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(GroceryItem(name: trimmed, category: selectedCategory))
        try? modelContext.save()
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
```

```swift
// FILE: CategoryEditorView.swift
import SwiftUI
import SwiftData

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existing: Category?

    @State private var name: String
    @State private var symbolName: String
    @State private var color: CategoryColor
    @FocusState private var isFocused: Bool

    init(existing: Category? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _symbolName = State(initialValue: existing?.symbolName ?? "cart")
        _color = State(initialValue: existing?.color ?? .green)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { if isValid { save() } }
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 48))], spacing: 10) {
                        ForEach(SymbolLibrary.icons, id: \.self) { icon in
                            Button {
                                symbolName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 48, height: 48)
                                    .foregroundStyle(symbolName == icon ? .white : color.color)
                                    .background(
                                        symbolName == icon ? color.color : Color.secondary.opacity(0.12),
                                        in: .rect(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    HStack(spacing: 14) {
                        ForEach(CategoryColor.allCases) { option in
                            Button {
                                withAnimation(.spring(response: 0.2)) {
                                    color = option
                                }
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if color == option {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(option == .yellow ? .black : .white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.label)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existing == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if existing == nil { isFocused = true }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existing {
            existing.name = trimmed
            existing.symbolName = symbolName
            existing.color = color
        } else {
            let count = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
            modelContext.insert(Category(name: trimmed, symbolName: symbolName, color: color, sortOrder: count))
        }
        try? modelContext.save()
        dismiss()
    }
}
```

How the requirements map to the code:

- **Categories** — `Category` model with name, SF Symbol icon, and color; items are grouped into `List` sections with a glass-tinted header showing the remaining count. Categories can be added, edited (tap a row), reordered (Edit mode), and deleted (swipe — cascades to its items).
- **Check-off** — tap the glass circle on any row, swipe left, or use the context menu; checked items get a strikethrough and dim. Bulk actions ("check off everything", "remove checked items") live in the toolbar menu, and progress shows in the navigation subtitle.
- **Delete** — swipe right (full swipe deletes), Edit mode, or the "Remove checked items" bulk action.
- **Saved between launches** — everything lives in SwiftData (`ModelContainer` with `isStoredInMemoryOnly: false`), so it persists automatically; sample data is seeded only on first launch.
- **iOS 26** — uses `.glassEffect(_:in:)` and `.buttonStyle(.glass)` for Liquid Glass, plus `navigationSubtitle` and `ContentUnavailableView`. Only Apple frameworks (SwiftUI, SwiftData, Foundation) are used.