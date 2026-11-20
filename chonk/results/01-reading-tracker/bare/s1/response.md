Here's a complete SwiftUI reading-tracker app for iOS 26, built entirely on Apple frameworks (SwiftData for persistence, SwiftUI for the UI). It tracks each book's reading progress, supports a favourites filter, search, swipe actions, and a detail editor.

```swift
// FILE: ReadingTrackerApp.swift
import SwiftUI
import SwiftData

@main
struct ReadingTrackerApp: App {
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

/// A single book being tracked, persisted with SwiftData.
@Model
final class Book {
    var title: String
    var author: String
    var totalPages: Int
    var pagesRead: Int
    var isFavorite: Bool
    var notes: String
    var dateAdded: Date

    init(
        title: String,
        author: String = "",
        totalPages: Int,
        pagesRead: Int = 0,
        isFavorite: Bool = false,
        notes: String = "",
        dateAdded: Date = .now
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(totalPages, 1)
        self.pagesRead = min(max(pagesRead, 0), max(totalPages, 1))
        self.isFavorite = isFavorite
        self.notes = notes
        self.dateAdded = dateAdded
    }

    /// Reading progress from 0.0 to 1.0.
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(Double(pagesRead) / Double(totalPages), 1.0)
    }

    /// True when every page has been read.
    var isFinished: Bool {
        totalPages > 0 && pagesRead >= totalPages
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI
import SwiftData

/// Filter for the book list: everything, or only favourites.
enum ReadingFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favourites = "Favourites"

    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var filter: ReadingFilter = .all
    @State private var searchText = ""
    @State private var showingAddBook = false

    private var visibleBooks: [Book] {
        books.filter { book in
            let matchesFilter = filter == .all || book.isFavorite
            let matchesSearch = searchText.isEmpty
                || book.title.localizedCaseInsensitiveContains(searchText)
                || book.author.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    private var averageProgress: Double {
        guard !visibleBooks.isEmpty else { return 0 }
        return visibleBooks.reduce(0.0) { $0 + $1.progress } / Double(visibleBooks.count)
    }

    private var summaryText: String {
        let count = visibleBooks.count
        let noun = count == 1 ? "book" : "books"
        return "\(count) \(noun) · \(Int(averageProgress * 100))% average progress"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(ReadingFilter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ForEach(visibleBooks) { book in
                        NavigationLink(value: book) {
                            BookRowView(book: book)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                book.pagesRead = min(book.pagesRead + 10, book.totalPages)
                            } label: {
                                Label("Read 10 pages", systemImage: "plus.circle.fill")
                            }
                            .tint(.green)

                            Button {
                                book.isFavorite.toggle()
                            } label: {
                                Label(
                                    book.isFavorite ? "Remove favourite" : "Favourite",
                                    systemImage: book.isFavorite ? "star.slash.fill" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(book)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                } header: {
                    if !visibleBooks.isEmpty {
                        Text(summaryText)
                    }
                }
            }
            .navigationTitle("My Books")
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Label("Add Book", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
            .overlay {
                if visibleBooks.isEmpty {
                    emptyState
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if filter == .favourites {
            ContentUnavailableView {
                Label("No Favourites", systemImage: "star.slash")
            } description: {
                Text("Tap the star on any book to add it to your favourites.")
            }
        } else {
            ContentUnavailableView {
                Label("No Books Yet", systemImage: "book.closed")
            } description: {
                Text("Tap the + button to start tracking your first book.")
            } actions: {
                Button("Add a Book") { showingAddBook = true }
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
        HStack(alignment: .center, spacing: 14) {
            BookCoverView(book: book)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    if book.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: book.progress)
                    .tint(book.isFinished ? .green : .blue)

                HStack {
                    Text(book.isFinished ? "Finished" : "\(book.pagesRead) of \(book.totalPages) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(book.progress, format: .percent)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
```

```swift
// FILE: BookCoverView.swift
import SwiftUI

/// A small generated "cover" showing the book's initials on a colour
/// derived from the title, so no image assets are needed.
struct BookCoverView: View {
    let book: Book

    private var initials: String {
        let words = book.title.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first.map(String.init) }
        let result = letters.joined().uppercased()
        return result.isEmpty ? "?" : result
    }

    private var hue: Double {
        let hash = book.title.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return Double(hash.magnitude % 360) / 360.0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.55, brightness: 0.80),
                            Color(hue: hue, saturation: 0.65, brightness: 0.50)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 54, height: 76)
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }
}
```

```swift
// FILE: BookDetailView.swift
import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    /// Two-way binding for the progress slider, clamped to 0...totalPages.
    private var pagesReadBinding: Binding<Double> {
        Binding(
            get: { Double(book.pagesRead) },
            set: { newValue in
                book.pagesRead = min(max(Int(newValue.rounded()), 0), book.totalPages)
            }
        )
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $book.title)
                TextField("Author", text: $book.author)
                Toggle(isOn: $book.isFavorite) {
                    Label("Favourite", systemImage: "star.fill")
                }
                .tint(.yellow)
                LabeledContent("Added") {
                    Text(book.dateAdded, style: .date)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Progress") {
                Stepper(value: $book.totalPages, in: 1...20000, step: 10) {
                    Text("Total pages: \(book.totalPages)")
                }
                Stepper(value: $book.pagesRead, in: 0...book.totalPages) {
                    Text("Pages read: \(book.pagesRead)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: pagesReadBinding, in: 0...Double(book.totalPages), step: 1)
                    HStack(spacing: 8) {
                        ProgressView(value: book.progress)
                            .tint(book.isFinished ? .green : .blue)
                        Text(book.progress, format: .percent)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                if book.isFinished {
                    Button("Reset progress") {
                        book.pagesRead = 0
                    }
                } else {
                    Button("Mark as finished") {
                        book.pagesRead = book.totalPages
                    }
                    .foregroundStyle(.green)
                }
            }

            Section("Notes") {
                TextField("Notes…", text: $book.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Book", systemImage: "trash")
                }
            }
        }
        .navigationTitle(book.title.isEmpty ? "Book Details" : book.title)
        .onChange(of: book.totalPages) { _, newValue in
            if book.pagesRead > newValue {
                book.pagesRead = newValue
            }
        }
        .confirmationDialog(
            "Delete “\(book.title)”? This cannot be undone.",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(book)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
```

```swift
// FILE: AddBookView.swift
import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = 320
    @State private var isFavorite = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Author", text: $author)
                        .textInputAutocapitalization(.words)
                    Stepper(value: $totalPages, in: 1...20000, step: 10) {
                        Text("Total pages: \(totalPages)")
                    }
                    Toggle(isOn: $isFavorite) {
                        Label("Favourite", systemImage: "star.fill")
                    }
                    .tint(.yellow)
                }
            }
            .navigationTitle("New Book")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addBook() }
                        .bold()
                        .disabled(!isValid)
                }
            }
        }
    }

    private func addBook() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: totalPages,
            isFavorite: isFavorite
        )
        modelContext.insert(book)
        dismiss()
    }
}
```

To use it, create a new iOS App project in Xcode targeting iOS 26 and drop these files in — SwiftData handles persistence automatically, so there's no setup code needed beyond the `@main` entry point.