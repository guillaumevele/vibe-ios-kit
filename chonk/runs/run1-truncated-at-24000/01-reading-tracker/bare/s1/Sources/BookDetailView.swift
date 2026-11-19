// FILE: BookDetailView.swift
import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var book: Book

    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ProgressRingView(progress: book.progress, isFinished: book.isFinished)
                        .frame(width: 84, height: 84)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title)
                            .font(.title2.bold())
                            .lineLimit(2)
                        Text(book.author.isEmpty ? "Unknown author" : book.author)
                            .foregroundStyle(.secondary)
                        if book.isFinished {
                            Label("Finished", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        } else if book.totalPages > 0 {
                            Text("\(book.pagesRemaining) pages left")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Favourite") {
                Toggle(isOn: $book.isFavorite) {
                    Label("Favourite", systemImage: book.isFavorite ? "star.fill" : "star")
                }
                .tint(.yellow)
            }

            Section("Progress") {
                Stepper(value: totalPagesBinding, in: 0...9999) {
                    LabeledContent("Total pages", value: "\(book.totalPages)")
                }
                Stepper(value: pagesReadBinding, in: 0...max(book.totalPages, 1)) {
                    LabeledContent("Pages read", value: "\(book.pagesRead)")
                }

                if book.totalPages > 0 {
                    Slider(
                        value: sliderBinding,
                        in: 0...Double(book.totalPages),
                        step: 1
                    ) {
                        Text("Progress")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("\(book.totalPages)")
                    }
                    Text("\(Int(book.progress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        if !book.isFinished {
                            Button("Mark as finished") {
                                book.pagesRead = book.totalPages
                            }
                        }
                        Button("Reset progress", role: .destructive) {
                            book.pagesRead = 0
                        }
                    }
                } else {
                    Text("Enter the total page count to track progress with the slider.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notes") {
                TextEditor(text: $book.notes)
                    .frame(minHeight: 100)
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete book", systemImage: "trash")
                }
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    book.isFavorite.toggle()
                } label: {
                    Image(systemName: book.isFavorite ? "star.fill" : "star")
                }
                .tint(.yellow)
                .accessibilityLabel(book.isFavorite ? "Remove from favourites" : "Add to favourites")
            }
        }
        .confirmationDialog(
            "Delete \"\(book.title)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(book)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var totalPagesBinding: Binding<Int> {
        Binding(
            get: { book.totalPages },
            set: { newValue in
                book.totalPages = max(0, newValue)
                if book.totalPages > 0 && book.pagesRead > book.totalPages {
                    book.pagesRead = book.totalPages
                }
            }
        )
    }

    private var pagesReadBinding: Binding<Int> {
        Binding(
            get: { book.pagesRead },
            set: { setPagesRead($0) }
        )
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(book.pagesRead) },
            set: { setPagesRead(Int($0.rounded())) }
        )
    }

    private func setPagesRead(_ value: Int) {
        let upperBound = book.totalPages > 0 ? book.totalPages : Int.max
        book.pagesRead = min(max(0, value), upperBound)
    }
}
