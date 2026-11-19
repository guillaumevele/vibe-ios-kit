// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            BookCoverView(book: book)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    if book.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: book.progress)
                    .tint(book.isFinished ? .green : .blue)

                HStack {
                    Text(book.isFinished ? "Finished" : "\(book.pagesRead) of \(book.totalPages) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(book.progress, format: .percent)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
