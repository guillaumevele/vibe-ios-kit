// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book
    let onSelect: () -> Void
    let onToggleFavourite: () -> Void

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text(book.title)
                        .font(.headline)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                        .tint(Theme.accent)
                        .accessibilityLabel("Progress")
                        .accessibilityValue(Text("\(book.percentRead) percent read"))
                    HStack {
                        Text("\(book.pagesRead) of \(book.totalPages) pages")
                        Spacer()
                        Text(book.lastUpdated.formatted(.relative(presentation: .named)))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)

            Button(action: onToggleFavourite) {
                Image(systemName: book.isFavourite ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(book.isFavourite ? Theme.accent : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(book.isFavourite ? "Remove from favourites" : "Add to favourites")
        }
        .padding(.vertical, Spacing.small)
    }
}
