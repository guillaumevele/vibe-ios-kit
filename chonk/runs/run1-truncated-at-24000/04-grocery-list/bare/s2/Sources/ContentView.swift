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
