// FILE: FeedDTO.swift
import Foundation

/// Decoding shapes for the JSON Feed spec (https://jsonfeed.org), version 1.1.
struct FeedDTO: Decodable, Sendable {
    let items: [ItemDTO]
}

struct ItemDTO: Decodable, Sendable {
    let id: String?
    let url: String?
    let title: String?
    let summary: String?
    let contentHTML: String?
    let contentText: String?
    let image: String?
    let datePublished: String?
    let author: AuthorDTO?
    let authors: [AuthorDTO]?

    enum CodingKeys: String, CodingKey {
        case id, url, title, summary, image, author, authors
        case contentHTML = "content_html"
        case contentText = "content_text"
        case datePublished = "date_published"
    }
}

struct AuthorDTO: Decodable, Sendable {
    let name: String?
}
