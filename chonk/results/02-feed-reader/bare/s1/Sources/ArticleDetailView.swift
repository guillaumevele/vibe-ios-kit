// FILE: ArticleDetailView.swift
import SwiftUI

/// Detail screen for a single article: title, date, hero image, and HTML body.
struct ArticleDetailView: View {
    let article: Article

    @State private var renderedBody: AttributedString?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title2.weight(.bold))

                if let date = article.datePublished {
                    Label(date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let imageURL = article.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.gray.opacity(0.15))
                                .frame(height: 200)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let renderedBody {
                    Text(renderedBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else if let summary = article.plainSummary, !summary.isEmpty {
                    Text(summary)
                        .textSelection(.enabled)
                }

                if let url = article.url {
                    Link(destination: url) {
                        Label("Read the original article", systemImage: "safari")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let html = article.contentHTML ?? article.summary ?? ""
            if !html.isEmpty {
                renderedBody = HTMLRenderer.attributedString(from: html)
            }
        }
        .toolbar {
            if let url = article.url {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: url, subject: Text(article.title))
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
            }
        }
    }
}
