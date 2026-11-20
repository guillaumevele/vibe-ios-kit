// FILE: Models.swift
import Foundation
import SwiftUI
import SwiftData

enum GroceryCategory: String, CaseIterable, Identifiable, Codable {
    case produce = "Produce"
    case dairy = "Dairy & Eggs"
    case bakery = "Bakery"
    case meatAndSeafood = "Meat & Seafood"
    case pantry = "Pantry"
    case frozen = "Frozen"
    case beverages = "Beverages"
    case household = "Household"
    case other = "Other"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .bakery: return "basket.fill"
        case .meatAndSeafood: return "fish.fill"
        case .pantry: return "archivebox.fill"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer.fill"
        case .household: return "bubbles.and.sparkles.fill"
        case .other: return "ellipsis.circle"
        }
    }

    var color: Color {
        switch self {
        case .produce: return .green
        case .dairy: return .blue
        case .bakery: return .orange
        case .meatAndSeafood: return .red
        case .pantry: return .brown
        case .frozen: return .cyan
        case .beverages: return .purple
        case .household: return .teal
        case .other: return .gray
        }
    }
}

@Model
final class GroceryItem {
    var name: String
    var categoryRaw: String
    var isCompleted: Bool
    var createdAt: Date
    var notes: String?

    init(
        name: String,
        category: GroceryCategory,
        notes: String? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.notes = notes
    }

    var category: GroceryCategory {
        GroceryCategory(rawValue: categoryRaw) ?? .other
    }
}
