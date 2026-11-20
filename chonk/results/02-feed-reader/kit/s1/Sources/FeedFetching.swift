// FILE: FeedFetching.swift
import Foundation

/// Anything that can load articles from a URL. Replaced by a stub in previews.
protocol FeedFetching: Sendable {
    func fetchArticles(from url: URL) async throws -> [Article]
}
