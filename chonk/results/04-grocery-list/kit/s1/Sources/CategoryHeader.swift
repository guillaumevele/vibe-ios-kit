// FILE: CategoryHeader.swift
import SwiftUI

struct CategoryHeader: View {
    let category: Category
    let remaining: Int
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(category.name)
                .font(.headline)
            Spacer()
            if remaining > 0 {
                Text("\(remaining) left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Label("All done", systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete category", systemImage: "trash")
            }
        }
        .accessibilityHint("Long press to delete this category")
    }
}
