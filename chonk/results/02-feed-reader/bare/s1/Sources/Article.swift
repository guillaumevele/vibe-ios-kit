// FILE: Article.swift
import Foundation

/// A single article decoded from a JSON Feed (https://jsonfeed.org) document.
/// The decoder tolerates a few alternative key names so the app also works with
/// feeds that are not strictly JSON-Feed compliant.
struct Article: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    var summary: String?
    var contentHTML: String?
    var url: URL?
    var imageURL: URL?
    var datePublished: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case objectID
        case title
        case summary
        case contentHTML = "content_html"
        case contentText = "content_text"
        case url
        case image
        case bannerImage = "banner_image"
        case datePublished = "date_published"
        case dateModified = "date_modified"
        case createdAt = "created_at"
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        summary: String? = nil,
        contentHTML: String? = nil,
        url: URL? = nil,
        imageURL: URL? = nil,
        datePublished: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.contentHTML = contentHTML
        self.url = url
        self.imageURL = imageURL
        self.datePublished = datePublished
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else if let intID = try? container.decode(Int.self, forKey: .objectID) {
            id = String(intID)
        } else if let stringObjectID = try? container.decode(String.self, forKey: .objectID) {
            id = stringObjectID
        } else {
            id = UUID().uuidString
        }

        title = (try? container.decode(String.self, forKey: .title)) ?? "(Untitled)"
        summary = try? container.decode(String.self, forKey: .summary)
        contentHTML =
            (try? container.decode(String.self, forKey: .contentHTML))
            ?? (try? container.decode(String.self, forKey: .contentText))
        url = try? container.decode(URL.self, forKey: .url)
        imageURL =
            (try? container.decode(URL.self, forKey: .image))
            ?? (try? container.decode(URL.self, forKey: .bannerImage))

        let dateString =
            (try? container.decode(String.self, forKey: .datePublished))
            ?? (try? container.decode(String.self, forKey: .dateModified))
            ?? (try? container.decode(String.self, forKey: .createdAt))
        datePublished = dateString.flatMap(Self.parseDate)
    }

    /// Human-readable publication date, e.g. "Mar 4, 2026".
    var displayDate: String? {
        datePublished?.formatted(date: .abbreviated, time: .omitted)
    }

    /// Summary with any HTML tags removed, suitable for plain-text display.
    var plainSummary: String? {
        summary?.strippedOfHTML
    }

    // MARK: - Date parsing

    private static func parseDate(_ string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) { return date }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: string) { return date }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = fallback.date(from: string) { return date }
        fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fallback.date(from: string)
    }
}
