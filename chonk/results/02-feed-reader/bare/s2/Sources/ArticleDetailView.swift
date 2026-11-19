// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageURL = article.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(article.title)
                    .font(.title2.weight(.bold))

                if !meta.isEmpty {
                    Text(meta)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.body)
                        .textSelection(.enabled)
                }

                if let url = article.url {
                    Link(destination: url) {
                        Label("Read the full article", systemImage: "safari")
                    }
                    .font(.headline)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}
