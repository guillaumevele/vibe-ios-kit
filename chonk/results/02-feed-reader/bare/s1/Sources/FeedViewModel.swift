// FILE: FeedViewModel.swift
import Foundation
import Observation

/// Observable state for the article list: articles, loading flags, and errors.
@Observable
@MainActor
final class FeedViewModel {
    var articles: [Article] = []
    var isLoading = false
    var isRefreshing = false
    var lastUpdated: Date?
    var errorMessage: String?
    var feedTitle = "Latest Articles"

    private let service: FeedService
    private let feedURL: URL

    init(service: FeedService = FeedService(), feedURL: URL? = nil) {
        self.service = service
        self.feedURL = feedURL ?? FeedService.defaultFeedURL
    }

    /// Loads the feed on first appearance. Pull-to-refresh calls `refresh()` directly.
    func loadIfNeeded() async {
        guard articles.isEmpty, !isLoading, !isRefreshing else { return }
        await refresh()
    }

    /// Fetches the latest articles. Safe to call from pull-to-refresh or a button.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = articles.isEmpty
        errorMessage = nil
        defer {
            isRefreshing = false
            isLoading = false
        }

        do {
            let feed = try await service.fetchFeed(from: feedURL)
            articles = feed.items
            lastUpdated = Date()
            if let title = feed.title, !title.isEmpty {
                feedTitle = title
            }
        } catch {
            // Keep showing previously loaded articles; surface the error so the UI can offer a retry.
            if let localizedError = error as? LocalizedError,
               let description = localizedError.errorDescription {
                errorMessage = description
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
