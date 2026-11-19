// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book
    let onToggleFavourite: () async -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(book.title)
                    .font(.headline)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressTrack(progress: book.progress)
                    .frame(height: 8)
                    .accessibilityHidden(true)
                Text("\(book.pagesRead) of \(book.totalPages) pages, \(book.progress.formatted(.percent)) read")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(rowAccessibilityLabel)

            Spacer(minLength: Spacing.small)

            Button {
                Task { await onToggleFavourite() }
            } label: {
                Image(systemName: book.isFavourite ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(book.isFavourite ? Theme.accent : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(
                book.isFavourite
                    ? "Remove \(book.title) from favourites"
                    : "Add \(book.title) to favourites"
            )
            .sensoryFeedback(.selection, trigger: book.isFavourite)
        }
        .padding(.vertical, Spacing.small)
    }

    private var rowAccessibilityLabel: String {
        var label = "\(book.title), by \(book.author), \(book.progress.formatted(.percent)) read"
        if book.isFavourite {
            label += ", favourite"
        }
        return label
    }
}
