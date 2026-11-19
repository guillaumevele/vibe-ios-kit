// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    Label("by \(article.author)", systemImage: "person")
                    Label("\(article.points.formatted()) points", systemImage: "arrow.up")
                    Label("\(article.commentCount.formatted()) comments", systemImage: "bubble.left")
                    Label(article.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)

                if let url = article.url {
                    Button {
                        Task { _ = await openURL(url) }
                    } label: {
                        Label("Read the full article", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Label("Text post — no external link", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Design.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = article.url {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: Article.previewArticles[0])
    }
}
