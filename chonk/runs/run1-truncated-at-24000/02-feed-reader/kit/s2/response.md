Here is the complete app. The feed URL is a single constant in `FeedReaderApp.swift` (`https://jsonfeed.org/feed.json`, a real JSON Feed endpoint — swap it for any JSON Feed URL). It decodes both a JSON Feed envelope (`{"items": [...]}`) and a bare array of items.

```swift
// FILE: FeedReaderApp.swift
import SwiftUI

enum FeedConfiguration {
    /// JSON Feed (https://jsonfeed.org) endpoint that returns the latest articles.
    static let feedURLString = "https://jsonfeed.org/feed.json"
}

@main
struct FeedReaderApp: App {
    @State private var model = ArticleListModel(
        service: URLSessionFeedService(feedURLString: FeedConfiguration.feedURLString)
    )

    var body: some Scene {
        WindowGroup {
            ArticleListView(model: model)
                .tint(Theme.accent)
        }
    }
}
```

```swift
// FILE: Theme.swift
import SwiftUI

enum Theme {
    /// The single accent color used across the app.
    static let accent = Color.blue
}

enum Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}
```

```swift
// FILE: Article.swift
import Foundation

struct Article: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let body: String
    let author: String
    let publishedAt: Date
    let link: URL?

    init(
        id: String = UUID().uuidString,
        title: String,
        summary: String,
        body: String? = nil,
        author: String = "Unknown author",
        publishedAt: Date = .now,
        link: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.body = body ?? summary
        self.author = author
        self.publishedAt = publishedAt
        self.link = link
    }

    init(item: JSONFeedItem) {
        let html = item.contentHtml ?? ""
        let text = item.contentText ?? (html.isEmpty ? "" : plainText(fromHTML: html))
        let summarySource = item.summary ?? text

        self.id = item.id
        if let title = item.title, !title.isEmpty {
            self.title = title
        } else {
            self.title = "Untitled article"
        }
        var summary = summarySource
        if summary.count > 240 {
            summary = String(summary.prefix(240)) + "…"
        }
        self.summary = summary
        self.body = text.isEmpty ? summarySource : text
