// FILE: GroceryApp.swift
import SwiftUI
import SwiftData

/// Deployment target: iOS 26
@main
struct GroceryApp: App {
    /// SwiftData container backed by on-disk storage — the list is saved between launches.
    let container: ModelContainer

    init() {
        let schema = Schema([Category.self, GroceryItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        seedSampleDataIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    /// On first launch only, create a starter set of categories and items.
    private func seedSampleDataIfNeeded() {
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existing == 0 else { return }

        let produce   = Category(name: "Produce",         symbolName: "carrot",         color: .green,  sortOrder: 0)
        let dairy     = Category(name: "Dairy & Eggs",    symbolName: "cup.and.saucer", color: .blue,   sortOrder: 1)
        let bakery    = Category(name: "Bakery",          symbolName: "birthday.cake",  color: .orange, sortOrder: 2)
        let meat      = Category(name: "Meat & Seafood",  symbolName: "fish",           color: .red,    sortOrder: 3)
        let pantry    = Category(name: "Pantry",          symbolName: "bag",            color: .brown,  sortOrder: 4)
        let frozen    = Category(name: "Frozen",          symbolName: "snowflake",      color: .teal,   sortOrder: 5)
        let drinks    = Category(name: "Drinks",          symbolName: "wineglass",      color: .purple, sortOrder: 6)
        let household = Category(name: "Household",       symbolName: "house",          color: .indigo, sortOrder: 7)

        let allCategories = [produce, dairy, bakery, meat, pantry, frozen, drinks, household]
        allCategories.forEach { context.insert($0) }

        let samples: [(String, Category, Bool)] = [
            ("Bananas", produce, false),
            ("Apples", produce, false),
            ("Spinach", produce, true),
            ("Milk", dairy, false),
            ("Eggs", dairy, false),
            ("Cheddar cheese", dairy, true),
            ("Sourdough bread", bakery, false),
            ("Croissants", bakery, false),
            ("Chicken breast", meat, false),
            ("Salmon fillet", meat, true),
            ("Pasta", pantry, false),
            ("Olive oil", pantry, false),
            ("Coffee beans", pantry, true),
            ("Ice cream", frozen, false),
            ("Frozen peas", frozen, true),
            ("Orange juice", drinks, false),
            ("Dish soap", household, false),
            ("Paper towels", household, true),
        ]
        for (name, category, checked) in samples {
            context.insert(GroceryItem(name: name, category: category, isChecked: checked))
        }
        try? context.save()
    }
}
