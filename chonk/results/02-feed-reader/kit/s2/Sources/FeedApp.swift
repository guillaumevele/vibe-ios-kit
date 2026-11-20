// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    private let store = FeedStore()

    var body: some Scene {
        WindowGroup {
            ArticleListView(store: store)
        }
    }
}
