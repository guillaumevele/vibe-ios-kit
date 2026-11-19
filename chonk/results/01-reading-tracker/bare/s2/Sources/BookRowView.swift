// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            CoverView(book: book, width: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(book.status.rawValue, systemImage: book.status.systemImage)
                        .font(.caption2)
                        .foregroundStyle(book.status.tint)
                    if book.isFavourite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 8) {
                    BookProgressBar(progress: book.progress, color: book.coverColor)
                    Text(Formatters.percentString(book.progress))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}
