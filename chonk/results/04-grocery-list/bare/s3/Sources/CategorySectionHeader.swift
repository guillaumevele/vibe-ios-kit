// FILE: CategorySectionHeader.swift
import SwiftUI

/// Section header showing the category symbol, name, and remaining-item count.
struct CategorySectionHeader: View {
    let category: Category
    let remaining: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.symbol)
                .foregroundStyle(category.color)
            Text(category.rawValue)
                .font(.headline)
            if remaining > 0 {
                Text("\(remaining)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(category.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(category.color.opacity(0.18))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .textCase(nil)
    }
}
