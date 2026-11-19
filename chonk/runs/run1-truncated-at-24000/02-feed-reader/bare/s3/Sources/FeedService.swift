// FILE: FeedService.swift
import Foundation

struct FeedService {
    let feedURLString: String

    init(feedURLString: String = FeedConfiguration.feedURLString) {
        self.feedURLString = feedURLString
    }

    func fetchFeed() async throws -> Feed {
        guard let url = URL(string: feedURLString) else {
            throw FeedError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FeedError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse(statusCode: -1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Feed.self, from: data)
        } catch {
            throw FeedError.decodingFailed
        }
    }
}
