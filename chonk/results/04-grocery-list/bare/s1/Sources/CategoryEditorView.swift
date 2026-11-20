// FILE: CategoryEditorView.swift
import SwiftUI
import SwiftData

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existing: Category?

    @State private var name: String
    @State private var symbolName: String
    @State private var color: CategoryColor
    @FocusState private var isFocused: Bool

    init(existing: Category? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _symbolName = State(initialValue: existing?.symbolName ?? "cart")
        _color = State(initialValue: existing?.color ?? .green)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { if isValid { save() } }
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 48))], spacing: 10) {
                        ForEach(SymbolLibrary.icons, id: \.self) { icon in
                            Button {
                                symbolName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 48, height: 48)
                                    .foregroundStyle(symbolName == icon ? .white : color.color)
                                    .background(
                                        symbolName == icon ? color.color : Color.secondary.opacity(0.12),
                                        in: .rect(cornerRadius: 12)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    HStack(spacing: 14) {
                        ForEach(CategoryColor.allCases) { option in
                            Button {
                                withAnimation(.spring(response: 0.2)) {
                                    color = option
                                }
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if color == option {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(option == .yellow ? .black : .white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.label)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existing == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if existing == nil { isFocused = true }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existing {
            existing.name = trimmed
            existing.symbolName = symbolName
            existing.color = color
        } else {
            let count = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
            modelContext.insert(Category(name: trimmed, symbolName: symbolName, color: color, sortOrder: count))
        }
        try? modelContext.save()
        dismiss()
    }
}
