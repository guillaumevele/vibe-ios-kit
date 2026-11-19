// FILE: BookDetailView.swift
import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var book: Book

    @State private var isPresentingEdit = false
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressRing

                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                progressControls

                Toggle(isOn: $book.isFavorite) {
                    Label("Favorite", systemImage: "star.fill")
                }
                .tint(.yellow)
                .padding(.horizontal)

                if let notes = book.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                Text("Added \(book.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isPresentingEdit = true }
            }
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            BookFormView(book: book)
        }
        .confirmationDialog(
            "Delete \"\(book.title)\"? This cannot be undone.",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(book)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.15), lineWidth: 20)
            Circle()
                .trim(from: 0, to: CGFloat(book.progress))
                .stroke(
                    book.isFinished ? .green : .blue,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: book.progress)
            VStack(spacing: 2) {
                Text(book.percentText)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(book.isFinished ? "Finished" : "read")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 210, height: 210)
    }

    private var progressControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text("\(book.pagesRead) / \(book.totalPages) pages")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(book.pagesRead) },
                    set: { book.pagesRead = Int($0.rounded()).clamped(to: 0...book.totalPages) }
                ),
                in: 0...Double(book.totalPages),
                step: 1
            ) {
                Text("Pages read")
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("\(book.totalPages)")
            }

            HStack(spacing: 12) {
                Button { adjustPages(by: -10) } label: { Text("−10") }
                Button { adjustPages(by: -1) } label: { Text("−1") }
                Spacer()
                Button { adjustPages(by: 1) } label: { Text("+1") }
                Button { adjustPages(by: 10) } label: { Text("+10") }
            }
            .buttonStyle(.bordered)

            Button {
                withAnimation {
                    book.pagesRead = book.isFinished ? 0 : book.totalPages
                }
            } label: {
                Label(
                    book.isFinished ? "Mark as Not Finished" : "Mark as Finished",
                    systemImage: book.isFinished ? "arrow.uturn.backward" : "checkmark.circle"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(book.isFinished ? .orange : .green)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    private func adjustPages(by delta: Int) {
        withAnimation {
            book.pagesRead = (book.pagesRead + delta).clamped(to: 0...book.totalPages)
        }
    }
}
