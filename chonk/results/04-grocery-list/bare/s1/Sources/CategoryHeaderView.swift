// FILE: CategoryHeaderView.swift
import SwiftUI

struct CategoryHeaderView: View {
    let category: Category

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(category.color.color)
                .frame(width: 30, height: 30)
                .glassEffect(.regular.tint(category.color.color.opacity(0.3)), in: .circle) // iOS 26

            Text(category.name)
                .font(.headline)

            Spacer()

            if category.uncheckedCount > 0 {
                Text("\(category.uncheckedCount) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
