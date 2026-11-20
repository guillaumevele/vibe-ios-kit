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
