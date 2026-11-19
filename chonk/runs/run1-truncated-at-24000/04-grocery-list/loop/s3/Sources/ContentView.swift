// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    let model: GroceryListModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: NewItemDraft?

    var body: some View {
        NavigationStack {
            stateView
                .navigationTitle("Groceries")
                .toolbar {
                    if model.canAdd {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                draft = NewItemDraft()
                            } label: {
                                Label("Add item", systemImage: "plus")
                            }
                        }
                    }
                }
        }
        .sheet(item: $draft) { _ in
            NewItemSheet(model: model)
        }
        .alert("Delete this item?", isPresented: deleteAlertBinding) {
            Button("Delete", role: .destructive) {
                model.deletePending()
            }
            Button("Cancel", role: .cancel) {
                model.cancelDelete()
            }
        } message: {
            Text(model.pendingDeletion?.name ?? "")
        }
        .alert("Couldn't save changes", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {
                model.saveError = nil
            }
        } message: {
            Text(model.saveError ?? "")
        }
        .task {
            await model.load()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { await model.persistNow() }
            }
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch model.state {
        case .loading:
            loadingView
        case .empty:
            emptyView
        case .failed(let message):
            failedView(message: message)
        case .content:
            groceryList
        }
    }

    private var loadingView: some View {
        ProgressView("Loading your groceries")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No groceries yet", systemImage: "cart")
        } description: {
            Text("Add your first item and it will be saved on this device.")
        } actions: {
            Button("Add item", systemImage: "plus") {
                draft = NewItemDraft()
            }
        }
    }

    private func failedView(message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load groceries", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(message)
                Text("Your saved list was not changed. New edits won't be saved until loading succeeds.")
            }
        } actions: {
            Button("Retry", systemImage: "arrow.clockwise") {
                Task { await model.load() }
            }
        }
    }

    private var groceryList: some View {
        List {
            summarySection
            ForEach(model.sections) { section in
                CategorySectionView(section: section, model: model)
            }
        }
        .listStyle(.insetGrouped)
        .animation(reduceMotion ? nil : .default, value: model.sections)
    }

    private var summarySection: some View {
        Section {
            Text("\(model.remainingCount) of \(model.totalCount) remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { model.pendingDeletion != nil },
            set: { if !$0 { model.cancelDelete() } }
        )
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { model.saveError != nil },
            set: { if !$0 { model.saveError = nil } }
        )
    }
}

#Preview("Populated") {
    ContentView(model: GroceryListModel(store: InMemoryGroceryStore(items: [
        GroceryItem(name: "Apples", category: .produce),
        GroceryItem(name: "Bananas", category: .produce, isDone: true),
        GroceryItem(name: "Milk", category: .dairy),
        GroceryItem(name: "Bread", category: .bakery),
        GroceryItem(name: "Chicken", category: .meatAndFish, isDone: true),
        GroceryItem(name: "Pasta", category: .pantry),
        GroceryItem(name: "Ice cream", category: .frozen),
        GroceryItem(name: "Orange juice", category: .drinks),
        GroceryItem(name: "Dish soap", category: .household)
    ])))
}

#Preview("Empty") {
    ContentView(model: GroceryListModel(store: InMemoryGroceryStore()))
}
