// FILE: Models.swift
import Foundation
import SwiftUI

struct GroceryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var category: GroceryCategory
    var isChecked: Bool

    init(id: UUID = UUID(), name: String, category: GroceryCategory, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.isChecked = isChecked
    }
}

enum GroceryCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case produce
    case dairy
    case bakery
    case meatAndSeafood
    case pantry
    case frozen
    case beverages
    case household

    var id: String { rawValue }

    var title: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy & Eggs"
        case .bakery: return "Bakery"
        case .meatAndSeafood: return "Meat & Seafood"
        case .pantry: return "Pantry"
        case .frozen: return "Frozen"
        case .beverages: return "Beverages"
        case .household: return "Household"
        }
    }

    var symbolName: String {
        switch self {
        case .produce: return "leaf"
        case .dairy: return "drop"
        case .bakery: return "bag"
        case .meatAndSeafood: return "fish"
        case .pantry: return "archivebox"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer"
        case .household: return "house"
        }
    }
}

enum Theme {
    static let accent = Color.blue
    static let smallSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 12
    static let largeSpacing: CGFloat = 20
}
