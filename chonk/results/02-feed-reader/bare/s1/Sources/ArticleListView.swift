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
