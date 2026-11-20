// FILE: GroceryListApp.swift
import SwiftUI
import SwiftData

@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // On-disk model container: all data is saved between launches automatically.
        .modelContainer(for: [Category.self, GroceryItem.self])
    }
}
