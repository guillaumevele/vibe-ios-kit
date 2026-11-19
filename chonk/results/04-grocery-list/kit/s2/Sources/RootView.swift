// FILE: RootView.swift
import SwiftUI

struct RootView: View {
    @State private var viewModel: GroceryListViewModel
    @State private var addItemSheet: AddItemSheet?

    init(store: GroceryStore = GroceryStore.file) {
        _viewModel = State(initialValue: GroceryListViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .failed(let message):
                    failedView(message)
                case .content:
                    listView
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addItemSheet = AddItemSheet()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(item: $addItemSheet) { _ in
                AddItemView { name, category in
                    await viewModel.add(name: name, category: category)
                }
            }
            .alert(deleteAlertTitle, isPresented: deleteAlertPresented) {
                Button("Delete", role: .destructive) {
                    if let item = viewModel.pendingDelete {
                        viewModel.pendingDelete = nil
                        Task { await viewModel.delete(item) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.pendingDelete = nil
                }
            } message: {
                Text("This removes the item from your saved list.")
            }
            .alert("Couldn't save changes", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) {
                    viewModel.saveErrorMessage = nil
                }
            } message: {
                Text(viewModel.saveErrorMessage ?? "Your changes could not be saved.")
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Theme.mediumSpacing) {
            ProgressView()
            Text("Loading your list")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Your list is empty", systemImage: "cart")
        } description: {
            Text("Add your first grocery to get started.")
        } actions: {
            Button("Add item") {
                addItemSheet = AddItemSheet()
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load your list", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                viewModel.retry()
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.groupedItems, id: \.category.id) { group in
                Section {
                    ForEach(group.items) { item in
                        GroceryRowView(
                            item: item,
                            onToggle: { Task { await viewModel.toggle(item) } },
                            onDelete: { viewModel.pendingDelete = item }
                        )
                    }
                } header: {
                    HStack {
                        Label(group.category.title, systemImage: group.category.symbolName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(group.items.count) items")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var deleteAlertTitle: String {
        if let item = viewModel.pendingDelete {
            "Delete \(item.name)?"
        } else {
            "Delete item?"
        }
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDelete != nil },
            set: { if !$0 { viewModel.pendingDelete = nil } }
        )
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.saveErrorMessage != nil },
            set: { if !$0 { viewModel.saveErrorMessage = nil } }
        )
    }
}

#Preview("With items") {
    RootView(store: InMemoryGroceryStore(initial: [
        GroceryItem(name: "Bananas", category: .produce),
        GroceryItem(name: "Apples", category: .produce, isChecked: true),
        GroceryItem(name: "Whole milk", category: .dairy),
        GroceryItem(name: "Sourdough bread", category: .bakery),
        GroceryItem(name: "Chicken breast", category: .meatAndSeafood),
        GroceryItem(name: "Olive oil", category: .pantry),
        GroceryItem(name: "Vanilla ice cream", category: .frozen, isChecked: true),
        GroceryItem(name: "Dish soap", category: .household)
    ]))
}

#Preview("Empty") {
    RootView(store: InMemoryGroceryStore(initial: []))
}
