// FILE: Models.swift
import Foundation

enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case produce, dairy, bakery, meat, pantry, frozen, beverages, household, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy & Eggs"
        case .bakery: return "Bakery"
        case .meat: return "Meat & Fish"
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
        case .meat: return "fork.knife"
        case .pantry: return "archivebox"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer"
        case .household: return "house"
        case .other: return "questionmark.circle"
        }
    }
}

struct GroceryItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var category: Category
    var isChecked: Bool
    var addedOn: Date

    init(id: UUID = UUID(), name: String, category: Category, isChecked: Bool = false, addedOn: Date = Date()) {
        self.id = id
        self.name = name
        self.category = category
        self.isChecked = isChecked
        self.addedOn = addedOn
    }
}

struct CategorySection: Identifiable, Sendable {
    let category: Category
    var items: [GroceryItem]

    var id: Category { category }
}

/// Value handed to the add-item sheet so it always opens with fresh data.
struct NewItemDraft: Identifiable, Sendable {
    let id = UUID()
}
