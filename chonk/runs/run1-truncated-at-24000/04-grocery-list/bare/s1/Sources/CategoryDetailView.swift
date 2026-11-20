// FILE: CategoryDetailView.swift
import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let category: Category

    @State private var newItemName = ""
    @FocusState private var isInputFocused: Bool

    /// Unchecked items first, then alphabetical within each group.
    private var sortedItems: [GroceryItem] {
        category.items.sorted { lhs, rhs in
            if lhs.isChecked != rhs.isChecked {
                return !lhs.isChecked
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var trimmedNewItemName: String {
        newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                    TextField("Add an item…", text: $newItemName)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                    Button {
                        addItem()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(trimmedNewItemName.isEmpty ? .secondary : category.tint)
                    }
                    .disabled(trimmedNewItemName.isEmpty)
                    .buttonStyle(.plain)
                }
            }

            Section {
                ForEach(sortedItems) { item in
                    ItemRow(item: item)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                toggle(item)
                            } label: {
                                Label(item.isChecked ? "Uncheck" : "Check",
                                      systemImage: item.isChecked ? "circle" : "checkmark.circle.fill")
                            }
                            .tint(item.isChecked ? .orange : .green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                }
                .onDelete(perform: deleteItems)
            } header: {
                Text("\(category.uncheckedCount) remaining")
            } footer: {
                if sortedItems.isEmpty {
                    Text("No items yet — add your first one above.")
                }
            }
        }
        .tint(category.tint)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(category.name)
        .navigationSubtitle("\(category.items.count) items")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    clearChecked()
                } label: {
                    Label("Clear Checked", systemImage: "trash")
                }
                .disabled(category.items.allSatisfy { !$0.isChecked })
            }
        }
    }

    private func addItem() {
        guard !trimmedNewItemName.isEmpty else { return }
        let item = GroceryItem(name: trimmedNewItemName, category: category)
        withAnimation {
            modelContext.insert(item)
        }
        newItemName = "" // keyboard stays focused for rapid entry
    }

    private func toggle(_ item: GroceryItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            item.isChecked.toggle()
        }
    }

    private func delete(_ item: GroceryItem) {
        withAnimation {
            modelContext.delete(item)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sortedItems[index])
            }
        }
    }

    private func clearChecked() {
        withAnimation {
            for item in category.items where item.isChecked {
                modelContext.delete(item)
            }
        }
    }
}

private struct ItemRow: View {
    @Bindable var item: GroceryItem

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                item.isChecked.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                    .symbolEffect(.bounce, value: item.isChecked)
                Text(item.name)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked, color: .secondary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: item.isChecked)
    }
}
