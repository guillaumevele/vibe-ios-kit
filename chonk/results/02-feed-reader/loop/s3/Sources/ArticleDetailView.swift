// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article

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
                    Link(destination: url) {
                        Label("Read the full article", systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
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
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: Article.previewArticles[0])
    }
}
