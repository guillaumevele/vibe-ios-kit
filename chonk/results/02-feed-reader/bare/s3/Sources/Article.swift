// FILE: Article.swift
import Foundation

/// A single article decoded from the JSON feed.
///
/// The decoder is tolerant so the same model works with most JSON feeds:
/// `title`/`body` fall back to empty strings, and `published_at` accepts
/// ISO-8601 strings or Unix timestamps.
struct Article: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let title: String
    let body: String
    let userId: Int?
    let url: String?
    let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case userId
        case url
        case publishedAt = "published_at"
    }

    init(
        id: Int,
        title: String,
        body: String,
        userId: Int? = nil,
        url: String? = nil,
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.userId = userId
        self.url = url
        self.publishedAt = publishedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        url = try container.decodeIfPresent(String.self, forKey: .url)

        let rawString = try? container.decodeIfPresent(String.self, forKey: .publishedAt)
        if let rawString, let date = Self.parseDate(rawString) {
            publishedAt = date
        } else if let seconds = try? container.decodeIfPresent(TimeInterval.self, forKey: .publishedAt) {
            publishedAt = Date(timeIntervalSince1970: seconds)
        } else {
            publishedAt = nil
        }
    }

    /// Placeholder artwork derived from the id so every row has an image.
    var imageURL: URL? {
        URL(string: "https://picsum.photos/seed/article-\(id)/800/450")
    }

    /// Single-line preview of the body for list rows.
    var excerpt: String {
        body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDate(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
