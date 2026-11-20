// FILE: ArticleDetailView.swift
import SwiftUI

/// Full article screen: hero image, title, metadata, and the body rendered
/// as Markdown (falling back to plain text).
struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                heroImage

                Text(article.title)
                    .font(.title2.bold())

                metaRow

                Divider()

                Text(bodyText)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    // MARK: - Subviews

    private var heroImage: some View {
        AsyncImage(url: article.imageURL) { phase in
            switch phase {
            case .empty:
                placeholder
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            @unknown default:
                EmptyView()
            }
        }
        .frame(height: 220)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            ProgressView()
        }
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 18) {
            if let date = article.publishedAt {
                Label(Formatting.relativeDate(date), systemImage: "clock")
            }
            if let userId = article.userId {
                Label("User #\(userId)", systemImage: "person")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let url = article.url.flatMap({ URL(string: $0) }) {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: url, subject: Text(article.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Link(destination: url) {
                    Image(systemName: "safari")
                }
                .accessibilityLabel("Open in Safari")
            }
        }
    }

    // MARK: - Helpers

    private var bodyText: AttributedString {
        (try? AttributedString(markdown: article.body)) ?? AttributedString(article.body)
    }
}
