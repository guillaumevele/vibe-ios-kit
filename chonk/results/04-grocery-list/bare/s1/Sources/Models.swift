// FILE: Models.swift
import Foundation
import SwiftData
import SwiftUI

/// Preset palette used to tint category icons/headers.
/// Stored as a raw string so it can live inside SwiftData.
enum CategoryColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, teal, blue, indigo, purple, pink, brown

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .teal:   return .teal
        case .blue:   return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink:   return .pink
        case .brown:  return .brown
        }
    }
}

/// Curated SF Symbols offered when creating/editing a category.
enum SymbolLibrary {
    static let icons: [String] = [
        "cart", "basket", "bag", "carrot", "leaf", "fish",
        "cup.and.saucer", "birthday.cake", "wineglass", "drop",
        "snowflake", "house", "flame", "star", "sparkles", "pills"
    ]
}

@Model
final class Category {
    var name: String
    var symbolName: String
    var colorRaw: String
    var sortOrder: Int

    /// Cascade so deleting a category also removes its items.
    @Relationship(deleteRule: .cascade, inverse: \GroceryItem.category)
    var items: [GroceryItem]?

    init(name: String, symbolName: String = "cart", color: CategoryColor = .green, sortOrder: Int = 0) {
        self.name = name
        self.symbolName = symbolName
        self.colorRaw = color.rawValue
        self.sortOrder = sortOrder
    }

    var color: CategoryColor {
        get { CategoryColor(rawValue: colorRaw) ?? .green }
        set { colorRaw = newValue.rawValue }
    }

    var uncheckedCount: Int {
        items?.filter { !$0.isChecked }.count ?? 0
    }
}

@Model
final class GroceryItem {
    var name: String
    var isChecked: Bool
    var createdAt: Date
    var category: Category?

    init(name: String, category: Category? = nil, isChecked: Bool = false, createdAt: Date = .now) {
        self.name = name
        self.category = category
        self.isChecked = isChecked
        self.createdAt = createdAt
    }
}
