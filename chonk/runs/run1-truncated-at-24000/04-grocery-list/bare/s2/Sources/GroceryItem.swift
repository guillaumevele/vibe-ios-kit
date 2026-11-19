// FILE: GroceryItem.swift
import Foundation
import SwiftData

@Model
final class GroceryItem {
    var name: String
    var isChecked: Bool
    var addedAt: Date
    var sortOrder: Int

    @Relationship(inverse: \Category.items)
    var category: Category?

    init(name: String, category: Category? = nil, sortOrder: Int = 0) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isChecked = false
        self.addedAt = Date()
        self.sortOrder = sortOrder
        self.category = category
    }
}
