// FILE: Models.swift
import Foundation
import SwiftData
import SwiftUI

/// Preset accent colors a category can pick from.
enum CategoryColor: String, CaseIterable, Identifiable {
    case green, blue, orange, purple, pink, red, teal, brown

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .green:  return .green
        case .blue:   return .blue
        case .orange: return .orange
        case .purple: return .purple
        case .pink:   return .pink
        case .red:    return .red
        case .teal:   return .teal
        case .brown:  return .brown
        }
    }
}

@Model
final class Category {
    var name: String
    var symbolName: String
    var colorRaw: String
    var createdAt: Date

    // Deleting a category cascades to all of its items.
    @Relationship(deleteRule: .cascade, inverse: \GroceryItem.category)
    var items: [GroceryItem] = []

    init(name: String, symbolName: String, color: CategoryColor) {
        self.name = name
        self.symbolName = symbolName
        self.colorRaw = color.rawValue
        self.createdAt = Date()
    }

    var tint: Color {
        CategoryColor(rawValue: colorRaw)?.color ?? .blue
    }

    var uncheckedCount: Int {
        items.filter { !$0.isChecked }.count
    }
}

@Model
final class GroceryItem {
    var name: String
    var isChecked: Bool
    var createdAt: Date
    var category: Category?

    init(name: String, category: Category? = nil) {
        self.name = name
        self.isChecked = false
        self.createdAt = Date()
        self.category = category
    }
}
