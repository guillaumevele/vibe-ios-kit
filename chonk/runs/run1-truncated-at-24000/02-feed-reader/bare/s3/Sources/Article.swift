// FILE: Article.swift
import Foundation

struct FeedAuthor: Decodable {
    let name: String?
}

struct Article: Identifiable, Hashable, Decodable {
    let id: String
    let url: URL?
    let title: String?
    let summary: String?
    let contentHTML: String?
    let datePublished: Date?
    let image: URL?
    let author: String?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case title
        case summary
        case image
        case bannerImage = "banner_image"
        case author
        case authors
        case contentHTML = "content_html"
        case contentText = "content_text"
        case datePublished = "date_published"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        url = (try? container.decode(String.self, forKey: .url)).flatMap { URL(string: $0) }
        title = try? container.decode(String.self, forKey: .title)
        summary = try? container.decode(String.self, forKey: .summary)

        image = (try? container.decode(String.self, forKey: .image)).flatMap { URL(string: $0) }
            ?? (try? container.decode(String.self, forKey: .bannerImage)).flatMap { URL(string: $0) }

        if let dateString = try? container.decode(String.self, forKey: .datePublished) {
            datePublished = FeedDateParser.parse(dateString)
        } else {
            datePublished = nil
        }

        if let html = try? container.decode(String.self, forKey: .contentHTML) {
            contentHTML = html
        } else if let text = try? container.decode(String.self, forKey: .contentText) {
            contentHTML = "<p>\(HTMLContent.escaped(text))</p>"
        } else {
            contentHTML = nil
        }

        if let authors = try? container.decode([FeedAuthor].self, forKey: .authors),
           let name = authors.compactMap(\.name).first {
            author = name
        } else {
            author = try? container.decode(String.self, forKey: .author)
        }
    }

    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return "Untitled"
    }

    var bodyAttributed: AttributedString {
        if let contentHTML, !contentHTML.isEmpty {
            return HTMLContent.attributedString(from: contentHTML)
        }
        if let summary, !summary.isEmpty {
            return AttributedString(summary)
        }
        return AttributedString("No content available.")
    }
}
