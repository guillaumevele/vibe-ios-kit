// FILE: BookDetailView.swift
import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var book: Book

    @State private var showingDeleteAlert = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Text("\(book.progressPercent)%")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(book.status.color)
                        .contentTransition(.numericText())

                    ProgressBarView(progress: book.progress, height: 12, color: book.status.color)
                        .padding(.horizontal, 4)

                    Label(book.status.rawValue, systemImage: book.status.icon)
                        .font(.subheadline)
                        .foregroundStyle(book.status.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(book.status.color.opacity(0.15))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }

            Section("Reading progress") {
                Slider(
                    value: pagesReadBinding,
                    in: 0...Double(book.totalPages),
                    step: 1
                ) {
                    Text("Pages read")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("\(book.totalPages)")
                }

                Stepper(
                    "\(book.pagesRead) of \(book.totalPages) pages",
                    value: pagesReadBinding,
                    in: 0...Double(book.totalPages)
                )

                HStack {
                    Button("Reset", role: .destructive) {
                        book.pagesRead = 0
                    }
                    Spacer()
                    Button("Mark as finished") {
                        book.pagesRead = book.totalPages
                    }
                }
            }

            Section("Details") {
                TextField("Title", text: $book.title)
                TextField("Author", text: $book.author)
                TextField("Total pages", value: $book.totalPages, format: .number)
                    .keyboardType(.numberPad)
                Toggle(isOn: $book.isFavorite) {
                    Label("Favourite", systemImage: book.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(book.isFavorite ? .yellow : .primary)
                }
                DatePicker("Added on", selection: $book.dateAdded, displayedComponents: .date)
                TextField("Notes", text: $book.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete book", systemImage: "trash")
                }
            }
        }
        .navigationTitle(book.title.isEmpty ? "Book" : book.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? modelContext.save()
        }
        .alert("Delete \"\(book.title)\"?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(book)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This book will be removed from your library.")
        }
    }

    private var pagesReadBinding: Binding<Double> {
        Binding(
            get: { Double(book.pagesRead) },
            set: { newValue in
                book.pagesRead = min(max(Int(newValue.rounded()), 0), book.totalPages)
            }
        )
    }
}
