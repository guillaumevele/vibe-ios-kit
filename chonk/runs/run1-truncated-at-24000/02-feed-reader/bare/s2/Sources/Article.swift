// FILE: Article.swift
import Foundation

/// Top-level structure of the JSON feed.
struct FeedResponse: Decodable {
    let results: [ArticleDTO]
}

/// One raw entry from the feed, as decoded from JSON.
struct ArticleDTO: Decodable {
    let id: Int
    let title: String
    let url: String?
    let imageURL: String?
    let newsSite: String?
    let summary: String?
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case imageURL = "image_url"
        case newsSite = "news_site"
        case summary
        case publishedAt = "published_at"
    }
}

/// An article ready for display in the UI.
struct Article: Identifiable, Hashable {
    let id: Int
    let title: String
    let url: URL?
    let imageURL: URL?
    let newsSite: String
    let summary: String
    let publishedAt: Date

    init(dto: ArticleDTO) {
        self.id = dto.id
        self.title = dto.title
        self.url = dto.url.flatMap(URL.init(string:))
        self.imageURL = dto.imageURL.flatMap(URL.init(string:))
        self.newsSite = dto.newsSite ?? "Unknown source"
        self.summary = dto.summary ?? ""
        self.publishedAt = FeedDateParser.parse(dto.publishedAt ?? "") ?? Date()
    }

    var hasSummary: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// e.g. "2 hours ago"
    var relativePublished: String {
        publishedAt.formatted(.relative(presentation: .named))
    }

    /// e.g. "Jun 1, 2025 at 10:00 AM"
    var formattedPublished: String {
        publishedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Parses the ISO-8601 timestamps used by the feed.
enum FeedDateParser {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        fractional.date(from: string) ?? standard.date(from: string)
    }
}
