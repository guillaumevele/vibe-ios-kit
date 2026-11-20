// FILE: BookDetailView.swift
import SwiftUI

struct BookDetailView: View {
    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bookID: UUID

    @State private var editingBook: Book?
    @State private var confirmingDelete = false

    private var book: Book? { store.book(with: bookID) }

    var body: some View {
        if let book {
            List {
                Section {
                    HStack(spacing: 16) {
                        CoverView(book: book, width: 104)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.title)
                                .font(.title3.bold())
                                .lineLimit(3)
                            Text(book.author.isEmpty ? "Unknown author" : book.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let finished = book.dateFinished {
                                Label("Finished \(Formatters.shortDate.string(from: finished))",
                                      systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            Label("Added \(Formatters.shortDate.string(from: book.dateAdded))",
                                  systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section("Status") {
                    Picker("Status", selection: statusBinding(book)) {
                        ForEach(ReadingStatus.allCases) { s in
                            Label(s.rawValue, systemImage: s.systemImage).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: favouriteBinding(book)) {
                        Label("Favourite", systemImage: "star.fill")
                    }
                    .tint(.yellow)
                }

                Section("Progress") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("\(Formatters.pagesString(book.pagesRead)) of \(book.totalPages > 0 ? Formatters.pagesString(book.totalPages) : "unknown") pages")
                                .font(.subheadline)
                            Spacer()
                            Text(Formatters.percentString(book.progress))
                                .font(.subheadline.bold())
                                .foregroundStyle(book.coverColor)
                        }
                        BookProgressBar(progress: book.progress, color: book.coverColor, height: 10)

                        if book.totalPages > 0 {
                            Slider(value: pagesDoubleBinding(book), in: 0...Double(book.totalPages), step: 1) {
                                Text("Pages read")
                            }
                        } else {
                            Stepper("Pages read: \(book.pagesRead)", value: pagesBinding(book), in: 0...100_000)
                        }

                        HStack(spacing: 8) {
                            ForEach([1, 10, 25, 50], id: \.self) { amount in
                                Button("+\(amount)") {
                                    store.addPages(amount, to: book.id)
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                            Spacer()
                            Button("Finish") {
                                store.setStatus(.finished, for: book.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.caption)
                            .disabled(book.status == .finished)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: notesBinding(book))
                        .frame(minHeight: 110)
                }

                if !book.history.isEmpty {
                    Section("Reading history") {
                        ForEach(book.history.sorted { $0.date > $1.date }.prefix(10)) { entry in
                            HStack {
                                Text(Formatters.shortDate.string(from: entry.date))
                                Spacer()
                                Text("+\(entry.pages) pages")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete Book", systemImage: "trash")
                    }
                    .confirmationDialog(
                        "Delete “\(book.title)”?",
                        isPresented: $confirmingDelete,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            store.delete(book.id)
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.toggleFavourite(book.id)
                    } label: {
                        Image(systemName: book.isFavourite ? "star.fill" : "star")
                    }
                    .foregroundStyle(book.isFavourite ? .yellow : .primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingBook = book
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $editingBook) { book in
                BookFormView(mode: .edit(book))
            }
        } else {
            ContentUnavailableView("Book not found", systemImage: "questionmark.book")
        }
    }

    private func statusBinding(_ book: Book) -> Binding<ReadingStatus> {
        Binding(
            get: { store.book(with: book.id)?.status ?? book.status },
            set: { store.setStatus($0, for: book.id) }
        )
    }

    private func favouriteBinding(_ book: Book) -> Binding<Bool> {
        Binding(
            get: { store.book(with: book.id)?.isFavourite ?? false },
            set: { newValue in
                if (store.book(with: book.id)?.isFavourite ?? false) != newValue {
                    store.toggleFavourite(book.id)
                }
            }
        )
    }

    private func pagesBinding(_ book: Book) -> Binding<Int> {
        Binding(
            get: { store.book(with: book.id)?.pagesRead ?? 0 },
            set: { store.setPagesRead($0, for: book.id) }
        )
    }

    private func pagesDoubleBinding(_ book: Book) -> Binding<Double> {
        Binding(
            get: { Double(store.book(with: book.id)?.pagesRead ?? 0) },
            set: { store.setPagesRead(Int($0.rounded()), for: book.id) }
        )
    }

    private func notesBinding(_ book: Book) -> Binding<String> {
        Binding(
            get: { store.book(with: book.id)?.notes ?? "" },
            set: { store.setNotes($0, for: book.id) }
        )
    }
}
