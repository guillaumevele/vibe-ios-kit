// FILE: ArticleListViewModel.swift
import Foundation
import Observation

/// State and actions for the article list. Main-actor isolated so SwiftUI
/// can bind to it directly.
@MainActor
@Observable
final class ArticleListViewModel {
    var articles: [Article] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var lastUpdated: Date?

    /// Loads only when there is nothing to show yet (first launch).
    func loadIfNeeded() async {
        guard articles.isEmpty, !isLoading else { return }
        await load()
    }

    /// Full (re)load; used on first launch and from the empty-state retry.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            articles = try await FeedService.fetchArticles()
            lastUpdated = Date()
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    /// Pull-to-refresh / toolbar refresh. Keeps existing articles on failure
    /// so the UI never goes blank because of a transient error.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            articles = try await FeedService.fetchArticles()
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
