// FILE: ArticleRowView.swift
import SwiftUI

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        HStack(spacing: 12) {
            RemoteImageView(url: article.image)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(article.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let summary = article.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let date = article.datePublished {
                    Text(date.feedRelative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
