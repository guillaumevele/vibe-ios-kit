// FILE: Category.swift
import SwiftUI

/// Grocery categories with an SF Symbol and tint color each.
enum Category: String, CaseIterable, Identifiable, Codable, Sendable {
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

    var symbol: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .bakery: return "birthday.cake.fill"
        case .meatAndSeafood: return "fish.fill"
        case .pantry: return "archivebox.fill"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer.fill"
        case .household: return "sparkles"
        case .other: return "square.grid.2x2.fill"
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
        case .household: return .pink
        case .other: return .gray
        }
    }
}
