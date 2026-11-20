// FILE: FeedService.swift
import Foundation

/// Configuration for the remote JSON feed.
enum FeedConfiguration {
    /// Latest-articles endpoint (Spaceflight News API v4 — no API key required).
    /// Swap this URL for any other JSON feed with a compatible shape.
    static let articlesURL = URL(
        string: "https://api.spaceflightnewsapi.com/v4/articles/?limit=20&ordering=-published_at"
    )!
}

enum FeedError: LocalizedError {
    case badStatusCode(Int)
    case decodingFailed(DecodingError)

    var errorDescription: String? {
        switch self {
        case .badStatusCode(let code):
            return "The feed server responded with status code \(code)."
        case .decodingFailed(let error):
            return "The feed could not be decoded (\(error.localizedDescription))."
        }
    }
}

/// Fetches and decodes the article feed using only URLSession.
final class FeedService {
    static let shared = FeedService()

    private let feedURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(feedURL: URL = FeedConfiguration.articlesURL, session: URLSession = .shared) {
        self.feedURL = feedURL
        self.session = session
    }

    func fetchLatestArticles() async throws -> [Article] {
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData // pull-to-refresh always gets fresh data
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.badStatusCode(-1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.badStatusCode(httpResponse.statusCode)
        }

        do {
            let feed = try decoder.decode(FeedResponse.self, from: data)
            return feed.results.map(Article.init(dto:))
        } catch let decodingError as DecodingError {
            throw FeedError.decodingFailed(decodingError)
        }
    }
}
