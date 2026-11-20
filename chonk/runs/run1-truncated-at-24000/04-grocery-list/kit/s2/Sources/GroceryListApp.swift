// FILE: GroceryListApp.swift
import SwiftUI

@main
struct GroceryListApp: App {
    var body: some Scene {
        WindowGroup {
            GroceryListView(viewModel: GroceryListViewModel())
        }
    }
}
