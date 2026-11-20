// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Label("\(article.points) points", systemImage: "arrow.up")
                    Label(article.author, systemImage: "person")
                    Label(article.publishedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let url = article.url {
                    Link(destination: url) {
                        Label("Read the full article", systemImage: "safari")
                    }
                    .font(.headline)
                    .padding(.top, Spacing.small)
                }
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: .sample)
    }
}
