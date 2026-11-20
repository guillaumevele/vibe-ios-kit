// FILE: Category.swift
import SwiftUI
import SwiftData

@Model
final class Category {
    var name: String
    var symbolName: String
    var colorHex: String
    var sortOrder: Int

    // Deleting a category also deletes all of its items.
    @Relationship(deleteRule: .cascade, inverse: \GroceryItem.category)
    var items: [GroceryItem]?

    init(name: String, symbolName: String = "cart", colorHex: String = "#007AFF", sortOrder: Int = 0) {
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.items = []
    }

    var color: Color { Color(hex: colorHex) }

    var itemCount: Int { items?.count ?? 0 }

    var remainingCount: Int { (items ?? []).filter { !$0.isChecked }.count }

    /// SF Symbols offered when creating a category.
    static let symbolOptions: [String] = [
        "cart", "leaf", "carrot", "fish", "egg",
        "cup.and.saucer", "snowflake", "birthday.cake",
        "cabinet", "basket", "takeoutbag.and.cup.and.straw", "drop"
    ]

    /// Preset colors offered when creating a category (stored as hex).
    static let colorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#8E8E93", "#A2845E"
    ]
}
