// FILE: FeedApp.swift
import SwiftUI

/// App entry point. Deployment target: iOS 26.
@main
struct FeedApp: App {
    var body: some Scene {
        WindowGroup {
            ArticleListView()
        }
    }
}
