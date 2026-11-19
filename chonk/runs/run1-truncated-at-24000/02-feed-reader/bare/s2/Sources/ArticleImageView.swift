// FILE: ArticleImageView.swift
import SwiftUI

/// Loads a remote image with AsyncImage, with loading and failure placeholders.
struct ArticleImageView: View {
    let url: URL?
    var height: CGFloat = 170
    var cornerRadius: CGFloat = 12

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholder {
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder {
                    Image(systemName: "photo")
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
    }

    @ViewBuilder
    private func placeholder<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            content()
                .foregroundStyle(.secondary)
        }
    }
}
