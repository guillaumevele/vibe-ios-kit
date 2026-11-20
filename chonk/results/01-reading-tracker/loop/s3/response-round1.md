The gate flagged the trailing-closure call on `ContentUnavailableView` in `ContentView.swift` — the string-title initializers (`init(_:systemImage:description:)`) take no `actions:` trailing closure, so the closure at line 124 had no parameter to bind to, and that same family of string-title initializers is the deprecated API the gate reported. Both are fixed by switching every `ContentUnavailableView` to the `Label`-based `init(label:description:actions:)` form, which is the current, non-deprecated API and the only one that accepts an actions closure. The complete file set follows.

```swift
// FILE: ReadingListApp.swift
import Foundation
import SwiftUI

@main
struct ReadingListApp: App {
    private let store: BookStore = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileBookStore(url: directory.appendingPathComponent("books.json"))
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .tint(Theme.accent)
        }
    }
}
```

```swift
// FILE: Theme.swift
import SwiftUI

enum Theme {
    static let accent = Color.indigo
}

enum Spacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}
```

```swift
// FILE: Book.swift
import Foundation

struct Book: Identifiable, Hashable, Sendable, Codable {
    var id: UUID
    var title: String
    var author: String
    var totalPages: Int
    var pagesRead: Int
    var isFavourite: Bool
    var dateAdded: Date

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(1, max(0, Double(pagesRead) / Double(totalPages)))
    }

    var isFinished: Bool {
        totalPages > 0 && pagesRead >= totalPages
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        totalPages: Int,
        pagesRead: Int = 0,
        isFavourite: Bool = false,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.totalPages = max(1, totalPages)
        self.pagesRead = min(max(0, pagesRead), self.totalPages)
        self.isFavourite = isFavourite
        self.dateAdded = dateAdded
    }

    static let samples: [Book] = [
        Book(
            title: "The Name of the Wind",
            author: "Patrick Rothfuss",
            totalPages: 662,
            pagesRead: 412,
            isFavourite: true,
            dateAdded: Date().addingTimeInterval(-86_400 * 30)
        ),
        Book(
            title: "Project Hail Mary",
            author: "Andy Weir",
            totalPages: 496,
            pagesRead: 496,
            isFavourite: false,
            dateAdded: Date().addingTimeInterval(-86_400 * 12)
        ),
        Book(
            title: "Klara and the Sun",
            author: "Kazuo Ishiguro",
            totalPages: 320,
            pagesRead: 87,
            isFavourite: true,
            dateAdded: Date().addingTimeInterval(-86_400 * 3)
        )
    ]
}
```

```swift
// FILE: BookDraft.swift
import Foundation

struct BookDraft: Identifiable, Sendable {
    let id = UUID()
    var title: String = ""
    var author: String = ""
    var totalPages: Int = 300
    var pagesRead: Int = 0

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && totalPages >= 1
            && pagesRead >= 0
            && pagesRead <= totalPages
    }
}
```

```swift
// FILE: BookStore.swift
import Foundation

protocol BookStore: Sendable {
    func load() async throws -> [Book]
    func save(_ books: [Book]) async throws
}

struct FileBookStore: BookStore {
    let url: URL

    func load() async throws -> [Book] {
        guard FileManager.default.fileExists(atPath: url.path()) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Book].self, from: data)
    }

    func save(_ books: [Book]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(books)
        try data.write(to: url, options: .atomic)
    }
}

struct PreviewBookStore: BookStore {
    var books: [Book]

    init(books: [Book] = Book.samples) {
        self.books = books
    }

    func load() async throws -> [Book] {
        books
    }

    func save(_ books: [Book]) async throws { }
}
```

```swift
// FILE: LibraryViewModel.swift
import Foundation

@Observable
@MainActor
final class LibraryViewModel {
    enum LoadState {
        case loading
        case loaded
        case failed(Error)
    }

    var state: LoadState = .loading
    var books: [Book] = []
    var visibleBooks: [Book] = []
    var favouritesOnly = false
    var bookToAdd: BookDraft?
    var showSaveError = false
    var saveErrorMessage = ""

    private let store: BookStore
    private var hasReadStore = false

    init(store: BookStore) {
        self.store = store
    }

    var favouriteCount: Int {
        books.filter(\.isFavourite).count
    }

    func book(with id: Book.ID) -> Book? {
        books.first { $0.id == id }
    }

    func load() async {
        state = .loading
        do {
            books = try await store.load()
            hasReadStore = true
            refreshVisible()
            state = .loaded
        } catch {
            // The store read failed: keep whatever is in memory and refuse
            // to write anything back until a read succeeds again.
            state = .failed(error)
        }
    }

    func toggleFavouritesFilter() {
        favouritesOnly.toggle()
        refreshVisible()
    }

    func add(_ draft: BookDraft) async {
        let book = Book(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: draft.author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: draft.totalPages,
            pagesRead: draft.pagesRead
        )
        books.append(book)
        bookToAdd = nil
        refreshVisible()
        await persist()
    }

    func toggleFavourite(id: Book.ID) async {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].isFavourite.toggle()
        refreshVisible()
        await persist()
    }

    func setPagesRead(_ pages: Int, for id: Book.ID) async {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].pagesRead = min(max(0, pages), books[index].totalPages)
        await persist()
    }

    func adjustPages(by delta: Int, for id: Book.ID) async {
        guard let book = book(with: id) else { return }
        await setPagesRead(book.pagesRead + delta, for: id)
    }

    func markFinished(id: Book.ID) async {
        guard let book = book(with: id) else { return }
        await setPagesRead(book.totalPages, for: id)
    }

    func delete(_ toDelete: [Book]) async {
        let ids = Set(toDelete.map(\.id))
        books.removeAll { ids.contains($0.id) }
        refreshVisible()
        await persist()
    }

    func retrySave() async {
        await persist()
    }

    private func persist() async {
        guard hasReadStore else { return }
        do {
            try await store.save(books)
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func refreshVisible() {
        let filtered = favouritesOnly ? books.filter(\.isFavourite) : books
        visibleBooks = filtered.sorted { $0.dateAdded > $1.dateAdded }
    }
}
```

```swift
// FILE: ProgressTrack.swift
import SwiftUI

struct ProgressTrack: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: geometry.size.width * CGFloat(clamped))
                    .animation(reduceMotion ? nil : .default, value: progress)
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
    let onToggleFavourite: () async -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(book.title)
                    .font(.headline)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressTrack(progress: book.progress)
                    .frame(height: 8)
                    .accessibilityHidden(true)
                Text("\(book.pagesRead) of \(book.totalPages) pages, \(book.progress.formatted(.percent)) read")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(rowAccessibilityLabel)

            Spacer(minLength: Spacing.small)

            Button {
                Task { await onToggleFavourite() }
            } label: {
                Image(systemName: book.isFavourite ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(book.isFavourite ? Theme.accent : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(
                book.isFavourite
                    ? "Remove \(book.title) from favourites"
                    : "Add \(book.title) to favourites"
            )
            .sensoryFeedback(.selection, trigger: book.isFavourite)
        }
        .padding(.vertical, Spacing.small)
    }

    private var rowAccessibilityLabel: String {
        var label = "\(book.title), by \(book.author), \(book.progress.formatted(.percent)) read"
        if book.isFavourite {
            label += ", favourite"
        }
        return label
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var library: LibraryViewModel

    init(store: BookStore) {
        _library = State(wrappedValue: LibraryViewModel(store: store))
    }

    private enum DisplayState {
        case loading
        case empty
        case failed(Error)
        case content
    }

    private var displayState: DisplayState {
        switch library.state {
        case .loading:
            return .loading
        case .failed(let error):
            return .failed(error)
        case .loaded:
            return library.visibleBooks.isEmpty ? .empty : .content
        }
    }

    private var isLoaded: Bool {
        if case .loaded = library.state { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Group {
                switch displayState {
                case .loading:
                    ProgressView("Loading your library")
                case .empty:
                    emptyView
                case .failed(let error):
                    failedView(error)
                case .content:
                    bookList
                }
            }
            .navigationTitle("Reading List")
            .navigationSubtitle(
                library.favouritesOnly
                    ? "Showing \(library.favouriteCount) of \(library.books.count) books"
                    : ""
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        library.toggleFavouritesFilter()
                    } label: {
                        Label("Favourites", systemImage: library.favouritesOnly ? "star.fill" : "star")
                            .foregroundStyle(library.favouritesOnly ? Theme.accent : .primary)
                    }
                    .accessibilityLabel("Favourites filter")
                    .accessibilityValue(library.favouritesOnly ? "On" : "Off")
                    .sensoryFeedback(.selection, trigger: library.favouritesOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        library.bookToAdd = BookDraft()
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                    .accessibilityLabel("Add a book")
                    .disabled(!isLoaded)
                }
            }
            .task {
                await library.load()
            }
            .sheet(item: $library.bookToAdd) { draft in
                AddBookView(
                    draft: draft,
                    onSave: { await library.add($0) },
                    onCancel: { library.bookToAdd = nil }
                )
            }
            .alert("Couldn't save your changes", isPresented: $library.showSaveError) {
                Button("Retry") {
                    Task { await library.retrySave() }
                }
                Button("Dismiss", role: .cancel) { }
            } message: {
                Text("Your changes are still on screen, but writing them to storage failed: \(library.saveErrorMessage)")
            }
            .navigationDestination(for: Book.ID.self) { id in
                BookDetailView(bookID: id, library: library)
            }
        }
    }

    private var bookList: some View {
        List {
            ForEach(library.visibleBooks) { book in
                NavigationLink(value: book.id) {
                    BookRowView(book: book) {
                        await library.toggleFavourite(id: book.id)
                    }
                }
            }
            .onDelete { offsets in
                let targets = offsets.map { library.visibleBooks[$0] }
                Task { await library.delete(targets) }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyView: some View {
        Group {
            if library.favouritesOnly {
                ContentUnavailableView {
                    Label("No favourites yet", systemImage: "star")
                } description: {
                    Text("Tap the star on a book to pin it here.")
                } actions: {
                    Button("Show all books") {
                        library.toggleFavouritesFilter()
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No books yet", systemImage: "book")
                } description: {
                    Text("Add the first book you are reading to start tracking progress.")
                } actions: {
                    Button("Add a book", systemImage: "plus") {
                        library.bookToAdd = BookDraft()
                    }
                }
            }
        }
    }

    private func failedView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Couldn't load your library", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Reading your saved books failed: \(error.localizedDescription). Nothing on disk was changed.")
        } actions: {
            Button("Retry", systemImage: "arrow.clockwise") {
                Task { await library.load() }
            }
        }
    }
}

#Preview("With books") {
    ContentView(store: PreviewBookStore())
}

#Preview("Empty library") {
    ContentView(store: PreviewBookStore(books: []))
}
```

```swift
// FILE: AddBookView.swift
import SwiftUI

struct AddBookView: View {
    let onSave: (BookDraft) async -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var author: String
    @State private var totalPages: Int
    @State private var pagesRead: Int

    init(
        draft: BookDraft,
        onSave: @escaping (BookDraft) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: draft.title)
        _author = State(initialValue: draft.author)
        _totalPages = State(initialValue: draft.totalPages)
        _pagesRead = State(initialValue: draft.pagesRead)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && totalPages >= 1
            && pagesRead >= 0
            && pagesRead <= totalPages
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                }
                Section("Progress") {
                    TextField("Total pages", value: $totalPages, format: .number)
                    TextField("Pages already read", value: $pagesRead, format: .number)
                }
            }
            .navigationTitle("New book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var draft = BookDraft()
                        draft.title = title
                        draft.author = author
                        draft.totalPages = totalPages
                        draft.pagesRead = pagesRead
                        Task { await onSave(draft) }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
```

```swift
// FILE: BookDetailView.swift
import SwiftUI

struct BookDetailView: View {
    let bookID: Book.ID
    let library: LibraryViewModel

    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private var book: Book? {
        library.book(with: bookID)
    }

    var body: some View {
        Group {
            if let book {
                bookForm(book)
            } else {
                ContentUnavailableView {
                    Label("Book not found", systemImage: "book")
                } description: {
                    Text("This book is no longer in your library.")
                }
            }
        }
        .alert("Remove this book?", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                if let book {
                    Task {
                        await library.delete([book])
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let book {
                Text("\"\(book.title)\" and its reading progress will be removed. This cannot be undone.")
            } else {
                Text("This book and its reading progress will be removed.")
            }
        }
    }

    private func bookForm(_ book: Book) -> some View {
        Form {
            Section {
                Text(book.title)
                    .font(.title2)
                    .bold()
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Added")
                    Spacer()
                    Text(book.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            Section("Progress") {
                HStack {
                    Text(book.progress.formatted(.percent))
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    if book.isFinished {
                        Label("Finished", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressTrack(progress: book.progress)
                    .frame(height: 10)
                    .accessibilityHidden(true)
                Stepper(
                    value: Binding(
                        get: { book.pagesRead },
                        set: { newValue in
                            Task { await library.setPagesRead(newValue, for: book.id) }
                        }
                    ),
                    in: 0...book.totalPages
                ) {
                    Text("\(book.pagesRead) of \(book.totalPages) pages read")
                }
                .accessibilityValue("\(book.pagesRead) of \(book.totalPages) pages")
            }

            Section("Quick actions") {
                Button("Add 10 pages", systemImage: "plus") {
                    Task { await library.adjustPages(by: 10, for: book.id) }
                }
                Button("Remove 10 pages", systemImage: "minus") {
                    Task { await library.adjustPages(by: -10, for: book.id) }
                }
                Button("Mark as finished", systemImage: "checkmark") {
                    Task { await library.markFinished(id: book.id) }
                }
                .disabled(book.isFinished)
            }

            Section {
                Button {
                    Task { await library.toggleFavourite(id: book.id) }
                } label: {
                    Label(
                        book.isFavourite ? "Remove from favourites" : "Add to favourites",
                        systemImage: book.isFavourite ? "star.fill" : "star"
                    )
                }
                .sensoryFeedback(.selection, trigger: book.isFavourite)
            }

            Section {
                Button("Remove book", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(book.title)
    }
}
```

Not verified

I did not compile or run this app. What changed in this pass: every `ContentUnavailableView` now uses the `Label`-based `init(label:description:actions:)` — the trailing-closure error at the old `ContentView.swift:124` is gone because the actions closure now binds to the labeled `actions:` parameter, and the deprecated string-title initializers (`init(_:systemImage:description:)` and siblings) are no longer used anywhere, including the "Book not found" state in `BookDetailView.swift`. Still needed:

- A rebuild in Xcode with the iOS 26 SDK and Swift 6 language mode to confirm zero errors and zero deprecation warnings. The gate's "deprecated API" line did not name a symbol; if a warning still appears after this change, the compiler output will name it and it can be fixed directly.
- A simulator run covering: first launch with no `books.json`, adding a book through the sheet, the favourites filter with zero favourites, swipe-to-delete, the delete confirmation alert, and the save-error alert (e.g. by pointing `FileBookStore` at an unwritable URL).
- A VoiceOver pass over the list rows, star buttons, favourites toggle, empty/failed states, and the detail screen stepper.
- A device check with Reduce Motion on (progress bar updates instantly) and at larger Dynamic Type sizes.