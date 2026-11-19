Complete source:

```swift
// FILE: BookTrackerApp.swift
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
    var currentPage: Int
    var isFavorite: Bool
    var dateAdded: Date
    var lastUpdated: Date

    init(
        title: String,
        author: String,
        totalPages: Int,
        currentPage: Int = 0,
        isFavorite: Bool = false
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(0, totalPages)
        self.currentPage = min(max(0, currentPage), max(0, totalPages))
        self.isFavorite = isFavorite
        self.dateAdded = Date()
        self.lastUpdated = Date()
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(1, max(0, Double(currentPage) / Double(totalPages)))
    }

    var isFinished: Bool {
        totalPages > 0 && currentPage >= totalPages
    }

    var percentText: String {
        "\(Int(progress * 100))%"
    }

    func setProgress(page: Int) {
        currentPage = min(max(0, page), max(0, totalPages))
        lastUpdated = Date()
    }
}
```

```swift
// FILE: CoverView.swift
import SwiftUI

struct CoverView: View {
    let title: String
    let author: String
    var size: CGFloat = 64

    private var initials: String {
        let words = title.split(separator: " ").map(String.init)
        let first = words.first?.first.map(String.init) ?? "?"
        let second = words.count > 1 ? String(words[1].first ?? " ") : ""
        return (first + second).uppercased()
    }

    private var hue: Double {
        let hash = title.utf8.reduce(0) { ($0 &+ Int($1)) % 360 }
        return Double(hash) / 360.0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hue: hue, saturation: 0.45, brightness: 0.85))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size * 1.4)
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.lastUpdated, order: .reverse) private var books: [Book]

    @State private var showFavoritesOnly = false
    @State private var searchText = ""
    @State private var isPresentingAddBook = false

    private var visibleBooks: [Book] {
        books.filter { book in
            let matchesFilter = !showFavoritesOnly || book.isFavorite
            let matchesSearch = searchText.isEmpty
                || book.title.localizedCaseInsensitiveContains(searchText)
                || book.author.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $showFavoritesOnly) {
                        Text("All").tag(false)
                        Text("Favorites").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    if visibleBooks.isEmpty {
                        ContentUnavailableView {
                            Label(
                                showFavoritesOnly ? "No favorite books" : "No books yet",
                                systemImage: showFavoritesOnly ? "star.slash" : "book.closed"
                            )
                        } description: {
                            Text(showFavoritesOnly
                                 ? "Tap the star on a book to add it to your favorites."
                                 : "Tap + to add your first book.")
                        }
                    } else {
                        ForEach(visibleBooks) { book in
                            NavigationLink(value: book) {
                                BookRowView(book: book)
                            }
                            .contextMenu {
                                Button {
                                    book.isFavorite.toggle()
                                    book.lastUpdated = Date()
                                } label: {
                                    Label(
                                        book.isFavorite ? "Remove from favorites" : "Add to favorites",
                                        systemImage: book.isFavorite ? "star.slash" : "star"
                                    )
                                }
                            }
                        }
                        .onDelete(perform: deleteBooks)
                    }
                }
            }
            .navigationTitle("My Library")
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddBook = true
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddBook) {
                AddBookView()
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
        }
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleBooks[index])
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
        HStack(spacing: 12) {
            CoverView(title: book.title, author: book.author, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    if book.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: book.progress)
                    .tint(book.isFinished ? .green : .accentColor)

                HStack {
                    Text(book.isFinished
                         ? "Finished"
                         : "\(book.currentPage) / \(book.totalPages) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(book.percentText)
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
    @State private var startPageText = "0"

    private var totalPages: Int {
        Int(totalPagesText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var startPage: Int {
        Int(startPageText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && totalPages > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                }

                Section("Pages") {
                    TextField("Total pages", text: $totalPagesText)
                        .keyboardType(.numberPad)
                    TextField("Start at page", text: $startPageText)
                        .keyboardType(.numberPad)
                }

                Section {
                    Button("Add to library") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("New book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespaces),
            author: author.trimmingCharacters(in: .whitespaces),
            totalPages: totalPages,
            currentPage: min(max(0, startPage), totalPages)
        )
        modelContext.insert(book)
        dismiss()
    }
}
```