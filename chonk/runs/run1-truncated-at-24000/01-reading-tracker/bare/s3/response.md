Here's a complete SwiftUI + SwiftData reading tracker for iOS 26 — persistence via `@Model`, a library list with search, an All/Favorites filter, per-book progress (row bars + detail ring with slider/steppers), swipe-to-favorite/delete, and add/edit forms. Only Apple frameworks are used.

```swift
// FILE: BookReadingApp.swift
import SwiftUI
import SwiftData

@main
struct BookTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Book.self)
    }
}
```

```swift
// FILE: Book.swift
import Foundation
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var totalPages: Int
    var pagesRead: Int
    var isFavorite: Bool
    var dateAdded: Date
    var notes: String?

    init(
        title: String,
        author: String,
        totalPages: Int,
        pagesRead: Int = 0,
        isFavorite: Bool = false,
        dateAdded: Date = .now,
        notes: String? = nil
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(1, totalPages)
        self.pagesRead = min(max(0, pagesRead), self.totalPages)
        self.isFavorite = isFavorite
        self.dateAdded = dateAdded
        self.notes = notes
    }

    /// Reading progress in the range 0...1.
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesRead) / Double(totalPages)
    }

    var isFinished: Bool {
        totalPages > 0 && pagesRead >= totalPages
    }

    var percentText: String {
        "\(Int(progress * 100))%"
    }
}
```

```swift
// FILE: BookFilter.swift
import Foundation

enum BookFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: "books.vertical"
        case .favorites: "star.fill"
        }
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var filter: BookFilter = .all
    @State private var searchText = ""
    @State private var isPresentingAddBook = false

    private var visibleBooks: [Book] {
        books.filter { book in
            if filter == .favorites && !book.isFavorite { return false }
            guard !searchText.isEmpty else { return true }
            return book.title.localizedCaseInsensitiveContains(searchText)
                || book.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleBooks) { book in
                    NavigationLink(value: book) {
                        BookRowView(book: book)
                    }
                    .swipeActions {
                        Button {
                            withAnimation { book.isFavorite.toggle() }
                        } label: {
                            Label(
                                book.isFavorite ? "Remove Favorite" : "Favorite",
                                systemImage: book.isFavorite ? "star.slash.fill" : "star.fill"
                            )
                        }
                        .tint(.yellow)

                        Button(role: .destructive) {
                            withAnimation { modelContext.delete(book) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Reading List")
            .navigationSubtitle("\(visibleBooks.count) \(visibleBooks.count == 1 ? "book" : "books")")
            .searchable(text: $searchText, prompt: "Title or author")
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddBook = true
                    } label: {
                        Label("Add Book", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Picker("Filter", selection: $filter) {
                        ForEach(BookFilter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
            }
            .sheet(isPresented: $isPresentingAddBook) {
                BookFormView()
            }
            .overlay {
                if visibleBooks.isEmpty {
                    ContentUnavailableView {
                        Label(
                            filter == .favorites ? "No Favorites" : "No Books Yet",
                            systemImage: filter == .favorites ? "star" : "book.closed"
                        )
                    } description: {
                        Text(filter == .favorites
                             ? "Star a book to see it here."
                             : "Add a book to start tracking your reading progress.")
                    } actions: {
                        if filter == .all && searchText.isEmpty {
                            Button("Add Your First Book") {
                                isPresentingAddBook = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
    }
}
```

```swift
// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if book.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Text(book.percentText)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
            }

            ProgressView(value: book.progress)
                .tint(book.isFinished ? .green : .accentColor)

            HStack {
                Text("\(book.pagesRead) / \(book.totalPages) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if book.isFinished {
                    Label("Finished", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
```

```swift
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
```

```swift
// FILE: BookFormView.swift
import SwiftUI
import SwiftData

struct BookFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// When non-nil the form edits this book; otherwise it creates a new one.
    let book: Book?

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = 300
    @State private var pagesRead = 0
    @State private var isFavorite = false
    @State private var notes = ""

    init(book: Book? = nil) {
        self.book = book
    }

    private var isEditing: Bool { book != nil }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewProgress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(min(pagesRead, totalPages)) / Double(totalPages)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                    TextField("Author", text: $author)
                        .textContentType(.name)
                }

                Section("Reading progress") {
                    Stepper(value: $totalPages, in: 1...10_000, step: 10) {
                        Text("Total pages: \(totalPages)")
                    }
                    Stepper(value: $pagesRead, in: 0...max(1, totalPages)) {
                        Text("Pages read: \(pagesRead)")
                    }
                    .onChange(of: totalPages) { _, newValue in
                        pagesRead = min(pagesRead, max(1, newValue))
                    }

                    ProgressView(value: previewProgress)
                    Text("\(Int(previewProgress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Options") {
                    Toggle(isOn: $isFavorite) {
                        Label("Favorite", systemImage: "star.fill")
                    }
                    .tint(.yellow)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Book" : "New Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadExistingValues)
        }
    }

    private func loadExistingValues() {
        guard let book else { return }
        title = book.title
        author = book.author
        totalPages = book.totalPages
        pagesRead = book.pagesRead
        isFavorite = book.isFavorite
        notes = book.notes ?? ""
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTotal = max(1, totalPages)
        let safeRead = min(max(0, pagesRead), safeTotal)
        let finalAuthor = cleanAuthor.isEmpty ? "Unknown" : cleanAuthor
        let finalNotes = cleanNotes.isEmpty ? nil : cleanNotes

        if let book {
            book.title = cleanTitle
            book.author = finalAuthor
            book.totalPages = safeTotal
            book.pagesRead = safeRead
            book.isFavorite = isFavorite
            book.notes = finalNotes
        } else {
            modelContext.insert(Book(
                title: cleanTitle,
                author: finalAuthor,
                totalPages: safeTotal,
                pagesRead: safeRead,
                isFavorite: isFavorite,
                notes: finalNotes
            ))
        }
        dismiss()
    }
}
```

To use it, create a new iOS App project in Xcode with SwiftUI + SwiftData enabled, set the deployment target to iOS 26, and drop these files in. Features included: persistent storage via SwiftData, per-book progress bars and a detail progress ring with slider/±page steppers, an All/Favorites segmented filter, search, swipe-to-favorite/delete, and add/edit sheets with validation.