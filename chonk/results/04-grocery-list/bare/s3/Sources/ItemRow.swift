// FILE: ItemRow.swift
import SwiftUI

/// A tappable row that checks the item off (or back on).
struct ItemRow: View {
    let item: GroceryItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.category.color)
                Text(item.name)
                    .multilineTextAlignment(.leading)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name + (item.isChecked ? ", checked off" : ", not checked"))
        .accessibilityHint(item.isChecked ? "Double-tap to mark as not bought" : "Double-tap to check off")
    }
}
