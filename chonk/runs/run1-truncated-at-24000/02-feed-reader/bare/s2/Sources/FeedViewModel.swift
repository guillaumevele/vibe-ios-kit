// FILE: FeedViewModel.swift
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let service: FeedService
    private var hasLoadedOnce = false

    init(service: FeedService = .shared) {
        self.service = service
    }

    /// Loads the feed the first time the list appears.
    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await refresh()
    }

    /// Fetches the latest articles. Called on first load and by pull-to-refresh.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            articles = try await service.fetchLatestArticles()
            lastUpdated = Date()
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
