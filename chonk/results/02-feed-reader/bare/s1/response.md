Here's a complete SwiftUI feed-reader app (Apple frameworks only) targeting iOS 26. It loads a JSON Feed (default: Daring Fireball's JSON feed — change `FeedService.defaultFeedURL` to any JSON Feed URL), supports pull-to-refresh via `.refreshable`, and pushes a detail screen with the rendered HTML article body.

```swift
// FILE: FeedApp.swift
import SwiftUI

@main
struct FeedApp: App {
    @State private var viewModel = FeedViewModel()

    var body: some Scene {
        WindowGroup {
            ArticleListView()
                .environment(viewModel)
        }
    }
}
```

```swift
// FILE: FeedViewModel.swift
import Foundation
import Observation

/// Observable state for the article list: articles, loading flags, and errors.
@Observable
@MainActor
final class FeedViewModel {
    var articles: [Article] = []
    var isLoading = false
    var isRefreshing = false
    var lastUpdated: Date?
    var errorMessage: String?
    var feedTitle = "Latest Articles"

    private let service: FeedService
    private let feedURL: URL

    init(service: FeedService = FeedService(), feedURL: URL? = nil) {
        self.service = service
        self.feedURL = feedURL ?? FeedService.defaultFeedURL
    }

    /// Loads the feed on first appearance. Pull-to-refresh calls `refresh()` directly.
    func loadIfNeeded() async {
        guard articles.isEmpty, !isLoading, !isRefreshing else { return }
        await refresh()
    }

    /// Fetches the latest articles. Safe to call from pull-to-refresh or a button.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = articles.isEmpty
        errorMessage = nil
        defer {
            isRefreshing = false
            isLoading = false
        }

        do {
            let feed = try await service.fetchFeed(from: feedURL)
            articles = feed.items
            lastUpdated = Date()
            if let title = feed.title, !title.isEmpty {
                feedTitle = title
            }
        } catch {
            // Keep showing previously loaded articles; surface the error so the UI can offer a retry.
            if let localizedError = error as? LocalizedError,
               let description = localizedError.errorDescription {
                errorMessage = description
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

```swift
// FILE: FeedService.swift
import Foundation

/// A decoded feed document: an optional title plus its articles.
struct Feed: Decodable {
    let title: String?
    let items: [Article]

    enum CodingKeys: String, CodingKey {
        case title, items, articles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try? container.decode(String.self, forKey: .title)
        items =
            (try? container.decode([Article].self, forKey: .items))
            ?? (try? container.decode([Article].self, forKey: .articles))
            ?? []
    }
}

/// Errors thrown while loading a feed.
enum FeedError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpStatus(let code):
            return "The server returned an error (HTTP \(code))."
        case .decoding(let error):
            return "Could not parse the feed (\(error.localizedDescription))."
        }
    }
}

/// Downloads and decodes a JSON feed using only Foundation.
struct FeedService {
    /// The JSON feed shown by default. Swap this for any JSON Feed URL.
    static let defaultFeedURL = URL(string: "https://daringfireball.net/feeds/json")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the feed at `url` and returns its title and articles.
    func fetchFeed(from url: URL) async throws -> Feed {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json, text/plain;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("FeedReader/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.httpStatus(http.statusCode)
        }
        return try decode(data)
    }

    /// Decodes either a JSON Feed object (`{"items": [...]}`) or a bare array of articles.
    private func decode(_ data: Data) throws -> Feed {
        let decoder = JSONDecoder()
        if let feed = try? decoder.decode(Feed.self, from: data) {
            return feed
        }
        if let items = try? decoder.decode([Article].self, from: data) {
            return Feed(title: nil, items: items)
        }
        throw FeedError.decoding(URLError(.cannotDecodeContentData))
    }
}
```

```swift
// FILE: Article.swift
import Foundation

/// A single article decoded from a JSON Feed (https://jsonfeed.org) document.
/// The decoder tolerates a few alternative key names so the app also works with
/// feeds that are not strictly JSON-Feed compliant.
struct Article: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    var summary: String?
    var contentHTML: String?
    var url: URL?
    var imageURL: URL?
    var datePublished: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case objectID
        case title
        case summary
        case contentHTML = "content_html"
        case contentText = "content_text"
        case url
        case image
        case bannerImage = "banner_image"
        case datePublished = "date_published"
        case dateModified = "date_modified"
        case createdAt = "created_at"
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        summary: String? = nil,
        contentHTML: String? = nil,
        url: URL? = nil,
        imageURL: URL? = nil,
        datePublished: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.contentHTML = contentHTML
        self.url = url
        self.imageURL = imageURL
        self.datePublished = datePublished
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else if let intID = try? container.decode(Int.self, forKey: .objectID) {
            id = String(intID)
        } else if let stringObjectID = try? container.decode(String.self, forKey: .objectID) {
            id = stringObjectID
        } else {
            id = UUID().uuidString
        }

        title = (try? container.decode(String.self, forKey: .title)) ?? "(Untitled)"
        summary = try? container.decode(String.self, forKey: .summary)
        contentHTML =
            (try? container.decode(String.self, forKey: .contentHTML))
            ?? (try? container.decode(String.self, forKey: .contentText))
        url = try? container.decode(URL.self, forKey: .url)
        imageURL =
            (try? container.decode(URL.self, forKey: .image))
            ?? (try? container.decode(URL.self, forKey: .bannerImage))

        let dateString =
            (try? container.decode(String.self, forKey: .datePublished))
            ?? (try? container.decode(String.self, forKey: .dateModified))
            ?? (try? container.decode(String.self, forKey: .createdAt))
        datePublished = dateString.flatMap(Self.parseDate)
    }

    /// Human-readable publication date, e.g. "Mar 4, 2026".
    var displayDate: String? {
        datePublished?.formatted(date: .abbreviated, time: .omitted)
    }

    /// Summary with any HTML tags removed, suitable for plain-text display.
    var plainSummary: String? {
        summary?.strippedOfHTML
    }

    // MARK: - Date parsing

    private static func parseDate(_ string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) { return date }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: string) { return date }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = fallback.date(from: string) { return date }
        fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fallback.date(from: string)
    }
}
```

```swift
// FILE: ArticleListView.swift
import SwiftUI

/// Root screen: a pull-to-refresh list of the latest articles.
struct ArticleListView: View {
    @Environment(FeedViewModel.self) private var viewModel: FeedViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.articles) { article in
                        NavigationLink(value: article) {
                            ArticleRow(article: article)
                        }
                        .contextMenu {
                            if let url = article.url {
                                Link("Open in Safari", destination: url)
                                ShareLink(item: url, subject: Text(article.title)) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                } footer: {
                    if let lastUpdated = viewModel.lastUpdated {
                        Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: viewModel.articles)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshing)
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.articles.isEmpty {
                    ProgressView()
                        .controlSize(.large)
                } else if viewModel.articles.isEmpty {
                    ContentUnavailableView {
                        if viewModel.errorMessage != nil {
                            Label("Couldn't Load Articles", systemImage: "wifi.slash")
                        } else {
                            Label("No Articles", systemImage: "tray")
                        }
                    } description: {
                        Text(viewModel.errorMessage ?? "Pull down to refresh the feed.")
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.refresh() }
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let errorMessage = viewModel.errorMessage, !viewModel.articles.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.9), in: Capsule())
                        .padding(.top, 8)
                }
            }
        }
    }
}
```

```swift
// FILE: ArticleRow.swift
import SwiftUI

/// A single row in the article list: title, summary, date, and thumbnail.
struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)

                if let summary = article.plainSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let date = article.displayDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray.opacity(0.15))
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
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
```

```swift
// FILE: ArticleDetailView.swift
import SwiftUI

/// Detail screen for a single article: title, date, hero image, and HTML body.
struct ArticleDetailView: View {
    let article: Article

    @State private var renderedBody: AttributedString?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title2.weight(.bold))

                if let date = article.datePublished {
                    Label(date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let imageURL = article.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.gray.opacity(0.15))
                                .frame(height: 200)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let renderedBody {
                    Text(renderedBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else if let summary = article.plainSummary, !summary.isEmpty {
                    Text(summary)
                        .textSelection(.enabled)
                }

                if let url = article.url {
                    Link(destination: url) {
                        Label("Read the original article", systemImage: "safari")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let html = article.contentHTML ?? article.summary ?? ""
            if !html.isEmpty {
                renderedBody = HTMLRenderer.attributedString(from: html)
            }
        }
        .toolbar {
            if let url = article.url {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: url, subject: Text(article.title))
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
            }
        }
    }
}
```

```swift
// FILE: HTMLRenderer.swift
import Foundation
import UIKit

/// Converts article HTML into an `AttributedString` that SwiftUI can display,
/// using only Foundation/UIKit. Fonts are rescaled relative to the body text,
/// and hard-coded foreground colors are removed so text adapts to dark mode.
enum HTMLRenderer {
    static func attributedString(from html: String) -> AttributedString {
        let wrapped = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            body { font-family: -apple-system, Helvetica, sans-serif; font-size: 17px; line-height: 1.55; }
            img { max-width: 100%; height: auto; }
            blockquote { margin: 8px 0 8px 16px; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """

        guard let data = wrapped.data(using: .utf8) else {
            return AttributedString(html)
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let nsAttributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            // Fall back to showing the raw markup as plain text.
            return AttributedString(html)
        }

        let mutable = NSMutableAttributedString(attributedString: nsAttributed)
        let bodyPointSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        let fullRange = NSRange(location: 0, length: mutable.length)

        // The HTML importer defaults to a 12pt font; scale every run so the default
        // becomes the user's preferred body size while keeping relative sizes
        // (headings, captions) intact.
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let base = value as? UIFont
            let pointSize = base?.pointSize ?? 12
            let scaledSize = max(10, pointSize * bodyPointSize / 12)
            let font = base?.withSize(scaledSize)
                ?? UIFont.preferredFont(forTextStyle: .body)
            mutable.addAttribute(.font, value: font, range: range)
        }

        // Remove hard-coded colors so text follows the system label color (dark-mode safe).
        // Links keep their `.link` attribute and remain tappable in SwiftUI Text.
        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { _, range, _ in
            mutable.removeAttribute(.foregroundColor, range: range)
        }

        return AttributedString(mutable)
    }
}
```

```swift
// FILE: String+HTML.swift
import Foundation

extension String {
    /// The receiver with HTML markup removed, e.g. for displaying a summary as plain text.
    var strippedOfHTML: String {
        guard let data = data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard
            let attributed = try? NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )
        else {
            return self
        }
        return attributed.string
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

To point the app at a different feed, just change `FeedService.defaultFeedURL` — any JSON Feed v1 URL (or a bare JSON array of articles) works.