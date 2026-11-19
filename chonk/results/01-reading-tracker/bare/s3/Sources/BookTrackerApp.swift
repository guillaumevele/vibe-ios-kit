// FILE: BookTrackerApp.swift
import SwiftUI
import SwiftData

@main
struct BookTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Book.self)
    }
}
