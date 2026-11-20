// FILE: URLSessionFeedFetcher.swift
import Foundation

struct URLSessionFeedFetcher: FeedFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchArticles(from url: URL) async throws -> [Article] {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.unexpectedResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.httpStatus(httpResponse.statusCode)
        }

        do {
            let feed = try JSONDecoder().decode(FeedDTO.self, from: data)
            return feed.items
                .map(Article.init(dto:))
                .sorted { $0.date > $1.date }
        } catch let decodingError as DecodingError {
            throw FeedError.invalidData(underlying: String(describing: decodingError))
        }
    }
}
