// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @State private var viewModel = FeedViewModel()

    var body: some Scene {
        WindowGroup {
            ArticleListView(viewModel: viewModel)
        }
    }
}
