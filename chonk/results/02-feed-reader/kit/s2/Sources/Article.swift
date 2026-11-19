// FILE: Article.swift
import Foundation

struct Article: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let author: String
    let points: Int
    let url: URL?
    let publishedAt: Date
}

extension Article {
    static let sample = Article(
        id: "sample-1",
        title: "Swift 6 strict concurrency in practice",
        author: "ada",
        points: 128,
        url: URL(string: "https://example.com/swift-6"),
        publishedAt: Date.now.addingTimeInterval(-3600 * 3)
    )

    static let sample2 = Article(
        id: "sample-2",
        title: "Designing pull-to-refresh that feels native",
        author: "grace",
        points: 64,
        url: nil,
        publishedAt: Date.now.addingTimeInterval(-3600 * 26)
    )
}
