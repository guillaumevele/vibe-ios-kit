// FILE: ItemRow.swift
import SwiftUI

struct ItemRow: View {
    let item: GroceryItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Palette.accent : Color.secondary)
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(item.title)
                        .font(.body)
                        .strikethrough(item.isChecked, color: .secondary)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    Text(item.category.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, Spacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.category.title)")
        .accessibilityValue(item.isChecked ? "Checked" : "Not checked")
        .accessibilityHint(item.isChecked ? "Double-tap to mark as not bought yet" : "Double-tap to check off")
        .accessibilityAddTraits(item.isChecked ? .isSelected : [])
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
