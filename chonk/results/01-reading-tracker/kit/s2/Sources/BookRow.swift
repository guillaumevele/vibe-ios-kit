// FILE: BookRow.swift
import SwiftUI

struct BookRow: View {
    let book: Book
    let onToggleFavorite: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppDesign.Space.medium) {
            VStack(alignment: .leading, spacing: AppDesign.Space.xSmall) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: AppDesign.Space.small) {
                    ProgressView(value: book.fraction)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 120)
                        .accessibilityHidden(true)
                        .animation(reduceMotion ? nil : .default, value: book.fraction)
                    Text(book.fraction.formatted(.percent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityHidden(true)
                    if book.isFinished {
                        Label("Finished", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppDesign.Color.accent)
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(book.title) by \(book.author)")
            .accessibilityValue(book.isFinished ? "Finished" : "\(book.fraction.formatted(.percent)) read")

            Spacer()

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: book.isFavorite ? "star.fill" : "star")
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(book.isFavorite ? AppDesign.Color.accent : .secondary)
            .accessibilityLabel(book.isFavorite ? "Remove from favourites" : "Add to favourites")
            .sensoryFeedback(.selection, trigger: book.isFavorite)
        }
        .padding(.vertical, AppDesign.Space.small)
    }
}
