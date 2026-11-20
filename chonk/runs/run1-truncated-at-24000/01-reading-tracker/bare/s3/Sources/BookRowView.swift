// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if book.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Text(book.percentText)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
            }

            ProgressView(value: book.progress)
                .tint(book.isFinished ? .green : .accentColor)

            HStack {
                Text("\(book.pagesRead) / \(book.totalPages) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if book.isFinished {
                    Label("Finished", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
