// FILE: Feed.swift
import Foundation

struct Feed: Decodable {
    let title: String?
    let items: [Article]

    enum CodingKeys: String, CodingKey {
        case title
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decode(String.self, forKey: .title)
        items = (try? container.decode([Article].self, forKey: .items)) ?? []
    }
}
