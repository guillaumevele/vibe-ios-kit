Here is the complete app, one file per block.

```swift
// FILE: GroceryListApp.swift
import SwiftUI

@main
@MainActor
struct GroceryListApp: App {
    @State private var model = GroceryListModel(store: FileGroceryStore.makeDefault())

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
```

```swift
// FILE: Design.swift
import SwiftUI

enum Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
}

enum Accent {
    static let color: Color = .accentColor
}
```

```swift
// FILE: Models.swift
import Foundation

enum GroceryCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case produce
    case dairy
    case bakery
    case meatAndFish
    case pantry
    case frozen
    case drinks
    case household
    case other

    var id: Self { self }

    static var all: [GroceryCategory] { allCases }

    var name: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy"
        case .bakery: return "Bakery"
        case .meatAndFish: return "Meat & Fish"
        case .pantry: return "Pantry"
        case .frozen: return "Frozen"
        case .drinks: return "Drinks"
        case .household: return "Household"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .produce: return "carrot"
        case .dairy: return "drop"
        case .bakery: return "birthday.cake"
        case .meatAndFish: return "fish"
        case .pantry: return "archivebox"
        case .frozen: return "snowflake"
        case .drinks: return "cup.and.saucer"
        case .household: return "house"
        case .other: return "ellipsis.circle"
        }
    }
}

struct GroceryItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var isDone: Bool
    var category: GroceryCategory
    var addedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: GroceryCategory,
        isDone: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isDone = isDone
        self.addedAt = addedAt
    }
}

struct CategorySection: Identifiable, Equatable, Sendable {
    let id: GroceryCategory
    let category: GroceryCategory
    let items: [GroceryItem]
}
```

```swift
// FILE: GroceryStore.swift
import Foundation

protocol GroceryStore: Sendable {
    func load() async throws -> [GroceryItem]
    func save(_ items: [GroceryItem]) async throws
}

actor FileGroceryStore: GroceryStore {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    static func makeDefault() -> FileGroceryStore {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileGroceryStore(url: directory.appendingPathComponent("groceries.json"))
    }

    func load() async throws -> [GroceryItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GroceryItem].self, from: data)
    }

    func save(_ items: [GroceryItem]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)
        try data.write(to: url, options: .atomic)
    }
}

actor InMemoryGroceryStore: GroceryStore {
    private var items: [GroceryItem]

    init(items: [GroceryItem] = []) {
        self.items = items
    }

    func load() async throws -> [GroceryItem] {
        items
    }

    func save(_ newItems: [GroceryItem]) async throws {
        items = newItems
    }
}
```

```swift
// FILE: GroceryListModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class GroceryListModel {
    enum ScreenState: Equatable {
        case loading
        case empty
        case failed(String)
        case content
    }

    private let store: any GroceryStore
    private var items: [GroceryItem] = []

    private(set) var state: ScreenState = .loading
    private(set) var sections: [CategorySection] = []
    private(set) var totalCount = 0
    private(set) var remainingCount = 0
    private(set) var canWrite = false

    var pendingDeletion: GroceryItem?
    var saveError: String?

    init(store: any GroceryStore) {
        self.store = store
    }

    func load() async {
        state = .loading
        do {
            items = try await store.load()
            canWrite = true
            recompute()
            state = items.isEmpty ? .empty : .content
        } catch {
            canWrite = false
            state = .failed("Couldn't read the saved list: \(error.localizedDescription)")
        }
    }

    func add(name: String, category: GroceryCategory) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(GroceryItem(name: trimmed, category: category))
        recompute()
        persist()
    }

    func toggle(_ item: GroceryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        recompute()
        persist()
    }

    func requestDelete(_ item: GroceryItem) {
        pendingDeletion = item
    }

    func deletePending() {
        guard let item = pendingDeletion else { return }
        items.removeAll { $0.id == item.id }
        pendingDeletion = nil
        recompute()
        persist()
    }

    func cancelDelete() {
        pendingDeletion = nil
    }

    func persistNow() async {
        guard canWrite else { return }
        let snapshot = items
        do {
            try await store.save(snapshot)
        } catch {
            saveError = "Changes couldn't be saved: \(error.localizedDescription)"
        }
    }

    private func recompute() {
        sections = GroceryCategory.all.compactMap { category in
            let list = items
                .filter { $0.category == category }
                .sorted { $0.addedAt < $1.addedAt }
            guard !list.isEmpty else { return nil }
            return CategorySection(id: category, category: category, items: list)
        }
        totalCount = items.count
        remainingCount = items.filter { !$0.isDone }.count
        if state == .content || state == .empty {
            state = items.isEmpty ? .empty : .content
        }
    }

    private func persist() {
        guard canWrite else { return }
        let snapshot = items
        Task {
            do {
                try await store.save(snapshot)
            } catch {
                saveError = "Changes couldn't be saved: \(error.localizedDescription)"
            }
        }
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    let model: GroceryListModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: NewItemDraft?

    private var isPresentingDeleteAlert: Binding<Bool> {
        Binding(
            get: { model.pendingDeletion != nil },
            set: { if !$0 { model.cancelDelete() } }
        )
    }

    private var isPresentingSaveError: Binding<Bool> {
        Binding(
            get: { model.saveError != nil },
            set: { if !$0 { model.saveError = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    ProgressView("Loading your groceries")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ContentUnavailableView(
                        "No groceries yet",
                        systemImage: "cart",
                        description: Text("Add your first item and it will be saved on this device.")
                    ) {
                        Button("Add item", systemImage: "plus") {
                            draft = NewItemDraft()
                        }
                    }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't load groceries", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("\(message) Your saved list was not changed, and new edits won't be saved until loading succeeds.")
                    } actions: {
                        Button("Retry", systemImage: "arrow.clockwise") {
                            Task { await model.load() }
                        }
                    }
                case .content:
                    groceryList
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draft = NewItemDraft()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $draft) { _ in
                NewItemSheet(model: model)
            }
            .alert("Delete this item?", isPresented: isPresentingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    model.deletePending()
                }
                Button("Cancel", role: .cancel) {
                    model.cancelDelete()
                }
            } message: {
                Text(model.pendingDeletion?.name ?? "")
            }
            .alert("Couldn't save changes", isPresented: isPresentingSaveError) {
                Button("OK", role: .cancel) {
                    model.saveError = nil
                }
            } message: {
                Text(model.saveError ?? "")
            }
        }
        .task {
            await model.load()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { await model.persistNow() }
            }
        }
    }

    private var groceryList: some View {
        List {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        GroceryRow(item: item) {
                            model.toggle(item)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipeToTrigger: true) {
                            Button {
                                model.toggle(item)
                            } label: {
                                Label(item.isDone ? "Uncheck" : "Check off", systemImage: "checkmark")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipeToTrigger: false) {
                            Button(role: .destructive) {
                                model.requestDelete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Label(section.category.name, systemImage: section.category.symbolName)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationSubtitle("\(model.remainingCount) of \(model.totalCount) remaining")
        .animation(reduceMotion ? nil : .default, value: model.sections)
    }
}

#Preview("Populated") {
    ContentView(model: GroceryListModel(store: InMemoryGroceryStore(items: [
        GroceryItem(name: "Apples", category: .produce),
        GroceryItem(name: "Bananas", category: .produce, isDone: true),
        GroceryItem(name: "Milk", category: .dairy),
        GroceryItem(name: "Bread", category: .bakery),
        GroceryItem(name: "Chicken", category: .meatAndFish, isDone: true),
        GroceryItem(name: "Pasta", category: .pantry),
        GroceryItem(name: "Ice cream", category: .frozen),
        GroceryItem(name: "Orange juice", category: .drinks),
        GroceryItem(name: "Dish soap", category: .household)
    ])))
}

#Preview("Empty") {
    ContentView(model: GroceryListModel(store: InMemoryGroceryStore()))
}
```

```swift
// FILE: GroceryRow.swift
import SwiftUI

struct GroceryRow: View {
    let item: GroceryItem
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: Spacing.medium) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? Accent.color : Color.secondary)
                    .accessibilityHidden(true)
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                Spacer()
                Image(systemName: item.category.symbolName)
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isDone)
        .accessibilityLabel("\(item.name), \(item.category.name)")
        .accessibilityValue(item.isDone ? "Checked off" : "Not checked off")
        .accessibilityHint("Double tap to check off or uncheck")
    }
}
```

```swift
// FILE: NewItemSheet.swift
import Foundation
import SwiftUI

struct NewItemDraft: Identifiable {
    let id = UUID()
}

struct NewItemSheet: View {
    let model: GroceryListModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: GroceryCategory = .produce
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item name") {
                    TextField("Milk", text: $name)
                        .focused($isNameFocused)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(GroceryCategory.all) { option in
                            Label(option.name, systemImage: option.symbolName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
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
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .task {
            isNameFocused = true
        }
    }

    private func add() {
        model.add(name: name, category: category)
        dismiss()
    }
}
```

## Not verified

I did not run this app; it has not been compiled. Still needed:

- A build with Xcode 26 against the iOS 26 SDK in Swift 6 language mode to confirm strict-concurrency checking passes (especially the `Task` inheriting `@MainActor` in `persist()`, and the `Sendable` store protocol).
- A simulator run of both `#Preview`s and the real app: add items, check them off, swipe to delete, confirm the destructive alert, and relaunch the app to confirm the JSON file in Application Support restores the list.
- A VoiceOver pass on the list rows (label, value, hint), the empty/failed states, and the add-item sheet.
- A device test with Dynamic Type at Accessibility sizes, with Reduce Motion both on and off, and with the app backgrounded to verify the `scenePhase` save.
- Manual check that the SF Symbol names (`carrot`, `birthday.cake`, `drop`, `cup.and.saucer`, etc.) render and are not empty on iOS 26.