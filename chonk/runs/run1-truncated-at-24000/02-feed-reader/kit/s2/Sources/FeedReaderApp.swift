// FILE: FeedReaderApp.swift
import SwiftUI

enum FeedConfiguration {
    /// JSON Feed (https://jsonfeed.org) endpoint that returns the latest articles.
    static let feedURLString = "https://jsonfeed.org/feed.json"
}

@main
struct FeedReaderApp: App {
    @State private var model = ArticleListModel(
        service: URLSessionFeedService(feedURLString: FeedConfiguration.feedURLString)
    )

    var body: some Scene {
        WindowGroup {
            ArticleListView(model: model)
                .tint(Theme.accent)
        }
    }
}
