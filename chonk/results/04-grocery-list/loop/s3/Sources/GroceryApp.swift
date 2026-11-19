// FILE: GroceryApp.swift
import SwiftUI

@MainActor
@main
struct GroceryApp: App {
    @State private var model: GroceryListModel

    init() {
        _model = State(initialValue: GroceryListModel(store: FileGroceryStore.makeDefault()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(Palette.accent)
        }
    }
}
