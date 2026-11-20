Here's a complete SwiftUI app that reads the Hacker News front-page JSON feed (`https://hn.algolia.com/api/v1/search?tags=front_page`), with pull-to-refresh, four-state list UI, and a value-based detail screen.

```swift
// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

```swift
// FILE: Design.swift
import SwiftUI

enum Design {
    /// The one accent color used across the app.
    static let accent: Color = .accentColor

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }
}
```

```swift
// FILE: Article.swift
import Foundation

/// One story from the JSON feed. Sendable so it can cross `await` boundaries.
struct Article: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let author: String
    let url: URL?
    let points: Int
    let commentCount: Int
    let createdAt: Date
}

extension Article: Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "objectID"
        case title
        case author
        case url
        case points
        case commentCount = "num_comments"
        case createdAt = "created_at"
    }
}

/// Top-level shape of the feed response.
struct FeedResponse: Decodable, Sendable {
    let hits: [Article]
}

enum FeedError: Error, Sendable, Equatable {
    case invalidURL
    case invalidResponse
    case invalidData
}

extension Article {
    static let previewArticles: [Article] = [
        Article(
            id: "1",
            title: "Swift 6 concurrency in practice: actors, Sendable and async streams",
            author: "swiftfan",
            url: URL(string: "https://example.com/swift6"),
            points: 342,
            commentCount: 128,
            createdAt: Date().addingTimeInterval(-3600 * 5)
        ),
        Article(
            id: "2",
            title: "Designing pull-to-refresh that feels native",
            author: "uidesign",
            url: nil,
            points: 87,
            commentCount: 41,
            createdAt: Date().addingTimeInterval(-3600 * 26)
        ),
        Article(
            id: "3",
            title: "A field guide to SF Symbols",
            author: "symbols",
            url: URL(string: "https://example.com/symbols"),
            points: 512,
            commentCount: 203,
            createdAt: Date().addingTimeInterval(-3600 * 50)
        )
    ]
}
```

```swift
// FILE: FeedService.swift
import Foundation

/// Anything that can produce the latest articles. Replace with a mock in previews.
protocol FeedService: Sendable {
    func fetchLatestArticles() async throws -> [Article]
}

enum FeedEndpoint {
    /// Hacker News front page, served as JSON. Hardcoded constant, so the force
    /// unwrap can never fail at runtime.
    static let latestArticles: URL = URL(string: "https://hn.algolia.com/api/v1/search?tags=front_page")!
}

struct LiveFeedService: FeedService {
    let endpoint: URL

    init(endpoint: URL = FeedEndpoint.latestArticles) {
        self.endpoint = endpoint
    }

    func fetchLatestArticles() async throws -> [Article] {
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FeedError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(FeedResponse.self, from: data).hits
        } catch {
            throw FeedError.invalidData
        }
    }
}

/// Preview/test double: returns fixed data or a fixed failure after a short delay.
struct MockFeedService: FeedService {
    let articles: [Article]
    let failure: FeedError?
    let delay: Duration

    init(articles: [Article] = [], failure: FeedError? = nil, delay: Duration = .milliseconds(600)) {
        self.articles = articles
        self.failure = failure
        self.delay = delay
    }

    func fetchLatestArticles() async throws -> [Article] {
        try await Task.sleep(for: delay)
        if let failure {
            throw failure
        }
        return articles
    }
}
```

```swift
// FILE: FeedViewModel.swift
import Foundation

@Observable
@MainActor
final class FeedViewModel {
    /// The four states of the screen, as one enum.
    enum State: Equatable {
        case loading
        case loaded([Article])
        case empty
        case failed(String)
    }

    var state: State = .loading
    /// Set when a pull-to-refresh fails while articles are already on screen.
    /// The existing articles are kept; the failure is only surfaced as a banner.
    var refreshError: String?

    private let service: FeedService
    private var hasStarted = false

    init(service: FeedService) {
        self.service = service
    }

    /// Called once from the view's `.task`. Safe to call again; only the first call loads.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await load()
    }

    func load() async {
        state = .loading
        do {
            let articles = try await service.fetchLatestArticles()
            refreshError = nil
            state = articles.isEmpty ? .empty : .loaded(articles)
        } catch {
            state = .failed(userMessage(for: error))
        }
    }

    func refresh() async {
        do {
            let articles = try await service.fetchLatestArticles()
            refreshError = nil
            state = articles.isEmpty ? .empty : .loaded(articles)
        } catch {
            // A failed refresh must never overwrite the articles already on screen.
            refreshError = userMessage(for: error)
        }
    }

    private func userMessage(for error: Error) -> String {
        if let feedError = error as? FeedError {
            switch feedError {
            case .invalidURL, .invalidResponse:
                return "The feed returned an unexpected response. Please try again."
            case .invalidData:
                return "The feed could not be read. Please try again."
            }
        }
        if error is URLError {
            return "Could not reach the feed. Check your internet connection and try again."
        }
        return "Something went wrong while loading. Please try again."
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel: FeedViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    init(viewModel: FeedViewModel = FeedViewModel(service: LiveFeedService())) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView("Loading articles…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ContentUnavailableView {
                        Label("No articles right now", systemImage: "tray")
                    } description: {
                        Text("Pull down to refresh, or try again.")
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.load() }
                        }
                    }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Articles could not be loaded", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                    }
                case .loaded(let articles):
                    articleList(articles)
                }
            }
            .animation(reduceMotion ? nil : .default, value: viewModel.state)
            .sensoryFeedback(.selection, trigger: viewModel.state)
            .navigationTitle("Latest")
            .tint(Design.accent)
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
            .task {
                await viewModel.start()
            }
        }
    }

    private func articleList(_ articles: [Article]) -> some View {
        List {
            if let refreshError = viewModel.refreshError {
                Section {
                    Label(refreshError, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Section {
                ForEach(articles) { article in
                    NavigationLink(value: article) {
                        ArticleRowView(article: article)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

#Preview("Loaded") {
    ContentView(viewModel: FeedViewModel(service: MockFeedService(articles: Article.previewArticles)))
}

#Preview("Empty") {
    ContentView(viewModel: FeedViewModel(service: MockFeedService(articles: [])))
}

#Preview("Failed") {
    ContentView(viewModel: FeedViewModel(service: MockFeedService(failure: .invalidResponse)))
}
```

```swift
// FILE: ArticleRowView.swift
import SwiftUI

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xs) {
            Text(article.title)
                .font(.headline)
                .lineLimit(2)
            HStack(spacing: Design.Spacing.sm) {
                Label(article.author, systemImage: "person")
                    .lineLimit(1)
                Label("\(article.points.formatted()) points", systemImage: "arrow.up")
                Label("\(article.commentCount.formatted())", systemImage: "bubble.left")
                Spacer(minLength: 0)
                Text(article.createdAt.formatted(.relative(presentation: .named)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Design.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        ArticleRowView(article: Article.previewArticles[0])
        ArticleRowView(article: Article.previewArticles[1])
    }
}
```

```swift
// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    Label("by \(article.author)", systemImage: "person")
                    Label("\(article.points.formatted()) points", systemImage: "arrow.up")
                    Label("\(article.commentCount.formatted()) comments", systemImage: "bubble.left")
                    Label(article.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)

                if let url = article.url {
                    Button {
                        Task { _ = await openURL(url) }
                    } label: {
                        Label("Read the full article", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Label("Text post — no external link", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Design.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Article")
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

#Preview {
    NavigationStack {
        ArticleDetailView(article: Article.previewArticles[0])
    }
}
```

Not verified

I did not build or run this app. Still needed:

- A build in Xcode with the iOS 26 SDK in Swift 6 language mode to confirm strict-concurrency checking passes (especially the `@MainActor` view-model init pattern and the `Sendable` service protocol).
- A simulator run against the live Hacker News Algolia endpoint to confirm the JSON shape still matches the `CodingKeys` (`objectID`, `num_comments`, ISO-8601 `created_at`), and that `JSONDecoder.DateDecodingStrategy.iso8601` parses it.
- A simulator pass with Wi-Fi/cellular off to exercise the failed state and the refresh-failure banner (content must survive a failed pull-to-refresh).
- A VoiceOver pass on the list rows (combined accessibility elements), the empty/failed `ContentUnavailableView` actions, and the detail screen header trait.
- A device test for pull-to-refresh, the share sheet, `openURL`, haptics, and Dynamic Type at the largest sizes.