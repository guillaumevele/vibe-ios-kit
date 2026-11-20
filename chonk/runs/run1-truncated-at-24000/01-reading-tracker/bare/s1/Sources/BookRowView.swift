// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            ProgressRingView(progress: book.progress, isFinished: book.isFinished)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if book.totalPages > 0 {
                    ProgressView(value: book.progress)
                        .tint(book.isFinished ? .green : .accentColor)
                } else {
                    Text("No page count set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if book.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                Text("\(Int(book.progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if book.isFinished {
                    Text("Done")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
