// FILE: FeedViewModel.swift
import Foundation

@Observable
@MainActor
final class FeedViewModel {
    /// The four states of the screen, as one enum.
    enum State: Equatable {
        case loading
        case loaded([Article])
        case empty
        case failed(String)
    }

    var state: State = .loading
    /// Set when a pull-to-refresh fails while articles are already on screen.
    /// The existing articles are kept; the failure is only surfaced as a banner.
    var refreshError: String?

    private let service: FeedService
    private var hasStarted = false

    init(service: FeedService) {
        self.service = service
    }

    /// Called once from the view's `.task`. Safe to call again; only the first call loads.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await load()
    }

    func load() async {
        state = .loading
        do {
            let articles = try await service.fetchLatestArticles()
            refreshError = nil
            state = articles.isEmpty ? .empty : .loaded(articles)
        } catch {
            state = .failed(userMessage(for: error))
        }
    }

    func refresh() async {
        do {
            let articles = try await service.fetchLatestArticles()
            refreshError = nil
            state = articles.isEmpty ? .empty : .loaded(articles)
        } catch {
            // A failed refresh must never overwrite the articles already on screen.
            refreshError = userMessage(for: error)
        }
    }

    private func userMessage(for error: Error) -> String {
        if let feedError = error as? FeedError {
            switch feedError {
            case .invalidURL, .invalidResponse:
                return "The feed returned an unexpected response. Please try again."
            case .invalidData:
                return "The feed could not be read. Please try again."
            }
        }
        if error is URLError {
            return "Could not reach the feed. Check your internet connection and try again."
        }
        return "Something went wrong while loading. Please try again."
    }
}
