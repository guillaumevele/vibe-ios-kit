// FILE: BookTrackerApp.swift
import SwiftUI

@main
struct BookTrackerApp: App {
    @State private var store = BookStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
