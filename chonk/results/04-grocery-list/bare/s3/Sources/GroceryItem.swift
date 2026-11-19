// FILE: GroceryItem.swift
import Foundation
import SwiftData

/// A single grocery list entry, persisted with SwiftData.
@Model
final class GroceryItem {
    var name: String
    var categoryRawValue: String
    var isChecked: Bool
    var createdAt: Date

    /// Strongly-typed accessor for the stored category string.
    var category: Category {
        get { Category(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    init(name: String, category: Category = .other, isChecked: Bool = false) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.categoryRawValue = category.rawValue
        self.isChecked = isChecked
        self.createdAt = Date()
    }
}
