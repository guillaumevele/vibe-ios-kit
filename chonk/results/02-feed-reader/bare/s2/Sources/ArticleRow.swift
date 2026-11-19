// FILE: ArticleRow.swift
import SwiftUI

struct ArticleRow: View {
    let article: Article

    private var meta: String {
        var parts: [String] = []
        if let author = article.author, !author.isEmpty {
            parts.append(author)
        }
        if !article.publishedText.isEmpty {
            parts.append(article.publishedText)
        }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(article.title)
                .font(.headline)
                .lineLimit(2)

            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !meta.isEmpty {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
