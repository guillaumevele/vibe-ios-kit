// FILE: GroceryRowView.swift
import SwiftUI

struct GroceryRowView: View {
    let item: GroceryItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.mediumSpacing) {
            Button(action: onToggle) {
                HStack(spacing: Theme.mediumSpacing) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isChecked ? Theme.accent : .secondary)
                    Text(item.name)
                        .font(.body)
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                }
                .contentShape(.rect)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Mark \(item.name) as not bought" : "Mark \(item.name) as bought")
            .sensoryFeedback(.selection, trigger: item.isChecked)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(item.name)")
        }
        .animation(reduceMotion ? nil : .default, value: item.isChecked)
    }
}
