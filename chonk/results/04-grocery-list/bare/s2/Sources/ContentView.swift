// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.createdAt) private var items: [GroceryItem]

    @State private var searchText = ""
    @State private var showingAddItem = false
    @AppStorage("groceryList.hasSeededSampleData") private var hasSeededSampleData = false

    private var filteredItems: [GroceryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(query)
                || item.category.rawValue.localizedCaseInsensitiveContains(query)
                || (item.notes ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    private var remainingCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(GroceryCategory.allCases) { category in
                    CategorySection(
                        category: category,
                        items: sectionItems(for: category),
                        onToggle: toggle,
                        onDelete: delete
                    )
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search groceries"
            )
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(remainingCount) left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .accessibilityLabel("Add grocery item")
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
            .overlay {
                if filteredItems.isEmpty {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView {
                            Label("No groceries yet", systemImage: "cart")
                        } description: {
                            Text("Tap the + button to add your first item.")
                        } actions: {
                            Button("Add item") {
                                showingAddItem = true
                            }
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .task {
                seedSampleDataIfNeeded()
            }
        }
    }

    private func sectionItems(for category: GroceryCategory) -> [GroceryItem] {
        filteredItems
            .filter { $0.category == category }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private func toggle(_ item: GroceryItem) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            item.isCompleted.toggle()
        }
        try? modelContext.save()
    }

    private func delete(_ item: GroceryItem) {
        withAnimation {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func seedSampleDataIfNeeded() {
        guard !hasSeededSampleData else { return }

        let descriptor = FetchDescriptor<GroceryItem>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        if count > 0 {
            hasSeededSampleData = true
            return
        }

        let samples: [(name: String, category: GroceryCategory, notes: String?)] = [
            ("Bananas", .produce, "Organic if available"),
            ("Apples", .produce, nil),
            ("Milk", .dairy, "2%"),
            ("Eggs", .dairy, "One dozen"),
            ("Bread", .bakery, nil),
            ("Chicken breast", .meatAndSeafood, nil),
            ("Pasta", .pantry, nil),
            ("Olive oil", .pantry, nil),
            ("Frozen peas", .frozen, nil),
            ("Coffee", .beverages, nil),
            ("Dish soap", .household, nil)
        ]

        for (index, sample) in samples.enumerated() {
            modelContext.insert(
                GroceryItem(
                    name: sample.name,
                    category: sample.category,
                    notes: sample.notes,
                    createdAt: Date().addingTimeInterval(TimeInterval(index))
                )
            )
        }
        try? modelContext.save()
        hasSeededSampleData = true
    }
}

private struct CategorySection: View {
    let category: GroceryCategory
    let items: [GroceryItem]
    let onToggle: (GroceryItem) -> Void
    let onDelete: (GroceryItem) -> Void

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            Section {
                ForEach(items) { item in
                    ItemRow(item: item) {
                        onToggle(item)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            onToggle(item)
                        } label: {
                            Label(
                                item.isCompleted ? "Undo" : "Done",
                                systemImage: item.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle"
                            )
                        }
                        .tint(item.isCompleted ? .orange : .green)
                    }
                    .contextMenu {
                        Button(
                            item.isCompleted ? "Mark as not done" : "Mark as done",
                            systemImage: item.isCompleted ? "circle" : "checkmark.circle"
                        ) {
                            onToggle(item)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            onDelete(item)
                        }
                    }
                }
            } header: {
                CategoryHeader(category: category, items: items)
            }
        }
    }
}

private struct CategoryHeader: View {
    let category: GroceryCategory
    let items: [GroceryItem]

    private var remainingCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.symbolName)
                .foregroundStyle(category.color)
            Text(category.rawValue)
                .font(.headline)
            Spacer()
            Text(remainingCount == 0 ? "All done" : "\(remainingCount) left")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
