// FILE: GroceryListApp.swift
import SwiftUI
import SwiftData

@main
struct GroceryListApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([Category.self, GroceryItem.self])
        do {
            // The default configuration stores data on disk, so the
            // grocery list is saved between launches.
            modelContainer = try ModelContainer(for: schema)
        } catch {
            // Fall back to an in-memory store if the disk store can't be opened.
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
