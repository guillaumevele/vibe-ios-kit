// FILE: Models.swift
import Foundation
import SwiftData

/// A group that grocery items belong to (e.g. "Produce", "Dairy & Eggs").
@Model
final class Category {
    var name: String
    var sortOrder: Int
    var createdAt: Date

    /// Items in this category. Deleting a category nullifies this link,
    /// so its items become "Uncategorized" instead of being deleted.
    @Relationship(inverse: \GroceryItem.category)
    var items: [GroceryItem] = []

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

/// A single grocery list entry.
@Model
final class GroceryItem {
    var name: String
    var quantity: String
    var isChecked: Bool
    var createdAt: Date
    var category: Category?

    init(name: String, quantity: String = "", category: Category? = nil) {
        self.name = name
        self.quantity = quantity
        self.isChecked = false
        self.createdAt = Date()
        self.category = category
    }
}
