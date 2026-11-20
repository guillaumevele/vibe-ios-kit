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
