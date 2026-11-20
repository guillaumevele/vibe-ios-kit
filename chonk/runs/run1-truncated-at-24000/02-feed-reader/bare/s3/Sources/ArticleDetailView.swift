// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteImageView(url: article.image)
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text(article.displayTitle)
                        .font(.title2.bold())

                    HStack(spacing: 12) {
                        if let author = article.author {
                            Label(author, systemImage: "person.fill")
                        }
                        if let date = article.datePublished {
                            Label(date.feedMedium, systemImage: "calendar")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Divider()

                    Text(article.bodyAttributed)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(article.displayTitle)
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
