// FILE: FeedService.swift
import Foundation

protocol FeedService: Sendable {
    func fetchArticles() async throws -> [Article]
}

struct URLSessionFeedService: FeedService {
    private let feedURLString = "https://hn.algolia.com/api/v1/search_by_date?query=swift&tags=story&hitsPerPage=30"

    func fetchArticles() async throws -> [Article] {
        guard let url = URL(string: feedURLString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let feed = try JSONDecoder().decode(FeedResponse.self, from: data)

        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        return feed.hits.compactMap { hit in
            guard let title = hit.title, !title.isEmpty else { return nil }
            let date = withFractionalSeconds.date(from: hit.created_at)
                ?? plain.date(from: hit.created_at)
                ?? Date.now
            return Article(
                id: hit.objectID,
                title: title,
                author: hit.author ?? "unknown",
                points: hit.points ?? 0,
                url: hit.url.flatMap { URL(string: $0) },
                publishedAt: date
            )
        }
    }
}

private struct FeedResponse: Decodable {
    let hits: [Hit]
}

private struct Hit: Decodable {
    let objectID: String
    let title: String?
    let author: String?
    let points: Int?
    let url: String?
    let created_at: String
}
