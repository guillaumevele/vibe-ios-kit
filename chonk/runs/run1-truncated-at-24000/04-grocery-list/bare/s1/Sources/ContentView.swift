// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]

    @State private var showAddCategory = false

    private var totalItems: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }

    private var checkedItems: Int {
        categories.reduce(0) { total, category in
            total + category.items.filter(\.isChecked).count
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    ContentUnavailableView {
                        Label("No categories yet", systemImage: "cart")
                    } description: {
                        Text("Create a category to start your grocery list.")
                    } actions: {
                        Button("Add Category") {
                            showAddCategory = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("Shopping progress", systemImage: "list.bullet.clipboard")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(checkedItems) of \(totalItems) checked")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: Double(checkedItems),
                                             total: Double(max(totalItems, 1)))
                                    .tint(.green)
                            }
                            .padding(.vertical, 4)
                        }

                        Section("Categories") {
                            ForEach(categories) { category in
                                NavigationLink(value: category) {
                                    CategoryRow(category: category)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(category)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete(perform: deleteCategories)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView()
            }
            .navigationDestination(for: Category.self) { category in
                CategoryDetailView(category: category)
            }
            .task {
                SeedData.seedDefaultCategoriesIfNeeded(modelContext: modelContext)
            }
        }
    }

    private func delete(_ category: Category) {
        withAnimation {
            modelContext.delete(category)
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(categories[index])
            }
        }
    }
}

private struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.symbolName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(category.tint.gradient,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.headline)
                let total = category.items.count
                let done = total - category.uncheckedCount
                Text(total == 0 ? "No items yet" : "\(done) of \(total) picked up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if category.uncheckedCount > 0 {
                Text("\(category.uncheckedCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(category.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(category.tint.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
