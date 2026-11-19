// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    // A @main type is @MainActor-isolated in Swift 6, so constructing the
    // @MainActor view model in this stored-property initializer is safe.
    @State private var viewModel = FeedViewModel(service: LiveFeedService())

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
