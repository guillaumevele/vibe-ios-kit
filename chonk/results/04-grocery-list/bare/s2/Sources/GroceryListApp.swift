// FILE: GroceryListApp.swift
import SwiftUI
import SwiftData

@main
struct GroceryListApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([GroceryItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create persistent ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
