// FILE: GroceryListApp.swift
import SwiftUI
import SwiftData

/// App entry point. Requires iOS 26+.
/// SwiftData persists the model container to disk automatically,
/// so the grocery list is restored between launches.
@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: GroceryItem.self)
    }
}
