```swift
// FILE: GroceryListApp.swift
import SwiftUI
import SwiftData

@main
struct GroceryListApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([GroceryItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create persistent ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
```

```swift
// FILE: Models.swift
import Foundation
import SwiftUI
import SwiftData

enum GroceryCategory: String, CaseIterable, Identifiable, Codable {
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

    var symbolName: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .bakery: return "basket.fill"
        case .meatAndSeafood: return "fish.fill"
        case .pantry: return "archivebox.fill"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer.fill"
        case .household: return "bubbles.and.sparkles.fill"
        case .other: return "ellipsis.circle"
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
        case .household: return .teal
        case .other: return .gray
        }
    }
}

@Model
final class GroceryItem {
    var name: String
    var categoryRaw: String
    var isCompleted: Bool
    var createdAt: Date
    var notes: String?

    init(
        name: String,
        category: GroceryCategory,
        notes: String? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.notes = notes
    }

    var category: GroceryCategory {
        GroceryCategory(rawValue: categoryRaw) ?? .other
    }
}
```

```swift
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
```

```swift
// FILE: ItemRow.swift
import SwiftUI

struct ItemRow: View {
    let item: GroceryItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted, color: .secondary)

                    if let notes = item.notes,
                       !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if item.isCompleted {
                    Text("Done")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityValue(item.isCompleted ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to toggle")
    }

    private var accessibilityText: String {
        var label = item.name
        if let notes = item.notes, !notes.isEmpty {
            label += ", \(notes)"
        }
        return label
    }
}
```

```swift
// FILE: AddItemView.swift
import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var category: GroceryCategory = .produce
    @State private var notes = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("e.g. Bananas", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)

                    Picker("Category", selection: $category) {
                        ForEach(GroceryCategory.allCases) { option in
                            Label(option.rawValue, systemImage: option.symbolName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                    }
                    .disabled(trimmedName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = GroceryItem(
            name: trimmedName,
            category: category,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
```