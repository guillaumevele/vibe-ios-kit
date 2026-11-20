// FILE: FocusTimerApp.swift
import SwiftUI
import SwiftData

@main
struct FocusTimerApp: App {
    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Session.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create the model container: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(Self.sharedModelContainer)
        }
    }
}
