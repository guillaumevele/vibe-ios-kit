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
