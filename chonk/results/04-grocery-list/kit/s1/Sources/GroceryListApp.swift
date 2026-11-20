// FILE: GroceryListApp.swift
import SwiftUI

@main
struct GroceryListApp: App {
    @State private var model: GroceryListModel

    init() {
        _model = State(wrappedValue: GroceryListModel(store: FileGroceryStore.persisted()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(Theme.accent)
        }
    }
}
