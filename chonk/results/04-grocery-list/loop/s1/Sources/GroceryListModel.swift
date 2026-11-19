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
