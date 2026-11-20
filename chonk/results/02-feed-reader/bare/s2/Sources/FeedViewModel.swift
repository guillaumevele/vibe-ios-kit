// FILE: FeedViewModel.swift
import Foundation

@MainActor
@Observable
final class FeedViewModel {
    var articles: [Article] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    private let service: FeedService

    init(service: FeedService = FeedService()) {
        self.service = service
    }

    func load(force: Bool = false) async {
        guard !isLoading else { return }
        if !force && !articles.isEmpty { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchArticles()
            articles = fetched
            lastUpdated = Date()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refresh() async {
        await load(force: true)
    }
}
