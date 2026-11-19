// FILE: AddItemView.swift
import SwiftUI

struct ItemDraft: Identifiable {
    let id = UUID()
}

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: Category = .produce

    let onSave: (String, Category) -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("Item name") {
                TextField("Bananas", text: $title)
                    .textInputAutocapitalization(.sentences)
            }
            Section {
                Picker("Category", selection: $category) {
                    ForEach(Category.allCases) { option in
                        Label(option.title, systemImage: option.symbolName)
                            .tag(option)
                    }
                }
            }
        }
        .navigationTitle("New item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(title, category)
                    dismiss()
                }
                .disabled(trimmedTitle.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddItemView { _, _ in }
    }
}
