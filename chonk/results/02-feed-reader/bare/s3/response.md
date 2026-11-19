Here's a complete, single-target SwiftUI app (MVVM, `@Observable` view model, `NavigationStack` with a zoom transition, `refreshable` pull-to-refresh, and an async `URLSession` feed layer — Apple frameworks only). Set the deployment target to **iOS 26** in the project; to use a different feed, change `FeedService.feedURL` (the decoder accepts a top-level array or an object wrapping the array under `items`/`entries`/`results`/`posts`/`data`).

```swift
// FILE: FeedApp.swift
import SwiftUI

/// App entry point. Deployment target: iOS 26.
@main
struct FeedApp: App {
    var body: some Scene {
        WindowGroup {
            ArticleListView()
        }
    }
}
```

```swift
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
```

```swift
// FILE: FeedService.swift
import Foundation

/// Errors surfaced by the feed layer.
enum FeedError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case transport(String)
    case decoding(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The feed URL is invalid."
        case .httpStatus(let code):
            return "The feed returned HTTP \(code)."
        case .transport(let message):
            return "Network error: \(message)"
        case .decoding(let message):
            return "Could not parse the feed: \(message)"
        case .empty:
            return "The feed contains no articles."
        }
    }
}

/// Fetches and decodes articles from a JSON feed using only Foundation.
///
/// Point `feedURL` at any JSON feed whose payload is either a top-level
/// array of articles or an object wrapping the array under a common key
/// (`items`, `entries`, `results`, `posts`, `data`).
enum FeedService {
    /// Swap this for your own feed, e.g. an RSS-to-JSON endpoint.
    static var feedURL: URL? = URL(string: "https://jsonplaceholder.typicode.com/posts")

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    static func fetchArticles() async throws -> [Article] {
        guard let url = feedURL else { throw FeedError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Always hit the network so pull-to-refresh returns the latest items.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FeedError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FeedError.transport("Unexpected response type.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.httpStatus(http.statusCode)
        }

        let articles = try decode(data)
        guard !articles.isEmpty else { throw FeedError.empty }
        return articles
    }

    private static func decode(_ data: Data) throws -> [Article] {
        let decoder = JSONDecoder()

        // Preferred shape: a top-level array of articles.
        if let articles = try? decoder.decode([Article].self, from: data) {
            return articles
        }

        // Wrapped shapes: { "items": [...] }, { "entries": [...] }, etc.
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["items", "entries", "results", "posts", "data"] {
                guard let raw = object[key],
                      let arrayData = try? JSONSerialization.data(withJSONObject: raw),
                      let articles = try? decoder.decode([Article].self, from: arrayData)
                else { continue }
                return articles
            }
        }

        throw FeedError.decoding("Expected a JSON array of articles.")
    }
}
```

```swift
// FILE: ArticleListViewModel.swift
import Foundation
import Observation

/// State and actions for the article list. Main-actor isolated so SwiftUI
/// can bind to it directly.
@MainActor
@Observable
final class ArticleListViewModel {
    var articles: [Article] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var lastUpdated: Date?

    /// Loads only when there is nothing to show yet (first launch).
    func loadIfNeeded() async {
        guard articles.isEmpty, !isLoading else { return }
        await load()
    }

    /// Full (re)load; used on first launch and from the empty-state retry.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            articles = try await FeedService.fetchArticles()
            lastUpdated = Date()
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    /// Pull-to-refresh / toolbar refresh. Keeps existing articles on failure
    /// so the UI never goes blank because of a transient error.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            articles = try await FeedService.fetchArticles()
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
```

```swift
// FILE: Formatting.swift
import Foundation

/// Shared, cheap-to-create formatters.
enum Formatting {
    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// "2 hours ago", "yesterday", …
    static func relativeDate(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
```

```swift
// FILE: ArticleRowView.swift
import SwiftUI

/// A single row in the article list.
struct ArticleRowView: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(article.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let date = article.publishedAt {
                    Text(Formatting.relativeDate(date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var thumbnail: some View {
        AsyncImage(url: article.imageURL) { phase in
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
                EmptyView()
            }
        }
        .frame(width: 92, height: 68)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }
}
```

```swift
// FILE: ArticleListView.swift
import SwiftUI

/// Root screen: a pull-to-refresh list of the latest articles that pushes a
/// detail screen through a `NavigationStack` (with an iOS 18+ zoom transition).
struct ArticleListView: View {
    @State private var viewModel = ArticleListViewModel()
    @State private var path: [Article] = []
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Latest Articles")
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
                        .navigationTransition(.zoom(sourceID: article.id, in: zoom))
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isRefreshing)
                        .accessibilityLabel("Refresh")
                    }
                }
                .task {
                    await viewModel.loadIfNeeded()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.articles.isEmpty {
            ProgressView("Loading articles…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.articles.isEmpty {
            ContentUnavailableView {
                Label(
                    viewModel.errorMessage == nil ? "No articles" : "Couldn't load",
                    systemImage: viewModel.errorMessage == nil ? "tray" : "wifi.exclamationmark"
                )
            } description: {
                Text(viewModel.errorMessage ?? "Pull down to refresh the feed.")
            } actions: {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
            }
        } else {
            articleList
        }
    }

    private var articleList: some View {
        List {
            Section {
                ForEach(viewModel.articles) { article in
                    NavigationLink(value: article) {
                        ArticleRowView(article: article)
                    }
                    .matchedGeometryEffect(id: article.id, in: zoom)
                }
            } footer: {
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if let date = viewModel.lastUpdated {
                    Text("Updated \(Formatting.relativeDate(date))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refresh()
        }
        .sensoryFeedback(.success, trigger: viewModel.lastUpdated)
    }
}
```

```swift
// FILE: ArticleDetailView.swift
import SwiftUI

/// Full article screen: hero image, title, metadata, and the body rendered
/// as Markdown (falling back to plain text).
struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                heroImage

                Text(article.title)
                    .font(.title2.bold())

                metaRow

                Divider()

                Text(bodyText)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    // MARK: - Subviews

    private var heroImage: some View {
        AsyncImage(url: article.imageURL) { phase in
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
                EmptyView()
            }
        }
        .frame(height: 220)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            ProgressView()
        }
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 18) {
            if let date = article.publishedAt {
                Label(Formatting.relativeDate(date), systemImage: "clock")
            }
            if let userId = article.userId {
                Label("User #\(userId)", systemImage: "person")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let url = article.url.flatMap({ URL(string: $0) }) {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: url, subject: Text(article.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Link(destination: url) {
                    Image(systemName: "safari")
                }
                .accessibilityLabel("Open in Safari")
            }
        }
    }

    // MARK: - Helpers

    private var bodyText: AttributedString {
        (try? AttributedString(markdown: article.body)) ?? AttributedString(article.body)
    }
}
```

Notes:
- **Feed URL**: change `FeedService.feedURL` to any JSON endpoint. The decoder handles a bare array (`[{...}]`) or a wrapped object (`{"items": [...]}`), and `published_at` may be ISO-8601 or a Unix timestamp.
- **Pull to refresh**: `.refreshable` on the `List` plus a toolbar refresh button; failed refreshes keep the current articles and show the error in the section footer instead of blanking the UI.
- **Detail screen**: reached via `NavigationLink`/`navigationDestination` with a zoom transition; body renders as Markdown via `AttributedString`, with Share/Safari actions when the feed provides a `url`.
- Everything uses Apple frameworks only (`SwiftUI`, `Foundation`, `Observation`); images load with `AsyncImage` from a seeded placeholder service keyed by article id.