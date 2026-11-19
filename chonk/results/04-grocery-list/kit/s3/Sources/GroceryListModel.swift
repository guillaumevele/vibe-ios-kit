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
