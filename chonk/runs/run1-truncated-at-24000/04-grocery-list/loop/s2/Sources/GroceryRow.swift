// FILE: GroceryRow.swift
import SwiftUI

struct GroceryRow: View {
    let item: GroceryItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
                    .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: item.isChecked)
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
                Image(systemName: item.category.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.category.title)")
        .accessibilityValue(item.isChecked ? "Bought" : "Not bought")
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onToggle()
            } label: {
                Label(item.isChecked ? "Not bought" : "Bought", systemImage: "checkmark.circle")
            }
            .tint(item.isChecked ? .orange : .green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                onToggle()
            } label: {
                Label(item.isChecked ? "Mark as not bought" : "Mark as bought", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
