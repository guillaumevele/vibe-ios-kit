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
