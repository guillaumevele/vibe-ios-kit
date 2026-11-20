// FILE: SeedData.swift
import Foundation
import SwiftData

/// Inserts a set of starter categories/items exactly once, on first launch.
enum SeedData {
    private static let hasSeededKey = "GroceryList.hasSeededDefaultCategories"

    static func seedDefaultCategoriesIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasSeededKey) else { return }
        UserDefaults.standard.set(true, forKey: hasSeededKey)

        let definitions: [(name: String, symbol: String, color: CategoryColor, items: [String])] = [
            ("Produce",        "leaf.fill",            .green,  ["Bananas", "Spinach", "Cherry tomatoes"]),
            ("Dairy & Eggs",   "egg.fill",             .blue,   ["Milk", "Eggs", "Greek yogurt"]),
            ("Bakery",         "birthday.cake.fill",   .orange, ["Sourdough bread"]),
            ("Meat & Seafood", "fish.fill",            .red,    ["Salmon fillet"]),
            ("Pantry",         "archivebox.fill",      .brown,  ["Olive oil", "Pasta", "Rice"]),
            ("Frozen",         "snowflake",            .teal,   ["Frozen peas", "Ice cream"]),
            ("Beverages",      "cup.and.saucer.fill",  .purple, ["Coffee beans", "Orange juice"]),
            ("Household",      "sparkles",             .pink,   ["Dish soap", "Paper towels"]),
        ]

        for definition in definitions {
            let category = Category(name: definition.name,
                                    symbolName: definition.symbol,
                                    color: definition.color)
            modelContext.insert(category)
            for itemName in definition.items {
                modelContext.insert(GroceryItem(name: itemName, category: category))
            }
        }
    }
}
