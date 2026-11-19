Two fixes: the protocol-extension static isn't callable on the metatype, so `RootView` now defaults to `FileGroceryStore()` directly; and the iOS 26-deprecated `navigationBarTitleDisplayMode` is removed. I also moved grouping into a stored, recomputed-on-mutation property (per the "compute once in the model" rule) and made the alert title a `Text` so the overload resolves unambiguously.

```swift
// FILE: GroceryListApp.swift
import SwiftUI

@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

```swift
// FILE: Models.swift
import Foundation
import SwiftUI

struct GroceryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var category: GroceryCategory
    var isChecked: Bool

    init(id: UUID = UUID(), name: String, category: GroceryCategory, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.isChecked = isChecked
    }
}

enum GroceryCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case produce
    case dairy
    case bakery
    case meatAndSeafood
    case pantry
    case frozen
    case beverages
    case household

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy & Eggs"
        case .bakery: return "Bakery"
        case .meatAndSeafood: return "Meat & Seafood"
        case .pantry: return "Pantry"
        case .frozen: return "Frozen"
        case .beverages: return "Beverages"
        case .household: return "Household"
        }
    }

    var symbolName: String {
        switch self {
        case .produce: return "leaf"
        case .dairy: return "drop"
        case .bakery: return "bag"
        case .meatAndSeafood: return "fish"
        case .pantry: return "archivebox"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer"
        case .household: return "house"
        }
    }
}

enum Theme {
    static let accent = Color.blue
    static let smallSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 12
    static let largeSpacing: CGFloat = 20
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

    init() {
        let supportDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        fileURL = supportDirectory.appendingPathComponent("grocery-list.json")
    }

    func load() async throws -> [GroceryItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([GroceryItem].self, from: data)
    }

    func save(_ items: [GroceryItem]) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}

struct InMemoryGroceryStore: GroceryStore {
    let initial: [GroceryItem]

    func load() async throws -> [GroceryItem] {
        initial
    }

    func save(_ items: [GroceryItem]) async throws { }
}
```

```swift
// FILE: GroceryListViewModel.swift
import Foundation
import SwiftUI

@Observable
@MainActor
final class GroceryListViewModel {
    enum ScreenState: Equatable {
        case loading
        case empty
        case failed(String)
        case content
    }

    struct CategoryGroup: Identifiable {
        let category: GroceryCategory
        let items: [GroceryItem]
        var id: String { category.id }
    }

    private(set) var state: ScreenState = .loading
    private(set) var items: [GroceryItem] = []
    private(set) var groups: [CategoryGroup] = []
    var pendingDelete: GroceryItem?
    var saveErrorMessage: String?

    private let store: GroceryStore
    private var hasReadSucceeded = false

    init(store: GroceryStore) {
        self.store = store
    }

    func load() async {
        state = .loading
        do {
            let loaded = try await store.load()
            items = loaded
            hasReadSucceeded = true
            recomputeGroups()
            state = loaded.isEmpty ? .empty : .content
        } catch {
            state = .failed("We couldn't read your saved list, so nothing on disk was changed. Free up some storage if needed, then try again.")
        }
    }

    func retry() {
        Task { await load() }
    }

    func add(name: String, category: GroceryCategory) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(GroceryItem(name: trimmed, category: category))
        recomputeGroups()
        await persist()
        if state == .empty {
            state = .content
        }
    }

    func toggle(_ item: GroceryItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isChecked.toggle()
        recomputeGroups()
        await persist()
    }

    func delete(_ item: GroceryItem) async {
        items.removeAll { $0.id == item.id }
        recomputeGroups()
        await persist()
        if items.isEmpty {
            state = .empty
        }
    }

    private func recomputeGroups() {
        groups = GroceryCategory.allCases.compactMap { category in
            let inCategory = items
                .filter { $0.category == category }
                .sorted { lhs, rhs in
                    if lhs.isChecked != rhs.isChecked {
                        return !lhs.isChecked
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            guard !inCategory.isEmpty else { return nil }
            return CategoryGroup(category: category, items: inCategory)
        }
    }

    private func persist() async {
        guard hasReadSucceeded else {
            saveErrorMessage = "This change was not saved because the saved list could not be read."
            return
        }
        do {
            try await store.save(items)
        } catch {
            saveErrorMessage = "This change could not be saved and will be lost when you close the app."
        }
    }
}
```

```swift
// FILE: RootView.swift
import SwiftUI

struct RootView: View {
    @State private var viewModel: GroceryListViewModel
    @State private var addItemSheet: AddItemSheet?

    init(store: GroceryStore = FileGroceryStore()) {
        _viewModel = State(initialValue: GroceryListViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .failed(let message):
                    failedView(message)
                case .content:
                    listView
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addItemSheet = AddItemSheet()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(item: $addItemSheet) { _ in
                AddItemView { name, category in
                    await viewModel.add(name: name, category: category)
                }
            }
            .alert(deleteAlertTitle, isPresented: deleteAlertPresented) {
                Button("Delete", role: .destructive) {
                    if let item = viewModel.pendingDelete {
                        viewModel.pendingDelete = nil
                        Task { await viewModel.delete(item) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.pendingDelete = nil
                }
            } message: {
                Text("This removes the item from your saved list.")
            }
            .alert("Couldn't save changes", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) {
                    viewModel.saveErrorMessage = nil
                }
            } message: {
                Text(viewModel.saveErrorMessage ?? "Your changes could not be saved.")
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Theme.mediumSpacing) {
            ProgressView()
            Text("Loading your list")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Your list is empty", systemImage: "cart")
        } description: {
            Text("Add your first grocery to get started.")
        } actions: {
            Button("Add item") {
                addItemSheet = AddItemSheet()
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load your list", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                viewModel.retry()
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.groups) { group in
                Section {
                    ForEach(group.items) { item in
                        GroceryRowView(
                            item: item,
                            onToggle: { Task { await viewModel.toggle(item) } },
                            onDelete: { viewModel.pendingDelete = item }
                        )
                    }
                } header: {
                    HStack {
                        Label(group.category.title, systemImage: group.category.symbolName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(group.items.count) items")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var deleteAlertTitle: Text {
        if let item = viewModel.pendingDelete {
            Text("Delete \(item.name)?")
        } else {
            Text("Delete item?")
        }
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDelete != nil },
            set: { if !$0 { viewModel.pendingDelete = nil } }
        )
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.saveErrorMessage != nil },
            set: { if !$0 { viewModel.saveErrorMessage = nil } }
        )
    }
}

#Preview("With items") {
    RootView(store: InMemoryGroceryStore(initial: [
        GroceryItem(name: "Bananas", category: .produce),
        GroceryItem(name: "Apples", category: .produce, isChecked: true),
        GroceryItem(name: "Whole milk", category: .dairy),
        GroceryItem(name: "Sourdough bread", category: .bakery),
        GroceryItem(name: "Chicken breast", category: .meatAndSeafood),
        GroceryItem(name: "Olive oil", category: .pantry),
        GroceryItem(name: "Vanilla ice cream", category: .frozen, isChecked: true),
        GroceryItem(name: "Dish soap", category: .household)
    ]))
}

#Preview("Empty") {
    RootView(store: InMemoryGroceryStore(initial: []))
}
```

```swift
// FILE: GroceryRowView.swift
import SwiftUI

struct GroceryRowView: View {
    let item: GroceryItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.mediumSpacing) {
            Button(action: onToggle) {
                HStack(spacing: Theme.mediumSpacing) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isChecked ? Theme.accent : .secondary)
                    Text(item.name)
                        .font(.body)
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                }
                .contentShape(.rect)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Mark \(item.name) as not bought" : "Mark \(item.name) as bought")
            .sensoryFeedback(.selection, trigger: item.isChecked)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(item.name)")
        }
        .animation(reduceMotion ? nil : .default, value: item.isChecked)
    }
}
```

```swift
// FILE: AddItemView.swift
import Foundation
import SwiftUI

struct AddItemSheet: Identifiable, Sendable {
    let id = UUID()
}

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: GroceryCategory = .produce

    let onAdd: (String, GroceryCategory) async -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Item name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(GroceryCategory.allCases) { option in
                            Label(option.title, systemImage: option.symbolName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
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
                    Button("Add") {
                        Task {
                            await onAdd(name, category)
                            dismiss()
                        }
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
```

Not verified

I did not build or run this app. Still needed before shipping:

- A build in Xcode targeting iOS 26 with Swift 6 language mode, to confirm the metatype fix compiles and no further deprecation warnings remain (the gate's deprecation line was truncated, so if another API is flagged, that specific call needs replacing).
- A simulator run of both `#Preview`s plus the real app: first launch (empty state), adding items, checking them off, deleting via the alert, and relaunching to confirm the JSON round-trips from Application Support.
- A failure-path check: corrupt `grocery-list.json` by hand and confirm the failed state appears, Retry works, and no write happens while the read has not succeeded.
- A VoiceOver pass over the list rows, section headers, the add sheet, and both alerts, including the 44-point delete target.
- A Dynamic Type pass at the largest sizes and a Reduce Motion pass to confirm the toggle animation is disabled and the check-off still works instantly.