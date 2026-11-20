// FILE: FeedService.swift
import Foundation

enum FeedError: LocalizedError {
    case invalidURL
    case badResponse(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The feed URL is invalid."
        case .badResponse(let code):
            return "The server returned status \(code)."
        case .decoding(let error):
            return "Could not parse the feed: \(error.localizedDescription)"
        }
    }
}

struct FeedService {
    /// Replace this with your own JSON feed endpoint.
    static let defaultFeedURL = URL(string: "https://jsonplaceholder.typicode.com/posts")!

    let feedURL: URL
    private let session: URLSession

    init(feedURL: URL = FeedService.defaultFeedURL, session: URLSession = .shared) {
        self.feedURL = feedURL
        self.session = session
    }

    func fetchArticles() async throws -> [Article] {
        guard feedURL.scheme != nil else { throw FeedError.invalidURL }

        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("FeedReader/1.0 (iOS 26)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FeedError.badResponse(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.badResponse(http.statusCode)
        }

        return try Self.decode(data)
    }

    private static func decode(_ data: Data) throws -> [Article] {
        let decoder = JSONDecoder()

        var arrayError: Error?
        do {
            return try decoder.decode([Article].self, from: data)
        } catch {
            arrayError = error
        }

        do {
            let envelope = try decoder.decode(Envelope.self, from: data)
            if !envelope.all.isEmpty {
                return envelope.all
            }
        } catch {
            // Fall through to the error below.
        }

        throw FeedError.decoding(
            arrayError ?? NSError(
                domain: "FeedService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognized feed format"]
            )
        )
    }

    private struct Envelope: Decodable {
        let items: [Article]?
        let articles: [Article]?
        let results: [Article]?
        let entries: [Article]?
        let data: [Article]?

        var all: [Article] {
            items ?? articles ?? results ?? entries ?? data ?? []
        }
    }
}
