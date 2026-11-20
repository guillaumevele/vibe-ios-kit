// FILE: FocusTimerApp.swift
import SwiftUI
import SwiftData

@main
struct FocusTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: FocusSession.self)
    }
}
