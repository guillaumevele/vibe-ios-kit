// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            CoverView(title: book.title, author: book.author, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    if book.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: book.progress)
                    .tint(book.isFinished ? .green : .accentColor)

                HStack {
                    Text(book.isFinished
                         ? "Finished"
                         : "\(book.currentPage) / \(book.totalPages) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(book.percentText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}
