// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ArticleImageView(url: article.imageURL, height: 240, cornerRadius: 16)

                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Label(article.newsSite, systemImage: "globe")
                    Spacer()
                    Text(article.formattedPublished)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                if article.hasSummary {
                    Text(article.summary)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }

                if let url = article.url {
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                            Text("Read the full article")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle(article.newsSite)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = article.url {
                    ShareLink(item: url, subject: Text(article.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
