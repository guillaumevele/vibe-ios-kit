Here is the complete app — eight Swift files, SwiftUI only, Apple frameworks only, written for iOS 26 / Swift 6 strict concurrency.

```swift
// FILE: GroceryListApp.swift
import SwiftUI

@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            GroceryListView(viewModel: GroceryListViewModel())
        }
    }
}
```

```swift
// FILE: Models.swift
import Foundation

enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case produce, dairy, bakery, meat, pantry, frozen, beverages, household, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy & Eggs"
        case .bakery: return "Bakery"
        case .meat: return "Meat & Fish"
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
        case .meat: return "fork.knife"
        case .pantry: return "archivebox"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer"
        case .household: return "house"
        case .other: return "questionmark.circle"
        }
    }
}

struct GroceryItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var category: Category
    var isChecked: Bool
    var addedOn: Date

    init(id: UUID = UUID(), name: String, category: Category, isChecked: Bool = false, addedOn: Date = Date()) {
        self.id = id
        self.name = name
        self.category = category
        self.isChecked = isChecked
        self.addedOn = addedOn
    }
}

struct CategorySection: Identifiable, Sendable {
    let category: Category
    var items: [GroceryItem]

    var id: Category { category }
}

/// Value handed to the add-item sheet so it always opens with fresh data.
struct NewItemDraft: Identifiable, Sendable {
    let id = UUID()
}
```

```swift
// FILE: GroceryStore.swift
import Foundation

/// Anything that reads or writes the grocery list. Replace with an in-memory
/// implementation in previews and tests.
protocol GroceryStore: Sendable {
    func load() async throws -> [GroceryItem]
    func save(_ items: [GroceryItem]) async throws
}

enum StoreError: LocalizedError, Sendable {
    case unreadableFile
    case undecodable(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The saved grocery file could not be read."
        case .undecodable(let detail):
            return "The saved grocery file is damaged (\(detail))."
        }
    }
}

/// Persists the list as JSON in Application Support, so it survives launches.
struct FileGroceryStore: GroceryStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = directory.appendingPathComponent("grocery-list.json")
        }
    }

    func load() async throws -> [GroceryItem] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw StoreError.unreadableFile
        }

        do {
            return try JSONDecoder().decode([GroceryItem].self, from: data)
        } catch {
            throw StoreError.undecodable(error.localizedDescription)
        }
    }

    func save(_ items: [GroceryItem]) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}

#if DEBUG
/// In-memory store used only by previews.
actor PreviewGroceryStore: GroceryStore {
    private var stored: [GroceryItem]
    private let shouldFail: Bool

    init(stored: [GroceryItem] = [], shouldFail: Bool = false) {
        self.stored = stored
        self.shouldFail = shouldFail
    }

    func load() async throws -> [GroceryItem] {
        if shouldFail {
            throw StoreError.unreadableFile
        }
        return stored
    }

    func save(_ items: [GroceryItem]) async throws {
        stored = items
    }
}
#endif
```

```swift
// FILE: GroceryListViewModel.swift
import Foundation

@Observable
@MainActor
final class GroceryListViewModel {
    /// The four states of the screen, as one enum.
    enum LoadState: Equatable {
        case loading
        case empty
        case failed(String)
        case content
    }

    private(set) var sections: [CategorySection] = []
    var state: LoadState = .loading
    var saveError: String?

    /// False until a load has succeeded. While false, every write is refused,
    /// so a failed read can never overwrite the saved file.
    private var storeIsHealthy = false
    private let store: any GroceryStore

    init(store: any GroceryStore = FileGroceryStore()) {
        self.store = store
    }

    var totalCount: Int {
        sections.reduce(0) { $0 + $1.items.count }
    }

    var remainingCount: Int {
        sections.reduce(0) { $0 + $1.items.filter { !$0.isChecked }.count }
    }

    func load() async {
        state = .loading
        saveError = nil
        do {
            let loaded = try await store.load()
            storeIsHealthy = true
            apply(loaded)
            state = loaded.isEmpty ? .empty : .content
        } catch {
            // Keep whatever is in memory; do not clear it, do not allow writes.
            state = .failed(message(for: error))
        }
    }

    func toggle(_ item: GroceryItem) async {
        guard storeIsHealthy,
              let sectionIndex = sections.firstIndex(where: { $0.items.contains { $0.id == item.id } }),
              let itemIndex = sections[sectionIndex].items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        sections[sectionIndex].items[itemIndex].isChecked.toggle()
        await persist()
    }

    func delete(_ item: GroceryItem) async {
        guard storeIsHealthy else { return }
        for sectionIndex in sections.indices {
            sections[sectionIndex].items.removeAll { $0.id == item.id }
        }
        sections.removeAll { $0.items.isEmpty }
        if sections.isEmpty, case .content = state {
            state = .empty
        }
        await persist()
    }

    func add(name: String, category: Category) async {
        guard storeIsHealthy else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var all = sections.flatMap(\.items)
        all.append(GroceryItem(name: trimmed, category: category))
        apply(all)
        if case .empty = state {
            state = .content
        }
        await persist()
    }

    func retrySave() async {
        await persist()
    }

    private func persist() async {
        guard storeIsHealthy else { return }
        let snapshot = sections.flatMap(\.items)
        do {
            try await store.save(snapshot)
            saveError = nil
        } catch {
            saveError = "Changes could not be saved yet. The list saved on this device is unchanged."
        }
    }

    /// Groups items into category sections in a fixed order, unchecked first,
    /// then alphabetical. Called once per mutation, never from `body`.
    private func apply(_ items: [GroceryItem]) {
        let grouped = Dictionary(grouping: items, by: \.category)
        sections = Category.allCases.compactMap { category in
            guard let list = grouped[category], !list.isEmpty else { return nil }
            let sorted = list.sorted { lhs, rhs in
                if lhs.isChecked != rhs.isChecked {
                    return !lhs.isChecked
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return CategorySection(category: category, items: sorted)
        }
    }

    private func message(for error: Error) -> String {
        let reason: String
        if let storeError = error as? StoreError, let description = storeError.errorDescription {
            reason = description
        } else {
            reason = "The saved list could not be read."
        }
        return "\(reason) Your saved groceries were left untouched, and changes are paused until the list loads."
    }
}
```

```swift
// FILE: GroceryListView.swift
import SwiftUI

struct GroceryListView: View {
    @State private var viewModel: GroceryListViewModel
    @State private var draft: NewItemDraft?
    @State private var pendingDelete: GroceryItem?

    init(viewModel: GroceryListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Groceries")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if case .content = viewModel.state {
                            Button {
                                draft = NewItemDraft()
                            } label: {
                                Label("Add", systemImage: "plus")
                            }
                        }
                    }
                }
                .sheet(item: $draft) { _ in
                    AddItemView(viewModel: viewModel)
                }
                .alert(Text("Delete item?"), item: $pendingDelete) { item in
                    Button("Delete", role: .destructive) {
                        Task { await viewModel.delete(item) }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: { item in
                    Text("This removes \"\(item.name)\" from your saved list.")
                }
                .task {
                    await viewModel.load()
                }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .loading:
            VStack {
                Spacer()
                ProgressView("Loading your groceries…")
                Spacer()
            }
        case .empty:
            ContentUnavailableView {
                Label("No groceries yet", systemImage: "cart")
            } description: {
                Text("Add your first item and it will be saved for next time.")
            } actions: {
                Button("Add Item", systemImage: "plus") {
                    draft = NewItemDraft()
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load your list", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry", systemImage: "arrow.clockwise") {
                    Task { await viewModel.load() }
                }
            }
        case .content:
            list
        }
    }

    private var list: some View {
        List {
            if let saveError = viewModel.saveError {
                Section {
                    HStack(spacing: Spacing.sm) {
                        Label("Changes not saved yet", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Retry") {
                            Task { await viewModel.retrySave() }
                        }
                        .font(.subheadline)
                    }
                }
            }
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        GroceryRow(
                            item: item,
                            onToggle: { Task { await viewModel.toggle(item) } },
                            onDelete: { pendingDelete = item }
                        )
                    }
                } header: {
                    Label(section.category.title, systemImage: section.category.symbolName)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationSubtitle("\(viewModel.remainingCount) of \(viewModel.totalCount) remaining")
    }
}

#if DEBUG
#Preview("Content") {
    GroceryListView(viewModel: GroceryListViewModel(store: PreviewGroceryStore(stored: [
        GroceryItem(name: "Bananas", category: .produce),
        GroceryItem(name: "Apples", category: .produce, isChecked: true),
        GroceryItem(name: "Milk", category: .dairy),
        GroceryItem(name: "Bread", category: .bakery),
        GroceryItem(name: "Chicken breast", category: .meat),
        GroceryItem(name: "Pasta", category: .pantry),
        GroceryItem(name: "Ice cream", category: .frozen),
        GroceryItem(name: "Coffee beans", category: .beverages),
        GroceryItem(name: "Dish soap", category: .household)
    ])))
}

#Preview("Empty") {
    GroceryListView(viewModel: GroceryListViewModel(store: PreviewGroceryStore()))
}

#Preview("Failed to load") {
    GroceryListView(viewModel: GroceryListViewModel(store: PreviewGroceryStore(shouldFail: true)))
}
#endif
```

```swift
// FILE: GroceryRow.swift
import SwiftUI

struct GroceryRow: View {
    let item: GroceryItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Color.accentColor : .secondary)
                    .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: item.isChecked)
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
                Image(systemName: item.category.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .contextMenu {
            Button {
                onToggle()
            } label: {
                Label(item.isChecked ? "Mark as not bought" : "Mark as bought", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                onDelete()
            } label: