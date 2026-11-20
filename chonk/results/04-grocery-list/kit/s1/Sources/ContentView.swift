// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @Bindable var model: GroceryListModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .failed(let message):
                    failedView(message: message)
                case .content:
                    listView
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.draft = ItemDraft()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                    .disabled(model.state != .content)
                }
            }
            .sheet(item: $model.draft) { _ in
                AddItemView(model: model)
            }
            .alert("Delete this item?", isPresented: itemDeletionPresented) {
                Button("Delete", role: .destructive) {
                    if let pending = model.itemPendingDeletion {
                        Task {
                            await model.delete(item: pending.itemID, in: pending.categoryID)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    model.itemPendingDeletion = nil
                }
            } message: {
                Text("It will be removed from your list.")
            }
            .alert("Delete this category?", isPresented: categoryDeletionPresented) {
                Button("Delete", role: .destructive) {
                    if let category = model.categoryPendingDeletion {
                        Task {
                            await model.deleteCategory(category)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    model.categoryPendingDeletion = nil
                }
            } message: {
                Text("The category and all of its items will be removed.")
            }
            .alert("Couldn't save changes", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) {
                    model.saveError = nil
                }
            } message: {
                if let saveError = model.saveError {
                    Text(saveError)
                }
            }
        }
        .task {
            await model.load()
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.medium) {
            ProgressView()
            Text("Loading your list")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Nothing on the list yet", systemImage: "cart")
        } description: {
            Text("Add your first grocery and it will be saved on this device.")
        } actions: {
            Button("Add item") {
                model.draft = ItemDraft()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func failedView(message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load your list", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    await model.load()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var listView: some View {
        List {
            ForEach(model.categories) { category in
                Section {
                    ForEach(category.items) { item in
                        ItemRow(
                            item: item,
                            onToggle: {
                                Task {
                                    await model.toggle(item: item.id, in: category.id)
                                }
                            },
                            onDelete: {
                                model.itemPendingDeletion = PendingItemDeletion(
                                    categoryID: category.id,
                                    itemID: item.id
                                )
                            }
                        )
                    }
                } header: {
                    CategoryHeader(
                        category: category,
                        remaining: model.remainingCount(in: category.id),
                        onDelete: {
                            model.categoryPendingDeletion = category
                        }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var itemDeletionPresented: Binding<Bool> {
        Binding(
            get: { model.itemPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    model.itemPendingDeletion = nil
                }
            }
        )
    }

    private var categoryDeletionPresented: Binding<Bool> {
        Binding(
            get: { model.categoryPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    model.categoryPendingDeletion = nil
                }
            }
        )
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { model.saveError != nil },
            set: { isPresented in
                if !isPresented {
                    model.saveError = nil
                }
            }
        )
    }
}

#Preview("With items") {
    ContentView(model: GroceryListModel(store: MemoryGroceryStore(loaded: SampleData.categories)))
}

#Preview("Empty") {
    ContentView(model: GroceryListModel(store: MemoryGroceryStore()))
}
