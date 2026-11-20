// FILE: FocusTimerApp.swift
import SwiftUI

@main
struct FocusTimerApp: App {
    @State private var model = AppModel(store: FileSessionStore.default)

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
