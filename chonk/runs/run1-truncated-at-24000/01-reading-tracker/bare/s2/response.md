Here's a complete SwiftUI + SwiftData reading tracker for iOS 26 — progress tracking per book, a favourites filter (segmented control + swipe-to-favourite), search, sorting, and a library summary. Save each file into your Xcode project:

```swift
// FILE: BookTrackerApp.swift
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

@Model
final class Book {
    var title: String
    var author: String
    var totalPages: Int
    var pagesRead: Int
    var isFavorite: Bool
    var dateAdded: Date
    var notes: String

    init(
        title: String,
        author: String,
        totalPages: Int,
        pagesRead: Int = 0,
        isFavorite: Bool = false,
        notes: String = ""
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(1, totalPages)
        self.pagesRead = min(max(0, pagesRead), self.totalPages)
        self.isFavorite = isFavorite
        self.dateAdded = Date()
        self.notes = notes
    }

    /// Progress as a value between 0 and 1.
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesRead) / Double(totalPages)
    }

    /// Progress as a whole-number percentage (0–100).
    var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    var status: BookStatus {
        if pagesRead <= 0 { return .notStarted }
        if pagesRead >= totalPages { return .finished }
        return .reading
    }
}
```

```swift
// FILE: BookStatus.swift
import SwiftUI

enum BookStatus: String, CaseIterable {
    case notStarted = "Not started"
    case reading = "Reading"
    case finished = "Finished"

    var icon: String {
        switch self {
        case .notStarted: "circle"
        case .reading: "book.fill"
        case .finished: "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: .secondary
        case .reading: .blue
        case .finished: .green
        }
    }
}
```

```swift
// FILE: ProgressBarView.swift
import SwiftUI

struct ProgressBarView: View {
    let progress: Double
    var height: CGFloat = 8
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)))
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: height)
    }
}
```

```swift
// FILE: BookCoverView.swift
import SwiftUI

/// A small generated "cover" with the book's initials on a deterministic gradient.
struct BookCoverView: View {
    let title: String
    let author: String

    private static let palette: [Color] = [
        .blue, .indigo, .purple, .teal, .mint, .orange, .pink, .red, .brown, .cyan
    ]

    private var initials: String {
        let words = title.split(separator: " ").filter { !$0.isEmpty }
        let letters = words.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    private var baseColor: Color {
        let hash = title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Self.palette[abs(hash) % Self.palette.count]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [baseColor, baseColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 66)
        .shadow(radius: 2, y: 1)
    }
}
```

```swift
// FILE: LibrarySummaryView.swift
import SwiftUI

struct LibrarySummaryView: View {
    let books: [Book]

    private var readingCount: Int {
        books.filter { $0.status == .reading }.count
    }

    private var finishedCount: Int {
        books.filter { $0.status == .finished }.count
    }

    private var averageProgress: Int {
        guard !books.isEmpty else { return 0 }
        let total = books.reduce(0.0) { $0 + $1.progress }
        return Int((total / Double(books.count) * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 0) {
            stat(value: "\(books.count)", label: "Books")
            stat(value: "\(readingCount)", label: "Reading")
            stat(value: "\(finishedCount)", label: "Finished")
            stat(value: "\(averageProgress)%", label: "Avg. progress")
        }
        .padding(.vertical, 4)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

```swift
// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    @Bindable var book: Book

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(title: book.title, author: book.author)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(book.title.isEmpty ? "Untitled" : book.title)
                        .font(.headline)
                        .lineLimit(1)
                    if book.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressBarView(progress: book.progress, color: book.status.color)

                HStack {
                    Label(book.status.rawValue, systemImage: book.status.icon)
                        .font(.caption2)
                        .foregroundStyle(book.status.color)
                    Spacer()
                    Text("\(book.pagesRead) / \(book.totalPages) · \(book.progressPercent)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI
import SwiftData

enum BookFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favourites = "Favourites"
    var id: String { rawValue }
}

enum BookSortOrder: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently added"
    case title = "Title A–Z"
    case progress = "Progress"
    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var searchText = ""
    @State private var filter: BookFilter = .all
    @State private var sortOrder: BookSortOrder = .recentlyAdded
    @State private var showingAddBook = false

    private var filteredBooks: [Book] {
        var result = books

        if filter == .favourites {
            result = result.filter { $0.isFavorite }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.author.localizedCaseInsensitiveContains(query)
            }
        }

        switch sortOrder {
        case .recentlyAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            result.sort { $0.progress > $1.progress }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("No books yet", systemImage: "books.vertical")
                    } description: {
                        Text("Tap the + button to add the first book you're reading.")
                    } actions: {
                        Button("Add a book") { showingAddBook = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 0) {
                        Picker("Filter", selection: $filter) {
                            ForEach(BookFilter.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        List {
                            Section("Overview") {
                                LibrarySummaryView(books: books)
                            }

                            Section(filter == .favourites ? "Favourites" : "Books") {
                                ForEach(filteredBooks) { book in
                                    NavigationLink {
                                        BookDetailView(book: book)
                                    } label: {
                                        BookRowView(book: book)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            withAnimation { book.isFavorite.toggle() }
                                        } label: {
                                            Label(
                                                book.isFavorite ? "Unfavourite" : "Favourite",
                                                systemImage: book.isFavorite ? "star.slash.fill" : "star.fill"
                                            )
                                        }
                                        .tint(.yellow)
                                    }
                                }
                                .onDelete(perform: deleteBooks)
                            }
                        }
                        .overlay {
                            if filteredBooks.isEmpty {
                                ContentUnavailableView {
                                    Label(
                                        filter == .favourites ? "No favourites yet" : "No results",
                                        systemImage: filter == .favourites ? "star" : "magnifyingglass"
                                    )
                                } description: {
                                    Text(filter == .favourites
                                         ? "Swipe right on a book, or tap the star, to mark it as a favourite."
                                         : "Try a different search or filter.")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reading Tracker")
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(BookSortOrder.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
        }
    }

    private func deleteBooks(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(filteredBooks[offset])
        }
        try? modelContext.save()
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
    @State private var totalPagesText = ""
    @State private var pagesReadText = ""
    @State private var isFavorite = false
    @State private var notes = ""

    private var totalPages: Int { Int(totalPagesText) ?? 0 }
    private var pagesRead: Int { min(Int(pagesReadText) ?? 0, max(totalPages, 0)) }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && totalPages > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Author", text: $author)
                        .textInputAutocapitalization(.words)
                    Toggle(isOn: $isFavorite) {
                        Label("Favourite", systemImage: "star.fill")
                            .foregroundStyle(isFavorite ? .yellow : .primary)
                    }
                }

                Section("Progress") {
                    TextField("Total pages", text: $totalPagesText)
                        .keyboardType(.numberPad)
                    TextField("Pages already read", text: $pagesReadText)
                        .keyboardType(.numberPad)
                    if totalPages > 0 {
                        ProgressBarView(progress: Double(pagesRead) / Double(totalPages))
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("Add book")
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
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        let book = Book(
            title: cleanTitle,
            author: cleanAuthor.isEmpty ? "Unknown author" : cleanAuthor,
            totalPages: totalPages,
            pagesRead: pagesRead,
            isFavorite: isFavorite,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(book)
        try? modelContext.save()
        dismiss()
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
```

**What you get:**
- **Progress tracking** — each book stores pages read / total pages; the list rows, summary, and detail screen all derive a live percentage and status (Not started / Reading / Finished). In the detail view you can scrub a slider, use a stepper, reset, or mark a book finished.
- **Favourites filter** — a segmented All / Favourites control at the top, plus swipe-right on any row (or the star toggle in the detail view) to favourite a book.
- **Extras** — search by title/author, sort by recently added / title / progress, a library overview (counts + average progress), swipe-to-delete, generated cover thumbnails, and an iOS 26 Liquid Glass prominent + button.
- **Persistence** — SwiftData (`@Model` + `.modelContainer`), so everything is stored on-device automatically; no third-party code anywhere.