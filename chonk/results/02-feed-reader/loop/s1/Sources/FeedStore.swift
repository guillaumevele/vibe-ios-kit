// FILE: FeedStore.swift
import Foundation

@Observable
@MainActor
final class FeedStore {
    enum State: Equatable {
        case loading
        case refreshing([Article])
        case loaded([Article])
        case empty
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var refreshNotice: String?

    private let fetcher: any FeedFetching
    private let feedURL: URL

    init(fetcher: any FeedFetching, feedURL: URL) {
        self.fetcher = fetcher
        self.feedURL = feedURL
    }

    func load() async {
        state = .loading
        refreshNotice = nil
        await fetch()
    }

    func refresh() async {
        if case .loaded(let articles) = state {
            state = .refreshing(articles)
        }
        await fetch()
    }

    private func fetch() async {
        do {
            let articles = try await fetcher.fetchArticles(from: feedURL)
            refreshNotice = nil
            state = articles.isEmpty ? .empty : .loaded(articles)
        } catch {
            let message = Self.userFacingMessage(for: error)
            switch state {
            case .loaded(let articles), .refreshing(let articles):
                // A failed refresh must never overwrite the articles already on screen.
                state = .loaded(articles)
                refreshNotice = message
            case .loading, .empty, .failed:
                state = .failed(message)
            }
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        switch error {
        case let feedError as FeedError:
            return feedError.errorDescription ?? "The feed could not be loaded."
        case is URLError:
            return "Could not reach the feed. Check your internet connection, then try again."
        case is DecodingError:
            return "The feed could not be read because its format was not recognized."
        default:
            return "Something went wrong while loading the feed. Please try again."
        }
    }
}
