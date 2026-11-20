// FILE: ArticleListView.swift
import SwiftUI

struct ArticleListView: View {
    @Environment(ArticlesViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            List(viewModel.articles) { article in
                NavigationLink(value: article) {
                    ArticleRowView(article: article)
                }
            }
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
            .overlay {
                if viewModel.articles.isEmpty {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.large)
                    } else if let error = viewModel.error {
                        ContentUnavailableView {
                            Label("Couldn't Load Articles", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(error.localizedDescription)
                        } actions: {
                            Button("Try Again") {
                                Task { await viewModel.refresh() }
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "No Articles",
                            systemImage: "doc.text",
                            description: Text("Pull down to refresh.")
                        )
                    }
                }
            }
        }
    }
}
