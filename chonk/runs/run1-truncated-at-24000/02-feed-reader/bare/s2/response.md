Here's the complete app — a SwiftUI feed reader (MVVM) that loads the latest articles from a JSON feed, supports pull-to-refresh via `.refreshable`, and pushes to a detail screen through `NavigationStack`. The feed URL lives in `FeedConfiguration` (currently the keyless Spaceflight News API, which provides titles, images, summaries and links) and can be swapped for any compatible JSON feed.

```swift
// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @StateObject private var feedViewModel = FeedViewModel()

    var body: some Scene {
        WindowGroup {
            ArticleListView(viewModel: feedViewModel)
        }
    }
}
```

```swift
// FILE: Article.swift
import Foundation

/// Top-level structure of the JSON feed.
struct FeedResponse: Decodable {
    let results: [ArticleDTO]
}

/// One raw entry from the feed, as decoded from JSON.
struct ArticleDTO: Decodable {
    let id: Int
    let title: String
    let url: String?
    let imageURL: String?
    let newsSite: String?
    let summary: String?
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case imageURL = "image_url"
        case newsSite = "news_site"
        case summary
        case publishedAt = "published_at"
    }
}

/// An article ready for display in the UI.
struct Article: Identifiable, Hashable {
    let id: Int
    let title: String
    let url: URL?
    let imageURL: URL?
    let newsSite: String
    let summary: String
    let publishedAt: Date

    init(dto: ArticleDTO) {
        self.id = dto.id
        self.title = dto.title
        self.url = dto.url.flatMap(URL.init(string:))
        self.imageURL = dto.imageURL.flatMap(URL.init(string:))
        self.newsSite = dto.newsSite ?? "Unknown source"
        self.summary = dto.summary ?? ""
        self.publishedAt = FeedDateParser.parse(dto.publishedAt ?? "") ?? Date()
    }

    var hasSummary: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// e.g. "2 hours ago"
    var relativePublished: String {
        publishedAt.formatted(.relative(presentation: .named))
    }

    /// e.g. "Jun 1, 2025 at 10:00 AM"
    var formattedPublished: String {
        publishedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Parses the ISO-8601 timestamps used by the feed.
enum FeedDateParser {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        fractional.date(from: string) ?? standard.date(from: string)
    }
}
```

```swift
// FILE: FeedService.swift
import Foundation

/// Configuration for the remote JSON feed.
enum FeedConfiguration {
    /// Latest-articles endpoint (Spaceflight News API v4 — no API key required).
    /// Swap this URL for any other JSON feed with a compatible shape.
    static let articlesURL = URL(
        string: "https://api.spaceflightnewsapi.com/v4/articles/?limit=20&ordering=-published_at"
    )!
}

enum FeedError: LocalizedError {
    case badStatusCode(Int)
    case decodingFailed(DecodingError)

    var errorDescription: String? {
        switch self {
        case .badStatusCode(let code):
            return "The feed server responded with status code \(code)."
        case .decodingFailed(let error):
            return "The feed could not be decoded (\(error.localizedDescription))."
        }
    }
}

/// Fetches and decodes the article feed using only URLSession.
final class FeedService {
    static let shared = FeedService()

    private let feedURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(feedURL: URL = FeedConfiguration.articlesURL, session: URLSession = .shared) {
        self.feedURL = feedURL
        self.session = session
    }

    func fetchLatestArticles() async throws -> [Article] {
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData // pull-to-refresh always gets fresh data
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.badStatusCode(-1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.badStatusCode(httpResponse.statusCode)
        }

        do {
            let feed = try decoder.decode(FeedResponse.self, from: data)
            return feed.results.map(Article.init(dto:))
        } catch let decodingError as DecodingError {
            throw FeedError.decodingFailed(decodingError)
        }
    }
}
```

```swift
// FILE: FeedViewModel.swift
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let service: FeedService
    private var hasLoadedOnce = false

    init(service: FeedService = .shared) {
        self.service = service
    }

    /// Loads the feed the first time the list appears.
    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await refresh()
    }

    /// Fetches the latest articles. Called on first load and by pull-to-refresh.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            articles = try await service.fetchLatestArticles()
            lastUpdated = Date()
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

```swift
// FILE: ArticleListView.swift
import SwiftUI

struct ArticleListView: View {
    @ObservedObject var viewModel: FeedViewModel

    var body: some View {
        NavigationStack {
            List {
                // Inline banner when a refresh fails but we still have content.
                if let errorMessage = viewModel.errorMessage, !viewModel.articles.isEmpty {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorMessage)
                                .lineLimit(2)
                            Spacer()
                            Button("Retry") {
                                Task { await viewModel.refresh() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    }
                }

                Section {
                    ForEach(viewModel.articles) { article in
                        NavigationLink(value: article) {
                            ArticleRowView(article: article)
                        }
                    }
                } footer: {
                    if let lastUpdated = viewModel.lastUpdated {
                        Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Latest News")
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
                        ProgressView("Loading articles…")
                    } else {
                        ContentUnavailableView {
                            Label("No articles", systemImage: "tray")
                        } description: {
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                            } else {
                                Text("Pull down to refresh the feed.")
                            }
                        } actions: {
                            Button("Try Again") {
                                Task { await viewModel.refresh() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
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
        VStack(alignment: .leading, spacing: 10) {
            ArticleImageView(url: article.imageURL, height: 170)

            Text(article.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(article.newsSite)
                Spacer()
                Image(systemName: "clock")
                Text(article.relativePublished)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
```

```swift
// FILE: ArticleImageView.swift
import SwiftUI

/// Loads a remote image with AsyncImage, with loading and failure placeholders.
struct ArticleImageView: View {
    let url: URL?
    var height: CGFloat = 170
    var cornerRadius: CGFloat = 12

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholder {
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder {
                    Image(systemName: "photo")
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
    }

    @ViewBuilder
    private func placeholder<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            content()
                .foregroundStyle(.secondary)
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
                ArticleImageView(url: article.imageURL, height: 240, cornerRadius: 16)

                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Label(article.newsSite, systemImage: "globe")
                    Spacer()
                    Text(article.formattedPublished)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                if article.hasSummary {
                    Text(article.summary)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }

                if let url = article.url {
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                            Text("Read the full article")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle(article.newsSite)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = article.url {
                    ShareLink(item: url, subject: Text(article.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
```

To use a different feed, just change `FeedConfiguration.articlesURL` and adjust `ArticleDTO`'s `CodingKeys` to match that feed's JSON field names — everything else (list, refresh, detail) works unchanged.