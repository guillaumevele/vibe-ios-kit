// FILE: Article.swift
import Foundation

/// One story from the JSON feed. Sendable so it can cross `await` boundaries.
struct Article: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let author: String
    let url: URL?
    let points: Int
    let commentCount: Int
    let createdAt: Date
}

extension Article: Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "objectID"
        case title
        case author
        case url
        case points
        case commentCount = "num_comments"
        case createdAt = "created_at"
    }
}

/// Top-level shape of the feed response.
struct FeedResponse: Decodable, Sendable {
    let hits: [Article]
}

enum FeedError: Error, Sendable, Equatable {
    case invalidURL
    case invalidResponse
    case invalidData
}

extension Article {
    static let previewArticles: [Article] = [
        Article(
            id: "1",
            title: "Swift 6 concurrency in practice: actors, Sendable and async streams",
            author: "swiftfan",
            url: URL(string: "https://example.com/swift6"),
            points: 342,
            commentCount: 128,
            createdAt: Date().addingTimeInterval(-3600 * 5)
        ),
        Article(
            id: "2",
            title: "Designing pull-to-refresh that feels native",
            author: "uidesign",
            url: nil,
            points: 87,
            commentCount: 41,
            createdAt: Date().addingTimeInterval(-3600 * 26)
        ),
        Article(
            id: "3",
            title: "A field guide to SF Symbols",
            author: "symbols",
            url: URL(string: "https://example.com/symbols"),
            points: 512,
            commentCount: 203,
            createdAt: Date().addingTimeInterval(-3600 * 50)
        )
    ]
}
