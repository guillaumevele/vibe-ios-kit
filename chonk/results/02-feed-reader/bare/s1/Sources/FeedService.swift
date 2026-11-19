// FILE: FeedService.swift
import Foundation

/// A decoded feed document: an optional title plus its articles.
struct Feed: Decodable {
    let title: String?
    let items: [Article]

    enum CodingKeys: String, CodingKey {
        case title, items, articles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decode(String.self, forKey: .title)
        items =
            (try? container.decode([Article].self, forKey: .items))
            ?? (try? container.decode([Article].self, forKey: .articles))
            ?? []
    }
}

/// Errors thrown while loading a feed.
enum FeedError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpStatus(let code):
            return "The server returned an error (HTTP \(code))."
        case .decoding(let error):
            return "Could not parse the feed (\(error.localizedDescription))."
        }
    }
}

/// Downloads and decodes a JSON feed using only Foundation.
struct FeedService {
    /// The JSON feed shown by default. Swap this for any JSON Feed URL.
    static let defaultFeedURL = URL(string: "https://daringfireball.net/feeds/json")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the feed at `url` and returns its title and articles.
    func fetchFeed(from url: URL) async throws -> Feed {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json, text/plain;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("FeedReader/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.httpStatus(http.statusCode)
        }
        return try decode(data)
    }

    /// Decodes either a JSON Feed object (`{"items": [...]}`) or a bare array of articles.
    private func decode(_ data: Data) throws -> Feed {
        let decoder = JSONDecoder()
        if let feed = try? decoder.decode(Feed.self, from: data) {
            return feed
        }
        if let items = try? decoder.decode([Article].self, from: data) {
            return Feed(title: nil, items: items)
        }
        throw FeedError.decoding(URLError(.cannotDecodeContentData))
    }
}
