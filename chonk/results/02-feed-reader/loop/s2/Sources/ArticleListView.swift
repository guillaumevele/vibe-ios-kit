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
