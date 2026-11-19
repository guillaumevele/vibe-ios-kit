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
                    .foregroundStyle(item.isChecked ? Theme.accent : .secondary)
                    .accessibilityHidden(true)
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.xsmall)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityValue(item.isChecked ? "Checked" : "Not checked")
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
