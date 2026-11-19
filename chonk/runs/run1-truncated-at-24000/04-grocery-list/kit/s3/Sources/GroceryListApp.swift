// FILE: GroceryListApp.swift
import SwiftUI

@main
@MainActor
struct GroceryListApp: App {
    @State private var model = GroceryListModel(store: FileGroceryStore.makeDefault())

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
