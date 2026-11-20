// FILE: ArticlesViewModel.swift
import Foundation
import Observation

@Observable
final class ArticlesViewModel {
    var articles: [Article] = []
    var feedTitle = "Latest"
    var isLoading = false
    var error: Error?

    private let service: FeedService

    init(service: FeedService = FeedService()) {
        self.service = service
    }

    @MainActor
    func loadIfNeeded() async {
        guard articles.isEmpty, !isLoading else { return }
        await load()
    }

    @MainActor
    func refresh() async {
        await load()
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let feed = try await service.fetchFeed()
            articles = feed.items.sorted { lhs, rhs in
                (lhs.datePublished ?? .distantPast) > (rhs.datePublished ?? .distantPast)
            }
            if let title = feed.title, !title.isEmpty {
                feedTitle = title
            }
        } catch {
            // Keep showing stale articles on refresh failure; only surface the
            // error when there is nothing to display.
            if articles.isEmpty {
                self.error = error
            }
        }
    }
}
