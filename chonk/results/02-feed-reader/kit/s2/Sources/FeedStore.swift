// FILE: FeedStore.swift
import Foundation

@MainActor
@Observable
final class FeedStore {
    enum State: Equatable {
        case loading
        case empty
        case failed(String)
        case content([Article])
    }

    var state: State = .loading
    var refreshError: String?

    private let service: any FeedService

    init(service: any FeedService = URLSessionFeedService()) {
        self.service = service
    }

    func loadIfNeeded() async {
        if case .content = state { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            let articles = try await service.fetchArticles()
            state = articles.isEmpty ? .empty : .content(articles)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    func refresh() async {
        do {
            let articles = try await service.fetchArticles()
            refreshError = nil
            state = articles.isEmpty ? .empty : .content(articles)
        } catch {
            // A failed refresh must never overwrite the articles already on screen.
            if case .content = state {
                refreshError = Self.message(for: error)
            } else {
                state = .failed(Self.message(for: error))
            }
        }
    }

    private static func message(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return "Something went wrong while loading the feed. Please try again."
        }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "You appear to be offline. Check your connection, then retry."
        case .timedOut:
            return "The feed took too long to respond. Please retry."
        case .cannotFindHost, .cannotConnectToHost:
            return "The feed server could not be reached. Please retry."
        default:
            return "The feed could not be loaded. Please retry."
        }
    }
}
