// FILE: Models.swift
import Foundation

enum GroceryCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case produce
    case dairy
    case bakery
    case meatAndFish
    case pantry
    case frozen
    case drinks
    case household
    case other

    var id: Self { self }

    static var all: [GroceryCategory] { allCases }

    var name: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy"
        case .bakery: return "Bakery"
        case .meatAndFish: return "Meat & Fish"
        case .pantry: return "Pantry"
        case .frozen: return "Frozen"
        case .drinks: return "Drinks"
        case .household: return "Household"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .produce: return "carrot"
        case .dairy: return "drop"
        case .bakery: return "birthday.cake"
        case .meatAndFish: return "fish"
        case .pantry: return "archivebox"
        case .frozen: return "snowflake"
        case .drinks: return "cup.and.saucer"
        case .household: return "house"
        case .other: return "ellipsis.circle"
        }
    }
}

struct GroceryItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var isDone: Bool
    var category: GroceryCategory
    var addedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: GroceryCategory,
        isDone: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isDone = isDone
        self.addedAt = addedAt
    }
}

struct CategorySection: Identifiable, Equatable, Sendable {
    let id: GroceryCategory
    let category: GroceryCategory
    let items: [GroceryItem]
}
