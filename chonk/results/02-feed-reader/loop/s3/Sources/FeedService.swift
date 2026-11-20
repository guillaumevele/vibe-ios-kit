// FILE: FeedService.swift
import Foundation

/// Anything that can produce the latest articles. Replace with a mock in previews.
protocol FeedService: Sendable {
    func fetchLatestArticles() async throws -> [Article]
}

enum FeedEndpoint {
    /// Hacker News front page, served as JSON. Hardcoded constant, so the force
    /// unwrap can never fail at runtime.
    static let latestArticles: URL = URL(string: "https://hn.algolia.com/api/v1/search?tags=front_page")!
}

struct LiveFeedService: FeedService {
    let endpoint: URL

    init(endpoint: URL = FeedEndpoint.latestArticles) {
        self.endpoint = endpoint
    }

    func fetchLatestArticles() async throws -> [Article] {
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FeedError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(FeedResponse.self, from: data).hits
        } catch {
            throw FeedError.invalidData
        }
    }
}

/// Preview/test double: returns fixed data or a fixed failure after a short delay.
struct MockFeedService: FeedService {
    let articles: [Article]
    let failure: FeedError?
    let delay: Duration

    init(articles: [Article] = [], failure: FeedError? = nil, delay: Duration = .milliseconds(600)) {
        self.articles = articles
        self.failure = failure
        self.delay = delay
    }

    func fetchLatestArticles() async throws -> [Article] {
        try await Task.sleep(for: delay)
        if let failure {
            throw failure
        }
        return articles
    }
}
