// FILE: RootView.swift
import SwiftUI

struct RootView: View {
    let store: FeedStore

    var body: some View {
        NavigationStack {
            ArticleListView(store: store)
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
                }
        }
    }
}
