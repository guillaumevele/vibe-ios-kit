// FILE: ItemRow.swift
import SwiftUI
import SwiftData

struct ItemRow: View {
    @Bindable var item: GroceryItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.25)) {
                    item.isChecked.toggle()
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isChecked ? .green : .secondary)
            }
            .buttonStyle(.glass) // iOS 26 Liquid Glass
            .accessibilityLabel(item.isChecked ? "Uncheck \(item.name)" : "Check off \(item.name)")

            Text(item.name)
                .strikethrough(item.isChecked, color: .secondary)
                .foregroundStyle(item.isChecked ? .secondary : .primary)
                .animation(.default, value: item.isChecked)

            Spacer()
        }
        .contentShape(.rect)
    }
}
