```swift
// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @State private var viewModel = FeedViewModel()

    var body: some Scene {
        WindowGroup {
            ArticleListView(viewModel: viewModel)
        }
    }
}
```

```swift
// FILE: Article.swift
import Foundation

struct Article: Identifiable, Hashable, Decodable {
    let id: String
    let title: String
    let summary: String
    let url: URL?
    let author: String?
    let published: Date?
    let imageURL: URL?

    // MARK: - Flexible decoding (accepts common feed key names and scalar types)

    private struct AnyKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)

        func string(_ keys: [String]) -> String? {
            for key in keys {
                guard let k = AnyKey(stringValue: key), c.contains(k) else { continue }
                if let value = try? c.decode(String.self, forKey: k) { return value }
                if let value = try? c.decode(Int.self, forKey: k) { return String(value) }
                if let value = try? c.decode(Double.self, forKey: k) { return String(value) }
                if let value = try? c.decode(Bool.self, forKey: k) { return value ? "true" : "false" }
            }
            return nil
        }

        func url(_ keys: [String]) -> URL? {
            guard let raw = string(keys), !raw.isEmpty else { return nil }
            return URL(string: raw)
        }

        func date(_ keys: [String]) -> Date? {
            guard let raw = string(keys), !raw.isEmpty else { return nil }
            return Article.parseDate(raw)
        }

        id = string(["id", "guid", "uid", "link", "url"]) ?? UUID().uuidString
        title = string(["title", "name", "headline"]) ?? "(Untitled)"
        summary = string(["summary", "description", "excerpt", "body", "content", "content_text", "text"]) ?? ""
        url = url(["url", "link", "href", "web_url"])
        author = string(["author", "author_name", "creator", "byline"])
        published = date(["published", "published_at", "pubDate", "pub_date", "date", "date_published", "created_at", "updated_at"])
        imageURL = url(["image", "image_url", "imageURL", "thumbnail", "media", "enclosure"])
    }

    private static func parseDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "EEE, dd MMM yyyy HH:mm:ss Z"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    var publishedText: String {
        guard let published else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: published, relativeTo: Date())
    }
}
```

```swift
// FILE: FeedService.swift
import Foundation

enum FeedError: LocalizedError {
    case invalidURL
    case badResponse(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The feed URL is invalid."
        case .badResponse(let code):
            return "The server returned status \(code)."
        case .decoding(let error):
            return "Could not parse the feed: \(error.localizedDescription)"
        }
    }
}

struct FeedService {
    /// Replace this with your own JSON feed endpoint.
    static let defaultFeedURL = URL(string: "https://jsonplaceholder.typicode.com/posts")!

    let feedURL: URL
    private let session: URLSession

    init(feedURL: URL = FeedService.defaultFeedURL, session: URLSession = .shared) {
        self.feedURL = feedURL
        self.session = session
    }

    func fetchArticles() async throws -> [Article] {
        guard feedURL.scheme != nil else { throw FeedError.invalidURL }

        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("FeedReader/1.0 (iOS 26)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FeedError.badResponse(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.badResponse(http.statusCode)
        }

        return try Self.decode(data)
    }

    private static func decode(_ data: Data) throws -> [Article] {
        let decoder = JSONDecoder()

        var arrayError: Error?
        do {
            return try decoder.decode([Article].self, from: data)
        } catch {
            arrayError = error
        }

        do {
            let envelope = try decoder.decode(Envelope.self, from: data)
            if !envelope.all.isEmpty {
                return envelope.all
            }
        } catch {
            // Fall through to the error below.
        }

        throw FeedError.decoding(
            arrayError ?? NSError(
                domain: "FeedService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognized feed format"]
            )
        )
    }

    private struct Envelope: Decodable {
        let items: [Article]?
        let articles: [Article]?
        let results: [Article]?
        let entries: [Article]?
        let data: [Article]?

        var all: [Article] {
            items ?? articles ?? results ?? entries ?? data ?? []
        }
    }
}
```

```swift
// FILE: FeedViewModel.swift
import Foundation

@MainActor
@Observable
final class FeedViewModel {
    var articles: [Article] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    private let service: FeedService

    init(service: FeedService = FeedService()) {
        self.service = service
    }

    func load(force: Bool = false) async {
        guard !isLoading else { return }
        if !force && !articles.isEmpty { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchArticles()
            articles = fetched
            lastUpdated = Date()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refresh() async {
        await load(force: true)
    }
}
```

```swift
// FILE: ArticleListView.swift
import SwiftUI

struct ArticleListView: View {
    var viewModel: FeedViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.articles) { article in
                NavigationLink(value: article) {
                    ArticleRow(article: article)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle("Latest")
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
            .task {
                await viewModel.load()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .overlay {
                if viewModel.articles.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if let errorMessage = viewModel.errorMessage {
                        ContentUnavailableView {
                            Label("Couldn't load articles", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("Try Again") {
                                Task { await viewModel.refresh() }
                            }
                        }
                    } else {
                        ContentUnavailableView("No articles", systemImage: "tray")
                    }
                }
            }
        }
    }
}
```

```swift
// FILE: ArticleRow.swift
import SwiftUI

struct ArticleRow: View {
    let article: Article

    private var meta: String {
        var parts: [String] = []
        if let author = article.author, !author.isEmpty {
            parts.append(author)
        }
        if !article.publishedText.isEmpty {
            parts.append(article.publishedText)
        }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(article.title)
                .font(.headline)
                .lineLimit(2)

            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !meta.isEmpty {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

```swift
// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    private var meta: String {
        var parts: [String] = []
        if let author = article.author, !author.isEmpty {
            parts.append(author)
        }
        if !article.publishedText.isEmpty {
            parts.append(article.publishedText)
        }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(article.title)
                    .font(.title2.weight(.bold))

                if !meta.isEmpty {
                    Text(meta)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.body)
                        .textSelection(.enabled)
                }

                if let url = article.url {
                    Link(destination: url) {
                        Label("Read the full article", systemImage: "safari")
                    }
                    .font(.headline)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```