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
