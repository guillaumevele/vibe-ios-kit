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
