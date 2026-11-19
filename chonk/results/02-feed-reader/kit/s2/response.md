Here is the complete app. It reads the Hacker News Algolia JSON API (`search_by_date`, so results are the *latest* stories), shows them in a `NavigationStack` list with pull-to-refresh, and pushes a detail screen per article. All state lives in one `@MainActor @Observable` store with a single four-case `enum`, and the network layer sits behind a `Sendable` protocol so previews use a mock.

```swift
// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    private let store = FeedStore()

    var body: some Scene {
        WindowGroup {
            ArticleListView(store: store)
        }
    }
}
```

```swift
// FILE: Theme.swift
import SwiftUI

enum Theme {
    static let accent = Color.blue
}

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
```

```swift
// FILE: FeedService.swift
import Foundation

protocol FeedService: Sendable {
    func fetchArticles() async throws -> [Article]
}

struct URLSessionFeedService: FeedService {
    private let feedURLString = "https://hn.algolia.com/api/v1/search_by_date?query=swift&tags=story&hitsPerPage=30"

    func fetchArticles() async throws -> [Article] {
        guard let url = URL(string: feedURLString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let feed = try JSONDecoder().decode(FeedResponse.self, from: data)

        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        return feed.hits.compactMap { hit in
            guard let title = hit.title, !title.isEmpty else { return nil }
            let date = withFractionalSeconds.date(from: hit.created_at)
                ?? plain.date(from: hit.created_at)
                ?? Date.now
            return Article(
                id: hit.objectID,
                title: title,
                author: hit.author ?? "unknown",
                points: hit.points ?? 0,
                url: hit.url.flatMap { URL(string: $0) },
                publishedAt: date
            )
        }
    }
}

private struct FeedResponse: Decodable {
    let hits: [Hit]
}

private struct Hit: Decodable {
    let objectID: String
    let title: String?
    let author: String?
    let points: Int?
    let url: String?
    let created_at: String
}
```

```swift
// FILE: FeedStore.swift
import Foundation

@MainActor
@Observable
final class FeedStore {
    enum State: Equatable {
        case loading
        case empty
        case failed(String)
        case content([Article])
    }

    var state: State = .loading
    var refreshError: String?

    private let service: any FeedService

    init(service: any FeedService = URLSessionFeedService()) {
        self.service = service
    }

    func loadIfNeeded() async {
        if case .content = state { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            let articles = try await service.fetchArticles()
            state = articles.isEmpty ? .empty : .content(articles)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    func refresh() async {
        do {
            let articles = try await service.fetchArticles()
            refreshError = nil
            state = articles.isEmpty ? .empty : .content(articles)
        } catch {
            // A failed refresh must never overwrite the articles already on screen.
            if case .content = state {
                refreshError = Self.message(for: error)
            } else {
                state = .failed(Self.message(for: error))
            }
        }
    }

    private static func message(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return "Something went wrong while loading the feed. Please try again."
        }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "You appear to be offline. Check your connection, then retry."
        case .timedOut:
            return "The feed took too long to respond. Please retry."
        case .cannotFindHost, .cannotConnectToHost:
            return "The feed server could not be reached. Please retry."
        default:
            return "The feed could not be loaded. Please retry."
        }
    }
}
```

```swift
// FILE: ArticleListView.swift
import SwiftUI

struct ArticleListView: View {
    @State private var store: FeedStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(store: FeedStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Latest Articles")
                .tint(Theme.accent)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await store.refresh() }
                        }
                        .accessibilityHint("Reloads the latest articles")
                    }
                }
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
                }
                .task {
                    await store.loadIfNeeded()
                }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch store.state {
        case .loading:
            ProgressView("Loading the latest articles")
        case .empty:
            ContentUnavailableView {
                Label("No articles yet", systemImage: "tray")
            } description: {
                Text("Pull down to refresh the feed, or use the button below.")
            } actions: {
                Button("Refresh the feed") {
                    Task { await store.refresh() }
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Could not load articles", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await store.load() }
                }
            }
        case .content(let articles):
            articleList(articles)
        }
    }

    private func articleList(_ articles: [Article]) -> some View {
        List {
            if let refreshError = store.refreshError {
                Section {
                    HStack(spacing: Spacing.small) {
                        Label(refreshError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Retry") {
                            Task { await store.refresh() }
                        }
                    }
                }
            }
            Section("Latest") {
                ForEach(articles) { article in
                    NavigationLink(value: article) {
                        articleRow(article)
                    }
                }
            }
        }
        .refreshable {
            await store.refresh()
        }
    }

    private func articleRow(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small / 2) {
            Text(article.title)
                .font(.headline)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            Text("\(article.author) · \(article.points) points · \(article.publishedAt.formatted(.relative(presentation: .named)))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.small / 2)
        .accessibilityElement(children: .combine)
    }
}

private struct MockFeedService: FeedService {
    let articles: [Article]
    let shouldFail: Bool

    func fetchArticles() async throws -> [Article] {
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        return articles
    }
}

#Preview("Content") {
    ArticleListView(store: FeedStore(service: MockFeedService(articles: [.sample, .sample2], shouldFail: false)))
}

#Preview("Empty") {
    ArticleListView(store: FeedStore(service: MockFeedService(articles: [], shouldFail: false)))
}

#Preview("Failed") {
    ArticleListView(store: FeedStore(service: MockFeedService(articles: [], shouldFail: true)))
}
```

```swift
// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Label("\(article.points) points", systemImage: "arrow.up")
                    Label(article.author, systemImage: "person")
                    Label(article.publishedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let url = article.url {
                    Link(destination: url) {
                        Label("Read the full article", systemImage: "safari")
                    }
                    .font(.headline)
                    .padding(.top, Spacing.small)
                }
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: .sample)
    }
}
```

## Not verified

I did not run this app; nothing below has been compiled or executed. Still needed:

- A build in Xcode against the iOS 26 SDK in Swift 6 language mode to confirm strict-concurrency checking passes (especially `URLSession.shared` usage and the `any FeedService` existential).
- A simulator run to confirm the feed loads from `https://hn.algolia.com/api/v1/search_by_date?...`, that pull-to-refresh and the toolbar Refresh button work, and that the failed-refresh banner appears without wiping the list (test with Network Link Conditioner / offline).
- A VoiceOver pass over the list rows (combined accessibility elements), the four state views, and the detail screen, plus a Dynamic Type check at the largest accessibility sizes (the row `lineLimit` branch).
- A device run to verify behavior on real network conditions, background/foreground transitions, and that the `Link` to the article URL opens correctly.