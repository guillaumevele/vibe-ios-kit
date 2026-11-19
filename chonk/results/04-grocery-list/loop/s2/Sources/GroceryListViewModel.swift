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
