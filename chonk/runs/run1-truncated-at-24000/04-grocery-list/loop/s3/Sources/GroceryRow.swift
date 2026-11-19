// FILE: GroceryRow.swift
import SwiftUI

struct GroceryRow: View {
    let item: GroceryItem
    let onToggle: @MainActor () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: Spacing.medium) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? Accent.color : Color.secondary)
                    .accessibilityHidden(true)
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                Spacer()
                Image(systemName: item.category.symbolName)
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isDone)
        .accessibilityLabel("\(item.name), \(item.category.name)")
        .accessibilityValue(item.isDone ? "Checked off" : "Not checked off")
        .accessibilityHint("Double tap to check off or uncheck")
    }
}
