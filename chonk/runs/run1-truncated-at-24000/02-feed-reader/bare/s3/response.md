Here's a complete SwiftUI app (iOS 26, Apple frameworks only) that loads a JSON Feed, supports pull-to-refresh, and pushes a detail screen via `NavigationStack`. Change `FeedConfiguration.feedURLString` to point at your own JSON Feed (https://jsonfeed.org) URL.

```swift
// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @State private var viewModel = ArticlesViewModel()

    var body: some Scene {
        WindowGroup {
            ArticleListView()
                .environment(viewModel)
        }
    }
}
```

```swift
// FILE: FeedConfiguration.swift
import Foundation

enum FeedConfiguration {
    /// Replace this with your own JSON Feed (https://jsonfeed.org) URL.
    static let feedURLString = "https://www.jsonfeed.org/feed.json"
}
```

```swift
// FILE: FeedError.swift
import Foundation

enum FeedError: LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case decodingFailed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The feed URL is invalid."
        case .invalidResponse(let statusCode):
            return "The server returned an unexpected status code (\(statusCode))."
        case .decodingFailed:
            return "The feed could not be decoded. Check that it is valid JSON Feed."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}
```

```swift
// FILE: FeedService.swift
import Foundation

struct FeedService {
    let feedURLString: String

    init(feedURLString: String = FeedConfiguration.feedURLString) {
        self.feedURLString = feedURLString
    }

    func fetchFeed() async throws -> Feed {
        guard let url = URL(string: feedURLString) else {
            throw FeedError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FeedError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse(statusCode: -1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Feed.self, from: data)
        } catch {
            throw FeedError.decodingFailed
        }
    }
}
```

```swift
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
```

```swift
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
```

```swift
// FILE: Formatters.swift
import Foundation

enum FeedDateParser {
    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Parses RFC 3339 / ISO 8601 dates as used by JSON Feed.
    static func parse(_ string: String) -> Date? {
        fractional.date(from: string) ?? standard.date(from: string)
    }
}

extension Date {
    var feedRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var feedMedium: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
```

```swift
// FILE: HTMLContent.swift
import Foundation
import UIKit

enum HTMLContent {
    /// Converts an HTML string (e.g. JSON Feed `content_html`) into an AttributedString
    /// using only Apple frameworks, falling back to plain text on failure.
    static func attributedString(from html: String) -> AttributedString {
        guard let data = html.data(using: .utf8) else {
            return AttributedString(plainText(from: html))
        }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        do {
            let nsAttributed = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return AttributedString(nsAttributed)
        } catch {
            return AttributedString(plainText(from: html))
        }
    }

    /// Minimal HTML-to-plain-text fallback.
    static func plainText(from html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " "
        ]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text
    }

    static func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
```

```swift
// FILE: ArticlesViewModel.swift
import Foundation
import Observation

@Observable
final class ArticlesViewModel {
    var articles: [Article] = []
    var feedTitle = "Latest"
    var isLoading = false
    var error: Error?

    private let service: FeedService

    init(service: FeedService = FeedService()) {
        self.service = service
    }

    @MainActor
    func loadIfNeeded() async {
        guard articles.isEmpty, !isLoading else { return }
        await load()
    }

    @MainActor
    func refresh() async {
        await load()
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let feed = try await service.fetchFeed()
            articles = feed.items.sorted { lhs, rhs in
                (lhs.datePublished ?? .distantPast) > (rhs.datePublished ?? .distantPast)
            }
            if let title = feed.title, !title.isEmpty {
                feedTitle = title
            }
        } catch {
            // Keep showing stale articles on refresh failure; only surface the
            // error when there is nothing to display.
            if articles.isEmpty {
                self.error = error
            }
        }
    }
}
```

```swift
// FILE: RemoteImageView.swift
import SwiftUI

struct RemoteImageView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }
}
```

```swift
// FILE: ArticleRowView.swift
import SwiftUI

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        HStack(spacing: 12) {
            RemoteImageView(url: article.image)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(article.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let summary = article.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let date = article.datePublished {
                    Text(date.feedRelative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
```

```swift
// FILE: ArticleListView.swift
import SwiftUI

struct ArticleListView: View {
    @Environment(ArticlesViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            List(viewModel.articles) { article in
                NavigationLink(value: article) {
                    ArticleRowView(article: article)
                }
            }
            .navigationTitle(viewModel.feedTitle)
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadIfNeeded()
            }
            .overlay {
                if viewModel.articles.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.large)
                    } else if let error = viewModel.error {
                        ContentUnavailableView {
                            Label("Couldn't Load Articles", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(error.localizedDescription)
                        } actions: {
                            Button("Try Again") {
                                Task { await viewModel.refresh() }
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "No Articles",
                            systemImage: "doc.text",
                            description: Text("Pull down to refresh.")
                        )
                    }
                }
            }
        }
    }
}
```

```swift
// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteImageView(url: article.image)
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text(article.displayTitle)
                        .font(.title2.bold())

                    HStack(spacing: 12) {
                        if let author = article.author {
                            Label(author, systemImage: "person.fill")
                        }
                        if let date = article.datePublished {
                            Label(date.feedMedium, systemImage: "calendar")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Divider()

                    Text(article.bodyAttributed)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(article.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = article.url {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
```