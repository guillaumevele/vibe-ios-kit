// FILE: BookFormView.swift
import SwiftUI

struct BookFormView: View {
    enum Mode {
        case add
        case edit(Book)
    }

    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = 0
    @State private var pagesRead = 0
    @State private var status: ReadingStatus = .wantToRead
    @State private var isFavourite = false
    @State private var coverHue = 0.58
    @State private var notes = ""

    private let palette: [Double] = [0.0, 0.07, 0.13, 0.33, 0.55, 0.66, 0.78, 0.9]

    init(mode: Mode) {
        self.mode = mode
        if case .edit(let book) = mode {
            _title = State(initialValue: book.title)
            _author = State(initialValue: book.author)
            _totalPages = State(initialValue: book.totalPages)
            _pagesRead = State(initialValue: book.pagesRead)
            _status = State(initialValue: book.status)
            _isFavourite = State(initialValue: book.isFavourite)
            _coverHue = State(initialValue: book.coverHue)
            _notes = State(initialValue: book.notes)
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var navigationTitle: String {
        if case .edit = mode { return "Edit Book" }
        return "Add Book"
    }

    private var previewBook: Book {
        Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: max(totalPages, 0),
            pagesRead: max(pagesRead, 0),
            status: status,
            isFavourite: isFavourite,
            coverHue: coverHue,
            notes: notes
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book details") {
                    TextField("Title", text: $title)
                        .autocorrectionDisabled()
                    TextField("Author", text: $author)
                        .autocorrectionDisabled()
                    Stepper(value: $totalPages, in: 0...100_000) {
                        Text("Total pages: \(Formatters.pagesString(totalPages))")
                    }
                    Stepper(value: $pagesRead, in: 0...max(totalPages, pagesRead, 1)) {
                        Text("Pages read: \(Formatters.pagesString(pagesRead))")
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ReadingStatus.allCases) { s in
                            Label(s.rawValue, systemImage: s.systemImage).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: $isFavourite) {
                        Label("Favourite", systemImage: "star.fill")
                    }
                    .tint(.yellow)
                }

                Section("Cover") {
                    HStack(spacing: 16) {
                        CoverView(book: previewBook, width: 56)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Colour")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 28))], spacing: 8) {
                                ForEach(palette, id: \.self) { hue in
                                    Circle()
                                        .fill(Color(hue: hue, saturation: 0.55, brightness: 0.9))
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            if abs(hue - coverHue) < 0.005 {
                                                Circle().stroke(Color.primary, lineWidth: 2)
                                            }
                                        }
                                        .onTapGesture { coverHue = hue }
                                }
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle(navigationTitle)
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
        }
    }

    private func save() {
        var book = previewBook
        if case .edit(let original) = mode {
            book.id = original.id
            book.dateAdded = original.dateAdded
            book.history = original.history
            book.dateFinished = original.dateFinished
        }
        if status == .finished {
            book.status = .finished
            book.dateFinished = Date()
            if book.totalPages > 0 {
                book.pagesRead = book.totalPages
            }
        }
        if case .edit = mode {
            store.update(book)
        } else {
            store.add(book)
        }
        dismiss()
    }
}
