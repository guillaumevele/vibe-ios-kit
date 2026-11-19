Here is the complete app — eight files, SwiftUI only, Apple frameworks only, written for iOS 26 in Swift 6 language mode.

```swift
// FILE: GroceryApp.swift
import SwiftUI

@MainActor
@main
struct GroceryApp: App {
    @State private var model: GroceryListModel

    init() {
        _model = State(initialValue: GroceryListModel(store: FileGroceryStore.makeDefault()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(Palette.accent)
        }
    }
}
```

```swift
// FILE: Theme.swift
import SwiftUI

enum Palette {
    static let accent = Color.green
}

enum Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}
```

```swift
// FILE: Models.swift
import Foundation

enum Category: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case produce
    case dairy
    case bakery
    case meat
    case pantry
    case frozen
    case beverages
    case household
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy"
        case .bakery: return "Bakery"
        case .meat: return "Meat & Seafood"
        case .pantry: return "Pantry"
        case .frozen: return "Frozen"
        case .beverages: return "Beverages"
        case .household: return "Household"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .produce: return "leaf"
        case .dairy: return "drop"
        case .bakery: return "birthday.cake"
        case .meat: return "fish"
        case .pantry: return "basket"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer"
        case .household: return "house"
        case .other: return "questionmark.circle"
        }
    }
}

struct GroceryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var category: Category
    var isChecked: Bool
    var addedAt: Date

    init(id: UUID = UUID(), title: String, category: Category, isChecked: Bool = false, addedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.category = category
        self.isChecked = isChecked
        self.addedAt = addedAt
    }
}

extension GroceryItem {
    static var samples: [GroceryItem] {
        [
            GroceryItem(title: "Bananas", category: .produce, addedAt: Date().addingTimeInterval(-3600)),
            GroceryItem(title: "Apples", category: .produce, isChecked: true, addedAt: Date().addingTimeInterval(-7200)),
            GroceryItem(title: "Milk", category: .dairy, addedAt: Date().addingTimeInterval(-1800)),
            GroceryItem(title: "Bread", category: .bakery, isChecked: true, addedAt: Date().addingTimeInterval(-5400)),
            GroceryItem(title: "Chicken breast", category: .meat, addedAt: Date().addingTimeInterval(-900)),
            GroceryItem(title: "Pasta", category: .pantry, addedAt: Date().addingTimeInterval(-600))
        ]
    }
}

struct CategorySection: Identifiable, Sendable {
    let category: Category
    let items: [GroceryItem]
    var id: Category { category }
}
```

```swift
// FILE: GroceryStore.swift
import Foundation

protocol GroceryStore: Sendable {
    func load() async throws -> [GroceryItem]
    func save(_ items: [GroceryItem]) async throws
}

struct FileGroceryStore: GroceryStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func makeDefault() -> FileGroceryStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileGroceryStore(fileURL: directory.appendingPathComponent("grocery-list.json"))
    }

    func load() async throws -> [GroceryItem] {
        do {
            let data = try await Data(contentsOf: fileURL)
            return try JSONDecoder().decode([GroceryItem].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    func save(_ items: [GroceryItem]) async throws {
        let directory = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(items)
        try await data.write(to: fileURL, options: .atomic)
    }
}

actor InMemoryGroceryStore: GroceryStore {
    private var stored: [GroceryItem]

    init(items: [GroceryItem] = []) {
        stored = items
    }

    func load() async throws -> [GroceryItem] {
        stored
    }

    func save(_ items: [GroceryItem]) async throws {
        stored = items
    }
}
```

```swift
// FILE: GroceryListModel.swift
import Foundation

@MainActor
@Observable
final class GroceryListModel {
    enum ScreenState {
        case loading
        case empty
        case failed(String)
        case content
    }

    private let store: any GroceryStore
    private var storeIsReadable = false

    var state: ScreenState = .loading
    var items: [GroceryItem] = []
    var saveNotice: String?

    init(store: any GroceryStore) {
        self.store = store
    }

    var sections: [CategorySection] {
        Category.allCases.compactMap { category in
            let items = items
                .filter { $0.category == category }
                .sorted { lhs, rhs in
                    if lhs.isChecked != rhs.isChecked {
                        return !lhs.isChecked
                    }
                    return lhs.addedAt < rhs.addedAt
                }
            return items.isEmpty ? nil : CategorySection(category: category, items: items)
        }
    }

    func load() async {
        state = .loading
        do {
            let loaded = try await store.load()
            items = loaded
            storeIsReadable = true
            saveNotice = nil
            state = loaded.isEmpty ? .empty : .content
        } catch {
            storeIsReadable = false
            state = .failed("We couldn't read your saved grocery list, so nothing on disk was changed. Make sure this device has storage available, then tap Retry.")
        }
    }

    func add(title: String, category: Category) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(GroceryItem(title: trimmed, category: category))
        await persist()
    }

    func toggle(_ item: GroceryItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isChecked.toggle()
        await persist()
    }

    func delete(_ item: GroceryItem) async {
        items.removeAll { $0.id == item.id }
        await persist()
    }

    private func persist() async {
        if storeIsReadable {
            do {
                try await store.save(items)
                saveNotice = nil
            } catch {
                saveNotice = "Your changes couldn't be saved and will be lost if you quit the app."
            }
        } else {
            saveNotice = "Your saved list couldn't be read, so changes are kept in memory only until a load succeeds."
        }
        state = items.isEmpty ? .empty : .content
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    let model: GroceryListModel

    @State private var addRequest: ItemDraft?
    @State private var pendingDelete: GroceryItem?
    @State private var isDeleteConfirmationShown = false

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    ProgressView("Loading your grocery list")
                case .empty:
                    ContentUnavailableView {
                        Label("Your list is empty", systemImage: "cart")
                    } description: {
                        Text("Add your first item and it will be saved on this device.")
                    } actions: {
                        Button("Add item") {
                            addRequest = ItemDraft()
                        }
                    }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't load your list", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry") {
                            Task { await model.load() }
                        }
                    }
                case .content:
                    listView
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addRequest = ItemDraft()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $addRequest) { _ in
                NavigationStack {
                    AddItemView { title, category in
                        Task { await model.add(title: title, category: category) }
                    }
                }
            }
            .alert("Delete this item?", isPresented: $isDeleteConfirmationShown) {
                Button("Delete", role: .destructive) {
                    if let item = pendingDelete {
                        Task { await model.delete(item) }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("It will be removed from your saved list.")
            }
            .task {
                await model.load()
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            if let notice = model.saveNotice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
            }
            List {
                ForEach(model.sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            ItemRow(item: item) {
                                Task { await model.toggle(item) }
                            } onDelete: {
                                pendingDelete = item
                                isDeleteConfirmationShown = true
                            }
                        }
                    } header: {
                        Label(section.category.title, systemImage: section.category.symbolName)
                            .font(.headline)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

#Preview("List with items") {
    ContentView(model: GroceryListModel(store: InMemoryGroceryStore(items: GroceryItem.samples)))
}

#Preview("Empty list") {
    ContentView(model: GroceryListModel(store: InMemoryGroceryStore()))
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
                    .foregroundStyle(item.isChecked ? Palette.accent : Color.secondary)
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(item.title)
                        .font(.body)
                        .strikethrough(item.isChecked, color: .secondary)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    Text(item.category.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, Spacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.category.title)")
        .accessibilityValue(item.isChecked ? "Checked" : "Not checked")
        .accessibilityHint(item.isChecked ? "Double-tap to mark as not bought yet" : "Double-tap to check off")
        .accessibilityAddTraits(item.isChecked ? .isSelected : [])
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
```

```swift
// FILE: AddItemView.swift
import SwiftUI

struct ItemDraft: Identifiable {
    let id = UUID()
}

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: Category = .produce

    let onSave: (String, Category) -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("Item name") {
                TextField("Bananas", text: $title)
                    .textInputAutocapitalization(.sentences)
            }
            Section {
                Picker("Category", selection: $category) {
                    ForEach(Category.allCases) { option in
                        Label(option.title, systemImage: option.symbolName)
                            .tag(option)
                    }
                }
            }
        }
        .navigationTitle("New item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(title, category)
                    dismiss()
                }
                .disabled(trimmedTitle.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddItemView { _, _ in }
    }
}
```

## Not verified

I did not run this app; it has not been compiled or executed. Still needed:

- A build in Xcode targeting iOS 26 with Swift 6 language mode, to confirm strict-concurrency correctness (especially the `@MainActor` app/model wiring and the async `Data(contentsOf:)` / `Data.write(to:)` calls).
- A simulator run covering: first launch (empty state), adding items across categories, check-off, swipe-delete with the confirmation alert, and quitting/relaunching to confirm the JSON file in Application Support restores the list.
- A VoiceOver pass over the list rows (combined label, checked value, hint), the add sheet, and the delete alert.
- A device run to confirm the Application Support directory is created and persists across launches, plus a Dynamic Type check at the largest accessibility sizes.