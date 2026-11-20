// FILE: BookDetailView.swift
import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CoverView(title: book.title, author: book.author, size: 120)

                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(book.author.isEmpty ? "Unknown author" : book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    book.isFavorite.toggle()
                    book.lastUpdated = Date()
                } label: {
                    Label(
                        book.isFavorite ? "Remove from favorites" : "Add to favorites",
                        systemImage: book.isFavorite ? "star.fill" : "star"
                    )
                    .foregroundStyle(book.isFavorite ? .yellow : .primary)
                }
                .buttonStyle(.bordered)

                VStack(spacing: 12) {
                    HStack {
                        Text("Progress")
                            .font(.headline)
                        Spacer()
                        Text(book.percentText)
                            .font(.headline)
                            .monospacedDigit()
                    }

                    ProgressView(value: book.progress)
                        .tint(book.isFinished ? .green : .accentColor)

                    Slider(
                        value: Binding(
                            get: { Double(book.currentPage) },
                            set: { book.setProgress(page: Int($0.rounded())) }
                        ),
                        in: 0...Double(max(book.totalPages, 1)),
                        step: 1
                    ) {
                        Text("Current page")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("\(book.totalPages)")
                    }

                    HStack {
                        Text("\(book.currentPage) of \(book.totalPages) pages")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if book.isFinished {
                            Label("Finished", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            book.setProgress(page: book.currentPage - 1)
                        } label: {
                            Label("Previous page", systemImage: "minus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(book.currentPage <= 0)

                        Button {
                            book.setProgress(page: book.currentPage + 1)
                        } label: {
                            Label("Next page", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(book.currentPage >= book.totalPages)
                    }

                    HStack(spacing: 12) {
                        Button("Mark as finished") {
                            book.setProgress(page: book.totalPages)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(book.isFinished)

                        Button("Reset", role: .destructive) {
                            book.setProgress(page: 0)
                        }
                        .buttonStyle(.bordered)
                        .disabled(book.currentPage == 0)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "Added \(book.dateAdded.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "calendar"
                    )
                    Label(
                        "Last updated \(book.lastUpdated.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "clock"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete book", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this book?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(book)
                dismiss()
            }
        }
    }
}
