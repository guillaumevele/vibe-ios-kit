// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    @Bindable var book: Book

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(title: book.title, author: book.author)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(book.title.isEmpty ? "Untitled" : book.title)
                        .font(.headline)
                        .lineLimit(1)
                    if book.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressBarView(progress: book.progress, color: book.status.color)

                HStack {
                    Label(book.status.rawValue, systemImage: book.status.icon)
                        .font(.caption2)
                        .foregroundStyle(book.status.color)
                    Spacer()
                    Text("\(book.pagesRead) / \(book.totalPages) · \(book.progressPercent)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}
