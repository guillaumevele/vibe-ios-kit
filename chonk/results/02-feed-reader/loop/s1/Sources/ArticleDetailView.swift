// FILE: ArticleDetailView.swift
import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    @State private var renderedContent: AttributedString

    init(article: Article) {
        self.article = article
        _renderedContent = State(initialValue: article.renderedBody())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
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
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 16))
                    .accessibilityHidden(true)
                }

                Text(article.title)
                    .font(.title)
                    .fontWeight(.bold)

                HStack(spacing: Spacing.medium) {
                    if let author = article.author {
                        Label(author, systemImage: "person")
                    }
                    Label(article.date.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)

                Divider()

                Text(renderedContent)
                    .font(.body)

                if let url = article.url {
                    Link(destination: url) {
                        Label("Read the original article", systemImage: "safari")
                    }
                    .font(.body)
                }
            }
            .padding(Spacing.large)
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Article {
    static let sample = Article(
        id: "sample",
        title: "A sample article",
        summary: "A short summary used in previews.",
        contentHTML: "<p>This is <b>sample</b> content rendered from HTML.</p>",
        contentText: "This is sample content rendered from HTML.",
        url: URL(string: "https://example.com/article"),
        imageURL: nil,
        author: "Sample Author",
        date: Date.now
    )
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: .sample)
    }
}
