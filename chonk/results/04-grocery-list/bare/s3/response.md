Here's a complete SwiftUI grocery list app targeting iOS 26, using SwiftData for persistence between launches — categories, check-off, delete (swipe + context menu), edit, search, and a progress header. Apple frameworks only.

```swift
// FILE: GroceryListApp.swift
import SwiftUI
import SwiftData

/// App entry point. Requires iOS 26+.
/// SwiftData persists the model container to disk automatically,
/// so the grocery list is restored between launches.
@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: GroceryItem.self)
    }
}
```

```swift
// FILE: GroceryItem.swift
import Foundation
import SwiftData

/// A single grocery list entry, persisted with SwiftData.
@Model
final class GroceryItem {
    var name: String
    var categoryRawValue: String
    var isChecked: Bool
    var createdAt: Date

    /// Strongly-typed accessor for the stored category string.
    var category: Category {
        get { Category(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    init(name: String, category: Category = .other, isChecked: Bool = false) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.categoryRawValue = category.rawValue
        self.isChecked = isChecked
        self.createdAt = Date()
    }
}
```

```swift
// FILE: Category.swift
import SwiftUI

/// Grocery categories with an SF Symbol and tint color each.
enum Category: String, CaseIterable, Identifiable, Codable, Sendable {
    case produce = "Produce"
    case dairy = "Dairy & Eggs"
    case bakery = "Bakery"
    case meatAndSeafood = "Meat & Seafood"
    case pantry = "Pantry"
    case frozen = "Frozen"
    case beverages = "Beverages"
    case household = "Household"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .bakery: return "birthday.cake.fill"
        case .meatAndSeafood: return "fish.fill"
        case .pantry: return "archivebox.fill"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer.fill"
        case .household: return "sparkles"
        case .other: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .produce: return .green
        case .dairy: return .blue
        case .bakery: return .orange
        case .meatAndSeafood: return .red
        case .pantry: return .brown
        case .frozen: return .cyan
        case .beverages: return .purple
        case .household: return .pink
        case .other: return .gray
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
```

```swift
// FILE: ItemRow.swift
import SwiftUI

/// A tappable row that checks the item off (or back on).
struct ItemRow: View {
    let item: GroceryItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.category.color)
                Text(item.name)
                    .multilineTextAlignment(.leading)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name + (item.isChecked ? ", checked off" : ", not checked"))
        .accessibilityHint(item.isChecked ? "Double-tap to mark as not bought" : "Double-tap to check off")
    }
}
```

```swift
// FILE: CategorySectionHeader.swift
import SwiftUI

/// Section header showing the category symbol, name, and remaining-item count.
struct CategorySectionHeader: View {
    let category: Category
    let remaining: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.symbol)
                .foregroundStyle(category.color)
            Text(category.rawValue)
                .font(.headline)
            if remaining > 0 {
                Text("\(remaining)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(category.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(category.color.opacity(0.18))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .textCase(nil)
    }
}
```

```swift
// FILE: ProgressHeaderView.swift
import SwiftUI

/// Progress summary shown at the top of the list.
struct ProgressHeaderView: View {
    let done: Int
    let total: Int

    private var isComplete: Bool { total > 0 && done == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    isComplete ? "All done!" : "Shopping progress",
                    systemImage: isComplete ? "checkmark.seal.fill" : "cart.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isComplete ? .green : .primary)
                Spacer()
                Text("\(done) of \(total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(done), total: Double(total))
                .tint(isComplete ? .green : .accentColor)
        }
        .padding(.vertical, 6)
    }
}
```

```swift
// FILE: ItemEditorView.swift
import SwiftUI
import SwiftData

/// Sheet for adding a new item or editing an existing one.
struct ItemEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: Category

    private let item: GroceryItem?

    init(item: GroceryItem? = nil) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _category = State(initialValue: item?.category ?? .other)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Bananas", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit {
                            if canSave { save() }
                        }
                } header: {
                    Text(item == nil ? "New item" : "Edit item")
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { option in
                            Label {
                                Text(option.rawValue)
                            } icon: {
                                Image(systemName: option.symbol)
                                    .foregroundStyle(option.color)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle(item == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(item == nil ? "Add" : "Save") {
                        save()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        if let item {
            item.name = trimmedName
            item.category = category
        } else {
            modelContext.insert(GroceryItem(name: trimmedName, category: category))
        }
        dismiss()
    }
}
```

To use it, create a new iOS App project in Xcode with the SwiftUI interface and SwiftData storage enabled (or just paste these files in), set the deployment target to iOS 26, and run. The list is stored in SwiftData's on-disk store, so it's fully preserved across launches, and supports check-off, swipe/context-menu delete, editing, moving between categories, search, and a "Clear Checked" action.