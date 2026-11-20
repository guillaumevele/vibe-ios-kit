Here is the complete app — nine files, each in its own fenced block.

```swift
// FILE: GroceryListApp.swift
import SwiftUI

@main
struct GroceryListApp: App {
    @State private var model: GroceryListModel

    init() {
        _model = State(wrappedValue: GroceryListModel(store: FileGroceryStore.persisted()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(Theme.accent)
        }
    }
}
```

```swift
// FILE: Models.swift
import Foundation

struct Category: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var items: [GroceryItem]

    init(id: UUID = UUID(), name: String, items: [GroceryItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}

struct GroceryItem: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var isChecked: Bool

    init(id: UUID = UUID(), name: String, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
    }
}

/// Non-nil only while the "add item" sheet should be shown.
struct ItemDraft: Identifiable, Sendable {
    let id = UUID()
}

/// Set when a swipe-delete is waiting for confirmation.
struct PendingItemDeletion: Identifiable, Sendable {
    let id = UUID()
    let categoryID: UUID
    let itemID: UUID
}

enum SampleData {
    static let categories: [Category] = [
        Category(name: "Produce", items: [
            GroceryItem(name: "Apples"),
            GroceryItem(name: "Spinach", isChecked: true),
        ]),
        Category(name: "Dairy", items: [
            GroceryItem(name: "Milk"),
            GroceryItem(name: "Eggs"),
        ]),
        Category(name: "Bakery", items: [
            GroceryItem(name: "Bread", isChecked: true),
        ]),
    ]
}
```

```swift
// FILE: GroceryStore.swift
import Foundation

/// Anything that reads and writes the list. Replaced by MemoryGroceryStore in previews.
protocol GroceryStore: Sendable {
    func load() async throws -> [Category]
    func save(_ categories: [Category]) async throws
}

/// Persists the list as JSON in Application Support, so it survives relaunches.
struct FileGroceryStore: GroceryStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func persisted() -> FileGroceryStore {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        // If creating the directory fails, saves will surface an error instead of crashing.
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileGroceryStore(fileURL: directory.appendingPathComponent("groceries.json"))
    }

    func load() async throws -> [Category] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode([Category].self, from: data)
    }

    func save(_ categories: [Category]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(categories)
        try data.write(to: fileURL, options: .atomic)
    }
}

/// In-memory store for previews.
struct MemoryGroceryStore: GroceryStore {
    private var loaded: [Category]

    init(loaded: [Category] = []) {
        self.loaded = loaded
    }

    func load() async throws -> [Category] {
        loaded
    }

    func save(_ categories: [Category]) async throws {
        loaded = categories
    }
}
```

```swift
// FILE: GroceryListModel.swift
import Foundation

@Observable
@MainActor
final class GroceryListModel {
    enum LoadState: Equatable {
        case loading
        case empty
        case failed(String)
        case content
    }

    private(set) var categories: [Category] = []
    private(set) var state: LoadState = .loading

    var draft: ItemDraft?
    var itemPendingDeletion: PendingItemDeletion?
    var categoryPendingDeletion: Category?
    var saveError: String?

    private let store: any GroceryStore
    private var hasLoadedSuccessfully = false

    init(store: any GroceryStore) {
        self.store = store
    }

    func load() async {
        guard !hasLoadedSuccessfully else { return }
        state = .loading
        do {
            let loaded = try await store.load()
            categories = loaded
            hasLoadedSuccessfully = true
            state = loaded.isEmpty ? .empty : .content
        } catch {
            state = .failed("We couldn't read your saved groceries, so nothing on this device was changed. Try again.")
        }
    }

    func remainingCount(in categoryID: UUID) -> Int {
        guard let category = categories.first(where: { $0.id == categoryID }) else { return 0 }
        return category.items.filter { !$0.isChecked }.count
    }

    func toggle(item itemID: UUID, in categoryID: UUID) async {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }),
              let itemIndex = categories[categoryIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
        categories[categoryIndex].items[itemIndex].isChecked.toggle()
        await persist()
    }

    func delete(item itemID: UUID, in categoryID: UUID) async {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[categoryIndex].items.removeAll { $0.id == itemID }
        itemPendingDeletion = nil
        await persist()
    }

    func deleteCategory(_ category: Category) async {
        categories.removeAll { $0.id == category.id }
        categoryPendingDeletion = nil
        await persist()
    }

    func addItem(name: String, categoryID: UUID?, newCategoryName: String?) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let targetCategoryID: UUID
        if let categoryID, categories.contains(where: { $0.id == categoryID }) {
            targetCategoryID = categoryID
        } else {
            let trimmedCategoryName = (newCategoryName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let category = Category(name: trimmedCategoryName.isEmpty ? "General" : trimmedCategoryName)
            categories.append(category)
            targetCategoryID = category.id
        }

        guard let categoryIndex = categories.firstIndex(where: { $0.id == targetCategoryID }) else { return }
        categories[categoryIndex].items.insert(GroceryItem(name: trimmedName), at: 0)
        if case .empty = state {
            state = .content
        }
        await persist()
    }

    private func persist() async {
        // A failed load must never clobber saved data: refuse to write until a read has succeeded.
        guard hasLoadedSuccessfully else { return }
        do {
            try await store.save(categories)
        } catch {
            saveError = "Your changes couldn't be saved and will be lost when the app closes."
        }
    }
}
```

```swift
// FILE: Theme.swift
import SwiftUI

enum Theme {
    static let accent = Color.green
}

enum Spacing {
    static let xsmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @Bindable var model: GroceryListModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .failed(let message):
                    failedView(message: message)
                case .content:
                    listView
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.draft = ItemDraft()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                    .disabled(model.state != .content)
                }
            }
            .sheet(item: $model.draft) { _ in
                AddItemView(model: model)
            }
            .alert("Delete this item?", isPresented: itemDeletionPresented) {
                Button("Delete", role: .destructive) {
                    if let pending = model.itemPendingDeletion {
                        Task {
                            await model.delete(item: pending.itemID, in: pending.categoryID)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    model.itemPendingDeletion = nil
                }
            } message: {
                Text("It will be removed from your list.")
            }
            .alert("Delete this category?", isPresented: categoryDeletionPresented) {
                Button("Delete", role: .destructive) {
                    if let category = model.categoryPendingDeletion {
                        Task {
                            await model.deleteCategory(category)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    model.categoryPendingDeletion = nil
                }
            } message: {
                Text("The category and all of its items will be removed.")
            }
            .alert("Couldn't save changes", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) {
                    model.saveError = nil
                }
            } message: {
                if let saveError = model.saveError {
                    Text(saveError)
                }
            }
        }
        .task {
            await model.load()
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.medium) {
            ProgressView()
            Text("Loading your list")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Nothing on the list yet", systemImage: "cart")
        } description: {
            Text("Add your first grocery and it will be saved on this device.")
        } actions: {
            Button("Add item") {
                model.draft = ItemDraft()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func failedView(message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load your list", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    await model.load()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var listView: some View {
        List {
            ForEach(model.categories) { category in
                Section {
                    ForEach(category.items) { item in
                        ItemRow(
                            item: item,
                            onToggle: {
                                Task {
                                    await model.toggle(item: item.id, in: category.id)
                                }
                            },
                            onDelete: {
                                model.itemPendingDeletion = PendingItemDeletion(
                                    categoryID: category.id,
                                    itemID: item.id
                                )
                            }
                        )
                    }
                } header: {
                    CategoryHeader(
                        category: category,
                        remaining: model.remainingCount(in: category.id),
                        onDelete: {
                            model.categoryPendingDeletion = category
                        }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var itemDeletionPresented: Binding<Bool> {
        Binding(
            get: { model.itemPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    model.itemPendingDeletion = nil
                }
            }
        )
    }

    private var categoryDeletionPresented: Binding<Bool> {
        Binding(
            get: { model.categoryPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    model.categoryPendingDeletion = nil
                }
            }
        )
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { model.saveError != nil },
            set: { isPresented in
                if !isPresented {
                    model.saveError = nil
                }
            }
        )
    }
}

#Preview("With items") {
    ContentView(model: GroceryListModel(store: MemoryGroceryStore(loaded: SampleData.categories)))
}

#Preview("Empty") {
    ContentView(model: GroceryListModel(store: MemoryGroceryStore()))
}
```

```swift
// FILE: CategoryHeader.swift
import SwiftUI

struct CategoryHeader: View {
    let category: Category
    let remaining: Int
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(category.name)
                .font(.headline)
            Spacer()
            if remaining > 0 {
                Text("\(remaining) left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Label("All done", systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete category", systemImage: "trash")
            }
        }
        .accessibilityHint("Long press to delete this category")
    }
}
```

```swift
// FILE: ItemRow.swift
import SwiftUI

struct ItemRow: View {
    let item: GroceryItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Theme.accent : .secondary)
                    .accessibilityHidden(true)
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.xsmall)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityValue(item.isChecked ? "Checked" : "Not checked")
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
```

```swift
// FILE: AddItemView.swift
import SwiftUI
import Foundation

struct AddItemView: View {
    let model: GroceryListModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var newCategoryName = ""
    @State private var isNewCategory = false
    @State private var selectedCategoryID: UUID?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCategoryName: String {
        newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        guard !trimmedName.isEmpty else { return false }
        if isNewCategory {
            return !trimmedCategoryName.isEmpty
        }
        return selectedCategoryID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Milk", text: $name)
                }
                Section("Category") {
                    if isNewCategory || model.categories.isEmpty {
                        TextField("Produce", text: $newCategoryName)
                    } else {
                        Picker("Category", selection: $selectedCategoryID) {
                            ForEach(model.categories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .pickerStyle(.menu)
                        Button("New category") {
                            isNewCategory = true
                        }
                    }
                }
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        add()
                    }
                    .disabled(!canAdd)
                }
            }
            .task {
                if model.categories.isEmpty {
                    isNewCategory = true
                }
                if selectedCategoryID == nil {
                    selectedCategoryID = model.categories.first?.id
                }
            }
        }
    }

    private func add() {
        Task {
            await model.addItem(
                name: trimmedName,
                categoryID: isNewCategory ? nil : selectedCategoryID,
                newCategoryName: isNewCategory ? trimmedCategoryName : nil
            )
            dismiss()
        }
    }
}
```

Not verified

I did not run this app. Still needed before shipping:

- A build with the Xcode 26 / iOS 26 SDK in Swift 6 language mode — I have not compiled any of this, so there may be small API or concurrency nits to fix.
- A simulator run to exercise all four states (loading, empty, failed, content), including forcing a failed load by corrupting `groceries.json` and confirming Retry works and that no write happens after a failed read.
- A relaunch test on a device to confirm check-offs, deletions, new categories and new items persist across launches.
- A VoiceOver pass: row combined elements, "Checked / Not checked" values, the section-header context menu (long press), and the two destructive alerts.
- A Dynamic Type pass at Accessibility sizes to confirm rows and the add-item form still lay out.
- Reduce Motion is trivially satisfied (no animations are used), but confirm the haptic on check-off feels right on a device.