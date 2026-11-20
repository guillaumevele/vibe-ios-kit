Here is the complete app — eight source files, SwiftUI only, Apple frameworks only, Swift 6 / iOS 26.

```swift
// FILE: ReadingListApp.swift
import Foundation
import SwiftUI

@main
struct ReadingListApp: App {
    @State private var store: BookStore

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = directory.appendingPathComponent("books.json")
        _store = State(initialValue: BookStore(repository: FileBookRepository(fileURL: fileURL)))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .tint(Theme.accent)
        }
    }
}
```

```swift
// FILE: Design.swift
import SwiftUI

enum Theme {
    static let accent = Color.blue
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

struct Book: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var title: String
    var author: String
    var totalPages: Int
    var pagesRead: Int
    var isFavourite: Bool
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        totalPages: Int,
        pagesRead: Int,
        isFavourite: Bool = false,
        lastUpdated: Date = .now
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.totalPages = max(1, totalPages)
        self.pagesRead = min(max(0, pagesRead), self.totalPages)
        self.isFavourite = isFavourite
        self.lastUpdated = lastUpdated
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(1, max(0, Double(pagesRead) / Double(totalPages)))
    }

    var percentRead: Int {
        Int((progress * 100).rounded())
    }
}

extension Book {
    static let samples: [Book] = [
        Book(
            title: "The Name of the Wind",
            author: "Patrick Rothfuss",
            totalPages: 662,
            pagesRead: 412,
            isFavourite: true,
            lastUpdated: .now.addingTimeInterval(-3600)
        ),
        Book(
            title: "Project Hail Mary",
            author: "Andy Weir",
            totalPages: 496,
            pagesRead: 496,
            isFavourite: false,
            lastUpdated: .now.addingTimeInterval(-86400)
        ),
        Book(
            title: "Klara and the Sun",
            author: "Kazuo Ishiguro",
            totalPages: 320,
            pagesRead: 88,
            isFavourite: true,
            lastUpdated: .now.addingTimeInterval(-172800)
        )
    ]
}

struct BookDraft: Sendable, Equatable {
    var title: String = ""
    var author: String = ""
    var totalPages: Int = 320
    var pagesRead: Int = 0
    var isFavourite: Bool = false

    init() {}

    init(book: Book) {
        title = book.title
        author = book.author
        totalPages = book.totalPages
        pagesRead = book.pagesRead
        isFavourite = book.isFavourite
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && totalPages > 0
    }
}

enum BookFilter: String, CaseIterable, Sendable {
    case all = "All"
    case favourites = "Favourites"
}
```

```swift
// FILE: BookRepository.swift
import Foundation

protocol BookRepository: Sendable {
    func load() async throws -> [Book]
    func save(_ books: [Book]) async throws
}

struct FileBookRepository: BookRepository {
    let fileURL: URL

    func load() async throws -> [Book] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Book].self, from: data)
    }

    func save(_ books: [Book]) async throws {
        let data = try JSONEncoder().encode(books)
        try data.write(to: fileURL, options: .atomic)
    }
}

struct InMemoryBookRepository: BookRepository {
    var books: [Book]

    func load() async throws -> [Book] {
        books
    }

    func save(_ newBooks: [Book]) async throws {
        books = newBooks
    }
}
```

```swift
// FILE: BookStore.swift
import Foundation
import Observation

enum BookStoreError: LocalizedError, Sendable, Equatable {
    case storeUnavailable
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .storeUnavailable:
            "The library could not be loaded, so changes are paused to protect your saved books. Retry loading first."
        case .saveFailed(let detail):
            "The change could not be saved. \(detail)"
        }
    }
}

@MainActor
@Observable
final class BookStore {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    enum ViewState: Equatable {
        case loading
        case failed(String)
        case empty
        case content
    }

    var books: [Book] = []
    var phase: Phase = .loading
    var filter: BookFilter = .all
    var errorText: String?

    private let repository: BookRepository

    init(repository: BookRepository) {
        self.repository = repository
    }

    var state: ViewState {
        switch phase {
        case .loading:
            return .loading
        case .failed(let message):
            return .failed(message)
        case .loaded:
            return visibleBooks.isEmpty ? .empty : .content
        }
    }

    var visibleBooks: [Book] {
        let filtered = filter == .favourites ? books.filter(\.isFavourite) : books
        return filtered.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    var emptyShowsFavouritesHint: Bool {
        filter == .favourites && !books.isEmpty
    }

    func load() async {
        phase = .loading
        do {
            books = try await repository.load()
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func save(_ draft: BookDraft, editing existing: Book?) async throws {
        var updated = books
        let book = Book(
            id: existing?.id ?? UUID(),
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: draft.author.trimmingCharacters(in: .whitespacesAndNewlines),
            totalPages: draft.totalPages,
            pagesRead: draft.pagesRead,
            isFavourite: draft.isFavourite,
            lastUpdated: .now
        )
        if let existing, let index = updated.firstIndex(where: { $0.id == existing.id }) {
            updated[index] = book
        } else {
            updated.append(book)
        }
        try await commit(updated)
    }

    func toggleFavourite(_ book: Book) async {
        var updated = books
        guard let index = updated.firstIndex(where: { $0.id == book.id }) else { return }
        updated[index].isFavourite.toggle()
        updated[index].lastUpdated = .now
        do {
            try await commit(updated)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func delete(_ book: Book) async {
        var updated = books
        updated.removeAll { $0.id == book.id }
        do {
            try await commit(updated)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func commit(_ updated: [Book]) async throws {
        guard case .loaded = phase else {
            throw BookStoreError.storeUnavailable
        }
        do {
            try await repository.save(updated)
        } catch {
            throw BookStoreError.saveFailed(error.localizedDescription)
        }
        books = updated
    }
}
```

```swift
// FILE: ContentView.swift
import Foundation
import SwiftUI

struct EditorItem: Identifiable {
    let id = UUID()
    let book: Book?
}

struct ContentView: View {
    @Bindable var store: BookStore

    @State private var editorItem: EditorItem?
    @State private var pendingDeletion: Book?
    @State private var showingDeleteAlert = false
    @State private var showingSaveError = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .loading:
                    loadingView
                case .failed(let message):
                    failedView(message)
                case .empty:
                    emptyView
                case .content:
                    listView
                }
            }
            .navigationTitle("Reading")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorItem = EditorItem(book: nil)
                    } label: {
                        Label("Add book", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorItem) { item in
                NavigationStack {
                    BookEditorView(store: store, existing: item.book)
                }
            }
            .alert("Delete this book?", isPresented: $showingDeleteAlert, presenting: pendingDeletion) { book in
                Button("Delete", role: .destructive) {
                    Task { await store.delete(book) }
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletion = nil
                }
            } message: { book in
                Text("This removes “\(book.title)” and its reading progress from this device.")
            }
            .alert("Couldn't save changes", isPresented: $showingSaveError, presenting: store.errorText) { _ in
                Button("OK", role: .cancel) {
                    store.errorText = nil
                }
            } message: { message in
                Text(message)
            }
            .onChange(of: store.errorText) { _, newValue in
                showingSaveError = newValue != nil
            }
        }
        .task {
            await store.load()
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.medium) {
            ProgressView()
                .controlSize(.large)
            Text("Loading your books…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load your books", systemImage: "exclamationmark.triangle")
        } description: {
            Text("\(message) Your saved books are safe, and changes are paused until loading succeeds.")
        } actions: {
            Button("Retry") {
                Task { await store.load() }
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            if store.emptyShowsFavouritesHint {
                Label("No favourites yet", systemImage: "star")
            } else {
                Label("No books yet", systemImage: "book")
            }
        } description: {
            if store.emptyShowsFavouritesHint {
                Text("Tap the star on a book to see it here.")
            } else {
                Text("Add the first book you are reading to start tracking your progress.")
            }
        } actions: {
            if store.emptyShowsFavouritesHint {
                Button("Show all books") {
                    store.filter = .all
                }
            } else {
                Button("Add a book") {
                    editorItem = EditorItem(book: nil)
                }
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            Picker("Filter books", selection: $store.filter) {
                ForEach(BookFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .sensoryFeedback(.selection, trigger: store.filter)

            List {
                ForEach(store.visibleBooks) { book in
                    BookRowView(
                        book: book,
                        onSelect: { editorItem = EditorItem(book: book) },
                        onToggleFavourite: { Task { await store.toggleFavourite(book) } }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            pendingDeletion = book
                            showingDeleteAlert = true
                        }
                        Button(
                            book.isFavourite ? "Remove favourite" : "Favourite",
                            systemImage: book.isFavourite ? "star.slash" : "star"
                        ) {
                            Task { await store.toggleFavourite(book) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(reduceMotion ? nil : .default, value: store.visibleBooks)
        }
    }
}

#Preview {
    ContentView(store: BookStore(repository: InMemoryBookRepository(books: Book.samples)))
}
```

```swift
// FILE: BookRowView.swift
import SwiftUI

struct BookRowView: View {
    let book: Book
    let onSelect: () -> Void
    let onToggleFavourite: () -> Void

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text(book.title)
                        .font(.headline)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                        .tint(Theme.accent)
                        .accessibilityLabel("Progress")
                        .accessibilityValue(Text("\(book.percentRead) percent read"))
                    HStack {
                        Text("\(book.pagesRead) of \(book.totalPages) pages")
                        Spacer()
                        Text(book.lastUpdated.formatted(.relative(presentation: .named)))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)

            Button(action: onToggleFavourite) {
                Image(systemName: book.isFavourite ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(book.isFavourite ? Theme.accent : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(book.isFavourite ? "Remove from favourites" : "Add to favourites")
        }
        .padding(.vertical, Spacing.small)
    }
}
```

```swift
// FILE: BookEditorView.swift
import SwiftUI

struct BookEditorView: View {
    let store: BookStore
    let existing: Book?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: BookDraft
    @State private var showingError = false
    @State private var errorMessage = ""

    init(store: BookStore, existing: Book?) {
        self.store = store
        self.existing = existing
        _draft = State(initialValue: existing.map { BookDraft(book: $0) } ?? BookDraft())
    }

    private var pagesReadBinding: Binding<Double> {
        Binding(
            get: { Double(draft.pagesRead) },
            set: { draft.pagesRead = min(draft.totalPages, max(0, Int($0.rounded()))) }
        )
    }

    private var percentRead: Int {
        guard draft.totalPages > 0 else { return 0 }
        return Int((Double(draft.pagesRead) / Double(draft.totalPages) * 100).rounded())
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $draft.title)
                TextField("Author", text: $draft.author)
            }

            Section("Progress") {
                Stepper(value: $draft.totalPages, in: 1...9999) {
                    Text("Total pages: \(draft.totalPages)")
                }
                .onChange(of: draft.totalPages) { _, newValue in
                    if draft.pagesRead > newValue {
                        draft.pagesRead = newValue
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Slider(value: pagesReadBinding, in: 0...Double(draft.totalPages), step: 1) {
                        Text("Pages read")
                    }
                    HStack {
                        Text("Pages read: \(draft.pagesRead)")
                        Spacer()
                        Text("\(percentRead)%")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if draft.pagesRead >= draft.totalPages {
                    Label("All pages read", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
            }

            Section {
                Toggle("Favourite", isOn: $draft.isFavourite)
            }
        }
        .navigationTitle(existing == nil ? "New book" : "Edit book")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(!draft.isValid)
            }
        }
        .alert("Couldn't save the book", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {
                errorMessage = ""
            }
        } message: { message in
            Text(message)
        }
    }

    private func save() async {
        do {
            try await store.save(draft, editing: existing)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    NavigationStack {
        BookEditorView(
            store: BookStore(repository: InMemoryBookRepository(books: Book.samples)),
            existing: Book.samples[0]
        )
    }
}
```

Not verified

I did not run this app. Still needed before shipping:

- A full build in Xcode with Swift 6 language mode to confirm strict-concurrency checking passes (especially `@MainActor @Observable` on `BookStore`, the `Sendable` repository protocol, and the `App` initializer).
- A simulator run of each of the four list states: loading, empty (both variants — no books, and favourites filter with no favourites), failed (force a corrupt `books.json` in Documents), and content.
- A device run to verify JSON persistence across relaunches, and that a failed load (e.g. unreadable file) blocks writes and shows the Retry path.
- A VoiceOver pass over the list rows (combined row element, star toggle labels, progress value in words), the filter picker, and the editor sheet.
- A Dynamic Type pass at the largest accessibility sizes to confirm the row layout and editor form still fit.
- A Reduce Motion check on the list insert/remove animation.