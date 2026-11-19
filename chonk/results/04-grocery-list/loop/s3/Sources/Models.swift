// FILE: Models.swift
import Foundation

enum Category: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case produce
    case dairy
    case bakery
    case meat
    case pantry
    case frozen
    case beverages
    case household
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy"
        case .bakery: return "Bakery"
        case .meat: return "Meat & Seafood"
        case .pantry: return "Pantry"
        case .frozen: return "Frozen"
        case .beverages: return "Beverages"
        case .household: return "Household"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .produce: return "leaf"
        case .dairy: return "drop"
        case .bakery: return "birthday.cake"
        case .meat: return "fish"
        case .pantry: return "basket"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer"
        case .household: return "house"
        case .other: return "questionmark.circle"
        }
    }
}

struct GroceryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var category: Category
    var isChecked: Bool
    var addedAt: Date

    init(id: UUID = UUID(), title: String, category: Category, isChecked: Bool = false, addedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.category = category
        self.isChecked = isChecked
        self.addedAt = addedAt
    }
}

extension GroceryItem {
    static var samples: [GroceryItem] {
        [
            GroceryItem(title: "Bananas", category: .produce, addedAt: Date().addingTimeInterval(-3600)),
            GroceryItem(title: "Apples", category: .produce, isChecked: true, addedAt: Date().addingTimeInterval(-7200)),
            GroceryItem(title: "Milk", category: .dairy, addedAt: Date().addingTimeInterval(-1800)),
            GroceryItem(title: "Bread", category: .bakery, isChecked: true, addedAt: Date().addingTimeInterval(-5400)),
            GroceryItem(title: "Chicken breast", category: .meat, addedAt: Date().addingTimeInterval(-900)),
            GroceryItem(title: "Pasta", category: .pantry, addedAt: Date().addingTimeInterval(-600))
        ]
    }
}

struct CategorySection: Identifiable, Sendable {
    let category: Category
    let items: [GroceryItem]
    var id: Category { category }
}
