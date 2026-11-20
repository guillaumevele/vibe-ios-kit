// FILE: Article.swift
import Foundation

struct Article: Identifiable, Hashable, Decodable {
    let id: String
    let title: String
    let summary: String
    let url: URL?
    let author: String?
    let published: Date?
    let imageURL: URL?

    // MARK: - Flexible decoding (accepts common feed key names and scalar types)

    private struct AnyKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)

        func string(_ keys: [String]) -> String? {
            for key in keys {
                guard let k = AnyKey(stringValue: key), c.contains(k) else { continue }
                if let value = try? c.decode(String.self, forKey: k) { return value }
                if let value = try? c.decode(Int.self, forKey: k) { return String(value) }
                if let value = try? c.decode(Double.self, forKey: k) { return String(value) }
                if let value = try? c.decode(Bool.self, forKey: k) { return value ? "true" : "false" }
            }
            return nil
        }

        func url(_ keys: [String]) -> URL? {
            guard let raw = string(keys), !raw.isEmpty else { return nil }
            return URL(string: raw)
        }

        func date(_ keys: [String]) -> Date? {
            guard let raw = string(keys), !raw.isEmpty else { return nil }
            return Article.parseDate(raw)
        }

        id = string(["id", "guid", "uid", "link", "url"]) ?? UUID().uuidString
        title = string(["title", "name", "headline"]) ?? "(Untitled)"
        summary = string(["summary", "description", "excerpt", "body", "content", "content_text", "text"]) ?? ""
        url = url(["url", "link", "href", "web_url"])
        author = string(["author", "author_name", "creator", "byline"])
        published = date(["published", "published_at", "pubDate", "pub_date", "date", "date_published", "created_at", "updated_at"])
        imageURL = url(["image", "image_url", "imageURL", "thumbnail", "media", "enclosure"])
    }

    private static func parseDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "EEE, dd MMM yyyy HH:mm:ss Z"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    var publishedText: String {
        guard let published else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: published, relativeTo: Date())
    }
}
