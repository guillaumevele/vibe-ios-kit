// FILE: ArticleRowView.swift
import SwiftUI

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArticleImageView(url: article.imageURL, height: 170)

            Text(article.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(article.newsSite)
                Spacer()
                Image(systemName: "clock")
                Text(article.relativePublished)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
