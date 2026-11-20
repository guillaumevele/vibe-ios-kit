// FILE: GroceryListView.swift
import SwiftUI

struct GroceryListView: View {
    @State private var viewModel: GroceryListViewModel
    @State private var draft: NewItemDraft?
    @State private var pendingDelete: GroceryItem?

    init(viewModel: GroceryListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Groceries")
                .navigationSubtitle("\(viewModel.remainingCount) of \(viewModel.totalCount) remaining")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if case .content = viewModel.state {
                            Button {
                                draft = NewItemDraft()
                            } label: {
                                Label("Add", systemImage: "plus")
                            }
                        }
                    }
                }
                .sheet(item: $draft) { _ in
                    AddItemView(viewModel: viewModel)
                }
                .alert("Delete item?", item: $pendingDelete) { item in
                    Button("Delete", role: .destructive) {
                        Task { await viewModel.delete(item) }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: { item in
                    Text("This removes \(item.name) from your saved list.")
                }
                .task {
                    await viewModel.load()
                }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .loading:
            VStack {
                Spacer()
                ProgressView("Loading your groceries…")
                Spacer()
            }
        case .empty:
            ContentUnavailableView {
                Label("No groceries yet", systemImage: "cart")
            } description: {
                Text("Add your first item and it will be saved for next time.")
            } actions: {
                Button("Add Item", systemImage: "plus") {
                    draft = NewItemDraft()
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load your list", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry", systemImage: "arrow.clockwise") {
                    Task { await viewModel.load() }
                }
            }
        case .content:
            list
        }
    }

    private var list: some View {
        List {
            if let saveError = viewModel.saveError {
                Section {
                    HStack(spacing: Spacing.sm) {
                        Label("Changes not saved yet", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Retry") {
                            Task { await viewModel.retrySave() }
                        }
                        .font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        GroceryRow(
                            item: item,
                            onToggle: { Task { await viewModel.toggle(item) } },
                            onDelete: { pendingDelete = item }
                        )
                    }
                } header: {
                    Label(section.category.title, systemImage: section.category.symbolName)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

#if DEBUG
#Preview("Content") {
    GroceryListView(viewModel: GroceryListViewModel(store: PreviewGroceryStore(stored: [
        GroceryItem(name: "Bananas", category: .produce),
        GroceryItem(name: "Apples", category: .produce, isChecked: true),
        GroceryItem(name: "Milk", category: .dairy),
        GroceryItem(name: "Bread", category: .bakery),
        GroceryItem(name: "Chicken breast", category: .meat),
        GroceryItem(name: "Pasta", category: .pantry),
        GroceryItem(name: "Ice cream", category: .frozen),
        GroceryItem(name: "Coffee beans", category: .beverages),
        GroceryItem(name: "Dish soap", category: .household)
    ])))
}

#Preview("Empty") {
    GroceryListView(viewModel: GroceryListViewModel(store: PreviewGroceryStore()))
}

#Preview("Failed to load") {
    GroceryListView(viewModel: GroceryListViewModel(store: PreviewGroceryStore(shouldFail: true)))
}
#endif
