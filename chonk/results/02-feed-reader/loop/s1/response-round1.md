Fixed the two compiler errors in `Article.swift`: the date parsing now uses explicitly typed `Date.ISO8601FormatStyle` values (implicit-member chains like `.iso8601.withFractionalSeconds()` have no contextual type inside `Date(_:strategy:)`), and both `replacingOccurrences` calls now use the correct `of:with:options:` argument order. The deprecation bullet arrived with no symbol name; the only diagnostics the gate reported were those two lines, so the rest of the set is unchanged. Complete files:

```swift
// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @State private var store: FeedStore

    init() {
        guard let feedURL = URL(string: FeedConfiguration.feedURLString) else {
            preconditionFailure("FeedConfiguration.feedURLString must be a valid URL")
        }
        _store = State(initialValue: FeedStore(fetcher: URLSessionFeedFetcher(), feedURL: feedURL))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
```

```swift
// FILE: RootView.swift
import SwiftUI

struct RootView: View {
    let store: FeedStore

    var body: some View {
        NavigationStack {
            ArticleListView(store: store)
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
                }
        }
    }
}
```

```swift
// FILE: FeedConfiguration.swift
import Foundation

enum FeedConfiguration {
    /// JSON Feed endpoint that returns the latest articles.
    /// Swap this single string to point the app at a different JSON Feed.
    static let feedURLString = "https://jsonfeed.org/feed.json"
}
```

```swift
// FILE: Spacing.swift
import SwiftUI

enum Spacing {
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
    let contentHTML: String
    let contentText: String
    let url: URL?
    let imageURL: URL?
    let author: String?
    let date: Date

    // Parsers are static so they are created once, never on every render.
    // The concrete type is written out explicitly: implicit member syntax
    // such as `.iso8601` has no contextual type inside `Date(_:strategy:)`
    // and does not compile.
    private static let iso8601Parser = Date.ISO8601FormatStyle()
    private static let iso8601FractionalParser = Date.ISO8601FormatStyle().withFractionalSeconds()

    init(dto: ItemDTO) {
        id = dto.id ?? dto.url ?? UUID().uuidString

        let rawTitle = (dto.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        title = rawTitle.isEmpty ? "Untitled article" : rawTitle

        contentHTML = dto.contentHTML ?? ""
        contentText = dto.contentText ?? (contentHTML.isEmpty ? "" : Article.plainText(fromHTML: contentHTML))

        let rawSummary = (dto.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        summary = rawSummary.isEmpty ? String(contentText.prefix(200)) : rawSummary

        url = dto.url.flatMap { URL(string: $0) }
        imageURL = dto.image.flatMap { URL(string: $0) }
        author = dto.authors?.compactMap(\.name).first ?? dto.author?.name

        let rawDate = dto.datePublished ?? ""
        date = (try? Date(rawDate, strategy: Self.iso8601Parser))
            ?? (try? Date(rawDate, strategy: Self.iso8601FractionalParser))
            ?? .now
    }

    /// Renders the HTML body once, outside of any view body.
    func renderedBody() -> AttributedString {
        guard !contentHTML.isEmpty, let htmlData = contentHTML.data(using: .utf8) else {
            return AttributedString(contentText)
        }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let nsAttributed = try? NSAttributedString(data: htmlData, options: options, documentAttributes: nil) {
            return AttributedString(nsAttributed)
        }
        return AttributedString(contentText)
    }

    private static func plainText(fromHTML html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&nbsp;": " "
        ]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

```swift
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
```

```swift
// FILE: FeedError.swift
import Foundation

enum FeedError: LocalizedError, Sendable {
    case unexpectedResponse
    case httpStatus(Int)
    case invalidData(underlying: String)

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse:
            return "The feed sent a response that could not be understood."
        case .httpStatus(let statusCode):
            return "The feed server returned an error (status \(statusCode))."
        case .invalidData:
            return "The feed data could not be parsed."
        }
    }
}
```

```swift
// FILE: FeedFetching.swift
import Foundation

/// Anything that can load articles from a URL. Replaced by a stub in previews.
protocol FeedFetching: Sendable {
    func fetchArticles(from url: URL) async throws -> [Article]
}
```

```swift
// FILE: URLSessionFeedFetcher.swift
import Foundation

struct URLSessionFeedFetcher: FeedFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchArticles(from url: URL) async throws -> [Article] {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.unexpectedResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.httpStatus(httpResponse.statusCode)
        }

        do {
            let feed = try JSONDecoder().decode(FeedDTO.self, from: data)
            return feed.items
                .map(Article.init(dto:))
                .sorted { $0.date > $1.date }
        } catch let decodingError as DecodingError {
            throw FeedError.invalidData(underlying: String(describing: decodingError))
        }
    }
}
```

```swift
// FILE: FeedStore.swift
import Foundation

@Observable
@MainActor
final class FeedStore {
    enum State: Equatable {
        case loading
        case refreshing([Article])
        case loaded([Article])
        case empty
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var refreshNotice: String?

    private let fetcher: any FeedFetching
    private let feedURL: URL

    init(fetcher: any FeedFetching, feedURL: URL) {
        self.fetcher = fetcher
        self.feedURL = feedURL
    }

    func load() async {
        state = .loading
        refreshNotice = nil
        await fetch()
    }

    func refresh() async {
        if case .loaded(let articles) = state {
            state = .refreshing(articles)
        }
        await fetch()
    }

    private func fetch() async {
        do {
            let articles = try await fetcher.fetchArticles(from: feedURL)
            refreshNotice = nil
            state = articles.isEmpty ? .empty : .loaded(articles)
        } catch {
            let message = Self.userFacingMessage(for: error)
            switch state {
            case .loaded(let articles), .refreshing(let articles):
                // A failed refresh must never overwrite the articles already on screen.
                state = .loaded(articles)
                refreshNotice = message
            case .loading, .empty, .failed:
                state = .failed(message)
            }
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        switch error {
        case let feedError as FeedError:
            return feedError.errorDescription ?? "The feed could not be loaded."
        case is URLError:
            return "Could not reach the feed. Check your internet connection, then try again."
        case is DecodingError:
            return "The feed could not be read because its format was not recognized."
        default:
            return "Something went wrong while loading the feed. Please try again."
        }
    }
}
```

```swift
// FILE: ArticleListView.swift
import SwiftUI

struct ArticleListView: View {
    let store: FeedStore

    var body: some View {
        Group {
            switch store.state {
            case .loading:
                ProgressView("Loading articles")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .empty:
                ContentUnavailableView {
                    Label("No articles yet", systemImage: "tray")
                } description: {
                    Text("Pull down to check for new articles.")
                } actions: {
                    Button("Check again") {
                        Task { await store.refresh() }
                    }
                }

            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't load articles", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry", systemImage: "arrow.clockwise") {
                        Task { await store.load() }
                    }
                }

            case .loaded(let articles), .refreshing(let articles):
                ArticleList(articles: articles, notice: store.refreshNotice) {
                    await store.refresh()
                }
            }
        }
        .navigationTitle("Latest Articles")
        .task {
            await store.load()
        }
    }
}

private struct ArticleList: View {
    let articles: [Article]
    let notice: String?
    let onRefresh: @Sendable () async -> Void

    var body: some View {
        List {
            if let notice {
                Section {
                    HStack(spacing: Spacing.small) {
                        Label(notice, systemImage: "wifi.slash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") {
                            Task { await onRefresh() }
                        }
                        .font(.subheadline)
                    }
                }
            }
            ForEach(articles) { article in
                NavigationLink(value: article) {
                    ArticleRow(article: article)
                }
            }
        }
        .refreshable(action: onRefresh)
    }
}

private struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)
                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(article.date, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the full article")
    }
}

private struct StubFeedFetcher: FeedFetching {
    func fetchArticles(from url: URL) async throws -> [Article] {
        try await Task.sleep(for: .seconds(1))
        return [
            Article(
                id: "1",
                title: "First sample article",
                summary: "A short summary of the first sample article.",
                contentHTML: "<p>Body of the first article.</p>",
                contentText: "Body of the first article.",
                url: URL(string: "https://example.com/1"),
                imageURL: nil,
                author: "Ada Lovelace",
                date: Date.now.addingTimeInterval(-3600)
            ),
            Article(
                id: "2",
                title: "Second sample article",
                summary: "A short summary of the second sample article.",
                contentHTML: "<p>Body of the second article.</p>",
                contentText: "Body of the second article.",
                url: URL(string: "https://example.com/2"),
                imageURL: nil,
                author: "Alan Turing",
                date: Date.now.addingTimeInterval(-7200)
            )
        ]
    }
}

#Preview {
    RootView(store: FeedStore(
        fetcher: StubFeedFetcher(),
        feedURL: URL(string: "https://example.com/feed.json") ?? URL(fileURLWithPath: "/")
    ))
}
```

```swift
// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    @State private var renderedContent: AttributedString

    init(article: Article) {
        self.article = article
        _renderedContent = State(initialValue: article.renderedBody())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if let imageURL = article.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 16))
                    .accessibilityHidden(true)
                }

                Text(article.title)
                    .font(.title)
                    .fontWeight(.bold)

                HStack(spacing: Spacing.medium) {
                    if let author = article.author {
                        Label(author, systemImage: "person")
                    }
                    Label(article.date.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)

                Divider()

                Text(renderedContent)
                    .font(.body)

                if let url = article.url {
                    Link(destination: url) {
                        Label("Read the original article", systemImage: "safari")
                    }
                    .font(.body)
                }
            }
            .padding(Spacing.large)
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Article {
    static let sample = Article(
        id: "sample",
        title: "A sample article",
        summary: "A short summary used in previews.",
        contentHTML: "<p>This is <b>sample</b> content rendered from HTML.</p>",
        contentText: "This is sample content rendered from HTML.",
        url: URL(string: "https://example.com/article"),
        imageURL: nil,
        author: "Sample Author",
        date: Date.now
    )
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: .sample)
    }
}
```

## Not verified

I did not run this app; it has not been compiled or executed since the fixes. What still needs checking:

- A fresh gate/build with Xcode 26 in Swift 6 mode against the iOS 26 SDK to confirm the two reported errors are gone: the date parsing now uses explicitly typed `Date.ISO8601FormatStyle` statics, and both `replacingOccurrences` calls use the `of:with:options:` order.
- The deprecation bullet in the gate output carried no symbol name, so I could not pinpoint which API it referred to. I reviewed every API used across the twelve files and none is deprecated to my knowledge, but a re-run of the gate is the only way to confirm the deprecation list is now empty.
- A simulator run against the real feed URL to confirm JSON Feed parsing (including `date_published` values with fractional seconds), pull-to-refresh, and the failed-refresh banner path with articles already on screen.
- A VoiceOver pass on the combined row elements, the refresh banner, the empty/failed screens, and the detail screen.
- A Dynamic Type pass at the largest accessibility sizes, and a physical device run to verify `AsyncImage`, `Link` opening Safari, and behavior on a real network.