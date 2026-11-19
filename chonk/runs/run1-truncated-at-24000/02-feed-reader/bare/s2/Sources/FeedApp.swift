// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @StateObject private var feedViewModel = FeedViewModel()

    var body: some Scene {
        WindowGroup {
            ArticleListView(viewModel: feedViewModel)
        }
    }
}
