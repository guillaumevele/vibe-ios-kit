// FILE: FeedService.swift
import Foundation

/// Errors surfaced by the feed layer.
enum FeedError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case transport(String)
    case decoding(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The feed URL is invalid."
        case .httpStatus(let code):
            return "The feed returned HTTP \(code)."
        case .transport(let message):
            return "Network error: \(message)"
        case .decoding(let message):
            return "Could not parse the feed: \(message)"
        case .empty:
            return "The feed contains no articles."
        }
    }
}

/// Fetches and decodes articles from a JSON feed using only Foundation.
///
/// Point `feedURL` at any JSON feed whose payload is either a top-level
/// array of articles or an object wrapping the array under a common key
/// (`items`, `entries`, `results`, `posts`, `data`).
enum FeedService {
    /// Swap this for your own feed, e.g. an RSS-to-JSON endpoint.
    static var feedURL: URL? = URL(string: "https://jsonplaceholder.typicode.com/posts")

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    static func fetchArticles() async throws -> [Article] {
        guard let url = feedURL else { throw FeedError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Always hit the network so pull-to-refresh returns the latest items.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FeedError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FeedError.transport("Unexpected response type.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.httpStatus(http.statusCode)
        }

        let articles = try decode(data)
        guard !articles.isEmpty else { throw FeedError.empty }
        return articles
    }

    private static func decode(_ data: Data) throws -> [Article] {
        let decoder = JSONDecoder()

        // Preferred shape: a top-level array of articles.
        if let articles = try? decoder.decode([Article].self, from: data) {
            return articles
        }

        // Wrapped shapes: { "items": [...] }, { "entries": [...] }, etc.
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["items", "entries", "results", "posts", "data"] {
                guard let raw = object[key],
                      let arrayData = try? JSONSerialization.data(withJSONObject: raw),
                      let articles = try? decoder.decode([Article].self, from: arrayData)
                else { continue }
                return articles
            }
        }

        throw FeedError.decoding("Expected a JSON array of articles.")
    }
}
