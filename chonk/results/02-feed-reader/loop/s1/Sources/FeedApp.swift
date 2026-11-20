// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @State private var store: FeedStore

    init() {
        guard let feedURL = URL(string: FeedConfiguration.feedURLString) else {
            preconditionFailure("FeedConfiguration.feedURLString must be a valid URL")
        }
        _store = State(initialValue: FeedStore(fetcher: URLSessionFeedFetcher(), feedURL: feedURL))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
