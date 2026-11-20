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
