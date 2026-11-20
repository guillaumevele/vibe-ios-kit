Here's a complete reading-tracker app built with SwiftUI + SwiftData (persistence included, no third-party code). It tracks per-book progress (pages + percentage ring), supports a favourites filter, search, sorting, swipe actions, and full add/edit/delete.

```swift
// FILE: ReadingTrackerApp.swift
import SwiftUI
import SwiftData

@main
struct ReadingTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Book.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
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
        totalPages: Int = 0,
        pagesRead: Int = 0,
        isFavorite: Bool = false,
        notes: String = ""
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(0, totalPages)
        self.pagesRead = max(0, pagesRead)
        self.isFavorite = isFavorite
        self.dateAdded = Date()
        self.notes = notes
    }

    /// Progress from 0.0 to 1.0. Returns 0 when no page count is set.
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(1, max(0, Double(pagesRead) / Double(totalPages)))
    }

    var isFinished: Bool {
        totalPages > 0 && pagesRead >= totalPages
    }

    var pagesRemaining: Int {
        max(0, totalPages - pagesRead)
    }
}
```

```swift
// FILE: ContentView.swift
import Foundation
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var showFavoritesOnly = false
    @State private var showAddBook = false
    @State private var searchText = ""
    @State private var sort: SortOption = .dateAdded

    enum SortOption: String, CaseIterable {
        case dateAdded = "Recently added"
        case title = "Title A–Z"
        case progress = "Progress"
    }

    private var visibleBooks: [Book] {
        let filtered = books.filter { book in
            (!showFavoritesOnly || book.isFavorite) &&
            (searchText.isEmpty ||
             book.title.localizedCaseInsensitiveContains(searchText) ||
             book.author.localizedCaseInsensitiveContains(searchText))
        }
        switch sort {
        case .dateAdded:
            return filtered.sorted { $0.dateAdded > $1.dateAdded }
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            return filtered.sorted { $0.progress > $1.progress }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !books.isEmpty {
                    Section {
                        StatsHeaderView(books: books)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    ForEach(visibleBooks) { book in
                        NavigationLink(value: book) {
                            BookRowView(book: book)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(book)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
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
                        .contextMenu {
                            Button {
                                book.isFavorite.toggle()
                            } label: {
                                Label(
                                    book.isFavorite ? "Remove from favourites" : "Add to favourites",
                                    systemImage: book.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                        }
                    }
                } header: {
                    if !visibleBooks.isEmpty {
                        HStack {
                            Text(showFavoritesOnly ? "Favourites" : "All books")
                            Spacer()
                            Text("\(visibleBooks.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reading Tracker")
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { showFavoritesOnly.toggle() }
                    } label: {
                        Label(
                            showFavoritesOnly ? "Show all" : "Favourites",
                            systemImage: showFavoritesOnly ? "star.fill" : "star"
                        )
                    }
                    .tint(showFavoritesOnly ? .yellow : .primary)
                    .accessibilityLabel(showFavoritesOnly
                                        ? "Showing favourites only, tap to show all books"
                                        : "Show favourites only")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Sort by") {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button {
                                    sort = option
                                } label: {
                                    if sort == option {
                                        Label(option.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        }
                        Button {
                            showAddBook = true
                        } label: {
                            Label("Add book", systemImage: "plus")
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBook = true
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                    .accessibilityLabel("Add book")
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
                    .presentationDetents([.medium, .large])
            }
            .overlay {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("No books yet", systemImage: "book.closed")
                    } description: {
                        Text("Tap + to add the first book you're reading.")
                    } actions: {
                        Button("Add book") { showAddBook = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if visibleBooks.isEmpty {
                    if showFavoritesOnly && searchText.isEmpty {
                        ContentUnavailableView {
                            Label("No favourites yet", systemImage: "star")
                        } description: {
                            Text("Tap the star on any book to add it to your favourites.")
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
    }
}
```

```swift
// FILE: StatsHeaderView.swift
import SwiftUI

struct StatsHeaderView: View {
    let books: [Book]

    private var finishedCount: Int {
        books.filter(\.isFinished).count
    }

    private var averageProgress: Double {
        guard !books.isEmpty else { return 0 }
        return books.reduce(0) { $0 + $1.progress } / Double(books.count)
    }

    var body: some View {
        HStack(spacing: 0) {
            stat(value: "\(books.count)", label: "Books")
            Divider()
            stat(value: "\(books.count - finishedCount)", label: "Reading")
            Divider()
            stat(value: "\(finishedCount)", label: "Finished")
            Divider()
            stat(value: "\(Int(averageProgress * 100))%", label: "Avg. progress")
        }
        .padding(.vertical, 8)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
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
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            ProgressRingView(progress: book.progress, isFinished: book.isFinished)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if book.totalPages > 0 {
                    ProgressView(value: book.progress)
                        .tint(book.isFinished ? .green : .accentColor)
                } else {
                    Text("No page count set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if book.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                Text("\(Int(book.progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if book.isFinished {
                    Text("Done")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

```swift
// FILE: ProgressRingView.swift
import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    var isFinished: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 5)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    isFinished ? .green : .accentColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            if isFinished {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 11, weight: .bold))
            }
        }
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
    @State private var totalPages = ""
    @State private var pagesRead = ""
    @State private var isFavorite = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Label("Favourite", systemImage: isFavorite ? "star.fill" : "star")
                    }
                    .tint(.yellow)
                }

                Section("Progress") {
                    TextField("Total pages", text: $totalPages)
                        .keyboardType(.numberPad)
                    TextField("Pages already read", text: $pagesRead)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let total = max(0, Int(totalPages) ?? 0)
        let read = min(max(0, Int(pagesRead) ?? 0), total > 0 ? total : max(0, Int(pagesRead) ?? 0))

        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: total,
            pagesRead: read,
            isFavorite: isFavorite
        )
        modelContext.insert(book)
        try? modelContext.save()
        dismiss()
    }
}
```

**How it fits together:**
- `ReadingTrackerApp` creates the SwiftData container, so all books persist between launches.
- `ContentView` is the library list: favourites filter (star button in the toolbar), search, sort menu, swipe-to-favourite/delete, and empty states.
- `BookRowView` + `ProgressRingView` show each book's progress as a ring and bar with a percentage.
- `BookDetailView` lets you edit pages read via steppers or a slider (auto-clamped), toggle favourite, add notes, mark finished, or delete.
- `AddBookView` is the sheet for adding a new book, with optional favourite flag and starting progress.
- `StatsHeaderView` summarizes totals, currently reading, finished, and average progress.