// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    let model: GroceryListModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: NewItemDraft?

    private var isPresentingDeleteAlert: Binding<Bool> {
        Binding(
            get: { model.pendingDeletion != nil },
            set: { if !$0 { model.cancelDelete() } }
        )
    }

    private var isPresentingSaveError: Binding<Bool> {
        Binding(
            get: { model.saveError != nil },
            set: { if !$0 { model.saveError = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    ProgressView("Loading your groceries")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ContentUnavailableView(
                        "No groceries yet",
                        systemImage: "cart",
                        description: Text("Add your first item and it will be saved on this device.")
                    ) {
                        Button("Add item", systemImage: "plus") {
                            draft = NewItemDraft()
                        }
                    }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't load groceries", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("\(message) Your saved list was not changed, and new edits won't be saved until loading succeeds.")
                    } actions: {
                        Button("Retry", systemImage: "arrow.clockwise") {
                            Task { await model.load() }
                        }
                    }
                case .content:
                    groceryList
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draft = NewItemDraft()
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $draft) { _ in
                NewItemSheet(model: model)
            }
            .alert("Delete this item?", isPresented: isPresentingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    model.deletePending()
                }
                Button("Cancel", role: .cancel) {
                    model.cancelDelete()
                }
            } message: {
                Text(model.pendingDeletion?.name ?? "")
            }
            .alert("Couldn't save changes", isPresented: isPresentingSaveError) {
                Button("OK", role: .cancel) {
                    model.saveError = nil
                }
            } message: {
                Text(model.saveError ?? "")
            }
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

    private var groceryList: some View {
        List {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.items) { item in
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
                } header: {
                    Label(section.category.name, systemImage: section.category.symbolName)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationSubtitle("\(model.remainingCount) of \(model.totalCount) remaining")
        .animation(reduceMotion ? nil : .default, value: model.sections)
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
