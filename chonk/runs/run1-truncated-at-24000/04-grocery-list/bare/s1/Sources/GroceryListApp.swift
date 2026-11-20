// FILE: GroceryListApp.swift
// Deployment target: iOS 26.0 — SwiftUI + SwiftData only, no third-party packages.
import SwiftUI
import SwiftData

@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Default ModelContainer persists to disk, so data survives between launches.
        .modelContainer(for: [Category.self, GroceryItem.self])
    }
}
