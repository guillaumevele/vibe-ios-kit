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

    var canAdd: Bool {
        state == .content || state == .empty
    }

    init(store: any GroceryStore) {
        self.store = store
    }

    func load() async {
        state = .loading
        do {
            let loaded = try await store.load()
            items = loaded
            canWrite = true
            recompute()
            state = items.isEmpty ? .empty : .content
        } catch {
            canWrite = false
            state = .failed("Couldn't read the saved list: \(error.localizedDescription)")
        }
    }

    func add(name: String, category: GroceryCategory) {
        guard canWrite else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(GroceryItem(name: trimmed, category: category))
        recompute()
        persist()
    }

    func toggle(_ item: GroceryItem) {
        guard canWrite else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        recompute()
        persist()
    }

    func requestDelete(_ item: GroceryItem) {
        pendingDeletion = item
    }

    func deletePending() {
        guard canWrite, let item = pendingDeletion else { return }
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
