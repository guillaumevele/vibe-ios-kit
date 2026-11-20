// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    let model: GroceryListModel

    @State private var addRequest: ItemDraft?
    @State private var pendingDelete: GroceryItem?
    @State private var isDeleteConfirmationShown = false

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    ProgressView("Loading your grocery list")
                case .empty:
                    ContentUnavailableView {
                        Label("Your list is empty", systemImage: "cart")
                    } description: {
                        Text("Add your first item and it will be saved on this device.")
                    } actions: {
                        Button("Add item") {
                            addRequest = ItemDraft()
                        }
                    }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't load your list", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry") {
                            Task { await model.load() }
                        }
                    }
                case .content:
                    listView
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addRequest = ItemDraft()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $addRequest) { _ in
                NavigationStack {
                    AddItemView { title, category in
                        Task { await model.add(title: title, category: category) }
                    }
                }
            }
            .alert("Delete this item?", isPresented: $isDeleteConfirmationShown) {
                Button("Delete", role: .destructive) {
                    if let item = pendingDelete {
                        Task { await model.delete(item) }
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("It will be removed from your saved list.")
            }
            .task {
                await model.load()
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            if let notice = model.saveNotice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
            }
            List {
                ForEach(model.sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            ItemRow(item: item) {
                                Task { await model.toggle(item) }
                            } onDelete: {
                                pendingDelete = item
                                isDeleteConfirmationShown = true
                            }
                        }
                    } header: {
                        Label(section.category.title, systemImage: section.category.symbolName)
                            .font(.headline)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

#Preview("List with items") {
    ContentView(model: GroceryListModel(store: InMemoryGroceryStore(items: GroceryItem.samples)))
}

#Preview("Empty list") {
    ContentView(model: GroceryListModel(store: InMemoryGroceryStore()))
}
