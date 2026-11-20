// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @State private var viewModel = ArticlesViewModel()

    var body: some Scene {
        WindowGroup {
            ArticleListView()
                .environment(viewModel)
        }
    }
}
