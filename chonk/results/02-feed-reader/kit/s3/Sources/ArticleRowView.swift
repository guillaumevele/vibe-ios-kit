// FILE: ArticleRowView.swift
import SwiftUI

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.xs) {
            Text(article.title)
                .font(.headline)
                .lineLimit(2)
            HStack(spacing: Design.Spacing.sm) {
                Label(article.author, systemImage: "person")
                    .lineLimit(1)
                Label("\(article.points.formatted()) points", systemImage: "arrow.up")
                Label("\(article.commentCount.formatted())", systemImage: "bubble.left")
                Spacer(minLength: 0)
                Text(article.createdAt.formatted(.relative(presentation: .named)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Design.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        ArticleRowView(article: Article.previewArticles[0])
        ArticleRowView(article: Article.previewArticles[1])
    }
}
