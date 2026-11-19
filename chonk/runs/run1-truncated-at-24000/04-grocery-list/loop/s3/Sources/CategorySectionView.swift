// FILE: CategorySectionView.swift
import SwiftUI

struct CategorySectionView: View {
    let section: CategorySection
    let model: GroceryListModel

    var body: some View {
        Section {
            ForEach(section.items) { item in
                row(for: item)
            }
        } header: {
            Label(section.category.name, systemImage: section.category.symbolName)
        }
    }

    private func row(for item: GroceryItem) -> some View {
        GroceryRow(item: item) {
            model.toggle(item)
        }
        .swipeActions(edge: .leading, allowsFullSwipeToTrigger: true) {
            Button {
                model.toggle(item)
            } label: {
                Label(item.isDone ? "Uncheck" : "Check off", systemImage: "checkmark")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipeToTrigger: false) {
            Button(role: .destructive) {
                model.requestDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
