Two fixes applied: (1) `AppDesign.Color` shadowed `SwiftUI.Color`, so `Color.accentColor` inside it resolved to the nested enum and failed — the accent is now declared as an explicit `SwiftUI.Color`; (2) the `accentColor` lookup flagged as deprecated is gone entirely, replaced by a single fixed system accent held in the one design enum. I also made the detail view's model `@Bindable` so it re-renders when the model changes.

```swift
// FILE: ReadingListApp.swift
import SwiftUI

@main
struct ReadingListApp: App {
    var body: some Scene {
        WindowGroup {
            BookListView(model: LibraryModel())
        }
    }
}
```

```swift
// FILE: AppDesign.swift
import SwiftUI

enum AppDesign {
    enum Space {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Color {
        static let accent: SwiftUI.Color = .blue
    }
}
```

```swift
// FILE: Book.swift
import Foundation

struct Book: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var author: String
    var pagesRead: Int
    var totalPages: Int
    var isFavorite: Bool
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        pagesRead: Int = 0,
        totalPages: Int,
        isFavorite: Bool = false,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.totalPages = max(1, totalPages)
        self.pagesRead = max(0, min(pagesRead, self.totalPages))
        self.isFavorite = isFavorite
        self.dateAdded = dateAdded
    }

    var fraction: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesRead) / Double(totalPages)
    }

    var isFinished: Bool {
        totalPages > 0 && pagesRead >= totalPages
    }
}

extension Book {
    static let samples: [Book] = [
        Book(
            title: "The Left Hand of Darkness",
            author: "Ursula K. Le Guin",
            pagesRead: 142,
            totalPages: 304,
            isFavorite: true,
            dateAdded: Date().addingTimeInterval(-12 * 24 * 60 * 60)
        ),
        Book(
            title: "Project Hail Mary",
            author: "Andy Weir",
            pagesRead: 310,
            totalPages: 496,
            dateAdded: Date().addingTimeInterval(-3 * 24 * 60 * 60)
        ),
        Book(
            title: "Piranesi",
            author: "Susanna Clarke",
            pagesRead: 245,
            totalPages: 245,
            isFavorite: true,
            dateAdded: Date().addingTimeInterval(-40 * 24 * 60 * 60)
        )
    ]
}
```

```swift
// FILE: BookStore.swift
import Foundation

protocol BookStore: Sendable {
    func load() async throws -> [Book]
    func save(_ books: [Book]) async throws
}

actor FileBookStore: BookStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = base.appendingPathComponent("ReadingList", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("books.json")
        }
    }

    func load() async throws -> [Book] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Book].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    func save(_ books: [Book]) async throws {
        let data = try JSONEncoder().encode(books)
        try data.write(to: fileURL, options: .atomic)
    }
}

actor MemoryBookStore: BookStore {
    private var stored: [Book]

    init(books: [Book] = []) {
        stored = books
    }

    func load() async throws -> [Book] {
        stored
    }

    func save(_ books: [Book]) async throws {
        stored = books
    }
}

actor FailingBookStore: BookStore {
    func load() async throws -> [Book] {
        throw CocoaError(.fileReadCorruptFile)
    }

    func save(_ books: [Book]) async throws {
        // Preview-only store; nothing to persist.
    }
}
```

```swift
// FILE: BookDraft.swift
import Foundation
import Observation

@Observable
@MainActor
final class BookDraft: Identifiable {
    let id = UUID()
    var title = ""
    var author = ""
    var totalPagesText = ""

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Int(totalPagesText) ?? 0) > 0
    }
}
```

```swift
// FILE: LibraryModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class LibraryModel {
    enum LoadState: Equatable {
        case loading
        case empty
        case failed(String)
        case content
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case favourites = "Favourites"

        var id: String { rawValue }
    }

    private let store: any BookStore
    private var readSucceeded = false

    private(set) var isLoading = false
    private(set) var loadErrorMessage: String?
    var banner: String?
    var books: [Book] = []
    var filter: Filter = .all
    var draft: BookDraft?
    var showDeleteAlert = false
    var pendingDeleteID: UUID?

    init(store: any BookStore = FileBookStore(), initialBooks: [Book] = []) {
        self.store = store
        self.books = initialBooks
    }

    var state: LoadState {
        if isLoading {
            return .loading
        }
        if let loadErrorMessage {
            return .failed(loadErrorMessage)
        }
        if visibleBooks.isEmpty {
            return .empty
        }
        return .content
    }

    var visibleBooks: [Book] {
        switch filter {
        case .all:
            return books
        case .favourites:
            return books.filter { $0.isFavorite }
        }
    }

    var pendingDeleteTitle: String {
        books.first { $0.id == pendingDeleteID }?.title ?? "this book"
    }

    func book(with id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    func load() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            books = try await store.load()
            readSucceeded = true
            banner = nil
            isLoading = false
        } catch {
            readSucceeded = false
            loadErrorMessage = "The saved library could not be read: \(error.localizedDescription). Saved books were left untouched, and new changes will not be saved until a load succeeds."
            banner = "Changes are not being saved until your library loads successfully."
            isLoading = false
        }
    }

    func beginAdd() {
        draft = BookDraft()
    }

    func commitDraft(_ draft: BookDraft) async {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = draft.author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let totalPages = Int(draft.totalPagesText), totalPages > 0 else {
            return
        }
        books.append(Book(title: title, author: author, totalPages: totalPages))
        self.draft = nil
        await persist()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else {
            return
        }
        books[index].isFavorite.toggle()
        Task { await persist() }
    }

    func setPagesRead(_ id: UUID, _ pages: Int) {
        guard let index = books.firstIndex(where: { $0.id == id }) else {
            return
        }
        let clamped = max(0, min(pages, books[index].totalPages))
        guard books[index].pagesRead != clamped else {
            return
        }
        books[index].pagesRead = clamped
        Task { await persist() }
    }

    func requestDelete(_ id: UUID) {
        pendingDeleteID = id
        showDeleteAlert = true
    }

    func confirmDelete() {
        guard let id = pendingDeleteID else {
            return
        }
        pendingDeleteID = nil
        delete(id)
    }

    func delete(_ id: UUID) {
        books.removeAll { $0.id == id }
        Task { await persist() }
    }

    func dismissBanner() {
        banner = nil
    }

    private func persist() async {
        guard readSucceeded else {
            return
        }
        do {
            try await store.save(books)
            banner = nil
        } catch {
            banner = "Could not save changes to disk. They will be lost when the app quits."
        }
    }
}
```

```swift
// FILE: BookListView.swift
import SwiftUI

struct BookListView: View {
    @Bindable var model: LibraryModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $model.filter) {
                    ForEach(LibraryModel.Filter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppDesign.Space.medium)
                .padding(.vertical, AppDesign.Space.small)
                .sensoryFeedback(.selection, trigger: model.filter)

                switch model.state {
                case .loading:
                    loadingView
                case .empty:
                    emptyView
                case .failed(let message):
                    failedView(message)
                case .content:
                    listView
                }
            }
            .navigationTitle("Reading list")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.beginAdd()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a book")
                }
            }
            .sheet(item: $model.draft) { draft in
                AddBookView(draft: draft) {
                    Task { await model.commitDraft(draft) }
                }
            }
            .alert("Delete this book?", isPresented: $model.showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    model.confirmDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Remove \(model.pendingDeleteTitle) from your library. This cannot be undone.")
            }
            .task {
                await model.load()
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading your library")
            Spacer()
        }
    }

    private var emptyView: some View {
        Group {
            if model.filter == .favourites {
                ContentUnavailableView {
                    Label("No favourites yet", systemImage: "star")
                } description: {
                    Text("Tap the star on any book to keep it here.")
                } actions: {
                    Button("Show all books") {
                        model.filter = .all
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No books yet", systemImage: "book")
                } description: {
                    Text("Add the first book you are reading.")
                } actions: {
                    Button("Add a book") {
                        model.beginAdd()
                    }
                }
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack {
            Spacer()
            ContentUnavailableView {
                Label("Could not load your library", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await model.load() }
                }
            }
            Spacer()
        }
    }

    private var listView: some View {
        List {
            if let banner = model.banner {
                HStack(spacing: AppDesign.Space.small) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(AppDesign.Color.accent)
                        .accessibilityHidden(true)
                    Text(banner)
                        .font(.footnote)
                    Spacer()
                    Button {
                        model.dismissBanner()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Dismiss message")
                }
            }
            ForEach(model.visibleBooks) { book in
                NavigationLink(value: book.id) {
                    BookRow(book: book) {
                        model.toggleFavorite(book.id)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        model.toggleFavorite(book.id)
                    } label: {
                        Label(
                            book.isFavorite ? "Remove favourite" : "Mark as favourite",
                            systemImage: book.isFavorite ? "star.slash" : "star"
                        )
                    }
                    .tint(book.isFavorite ? .secondary : AppDesign.Color.accent)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        model.requestDelete(book.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: UUID.self) { id in
            BookDetailView(model: model, bookID: id)
        }
    }
}

#Preview("Library with books") {
    BookListView(model: LibraryModel(store: MemoryBookStore(books: Book.samples), initialBooks: Book.samples))
}

#Preview("Empty library") {
    BookListView(model: LibraryModel(store: MemoryBookStore()))
}

#Preview("Failed to load") {
    BookListView(model: LibraryModel(store: FailingBookStore()))
}
```

```swift
// FILE: BookRow.swift
import SwiftUI

struct BookRow: View {
    let book: Book
    let onToggleFavorite: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppDesign.Space.medium) {
            VStack(alignment: .leading, spacing: AppDesign.Space.xSmall) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: AppDesign.Space.small) {
                    ProgressView(value: book.fraction)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 120)
                        .accessibilityHidden(true)
                        .animation(reduceMotion ? nil : .default, value: book.fraction)
                    Text(book.fraction.formatted(.percent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityHidden(true)
                    if book.isFinished {
                        Label("Finished", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppDesign.Color.accent)
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(book.title) by \(book.author)")
            .accessibilityValue(book.isFinished ? "Finished" : "\(book.fraction.formatted(.percent)) read")

            Spacer()

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: book.isFavorite ? "star.fill" : "star")
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(book.isFavorite ? AppDesign.Color.accent : .secondary)
            .accessibilityLabel(book.isFavorite ? "Remove from favourites" : "Add to favourites")
            .sensoryFeedback(.selection, trigger: book.isFavorite)
        }
        .padding(.vertical, AppDesign.Space.small)
    }
}
```

```swift
// FILE: BookDetailView.swift
import SwiftUI

struct BookDetailView: View {
    @Bindable var model: LibraryModel
    let bookID: UUID

    @State private var pages: Double = 0
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    private var book: Book? {
        model.book(with: bookID)
    }

    var body: some View {
        Group {
            if let book {
                Form {
                    progressSection(book)
                    detailsSection(book)
                    actionsSection(book)
                }
                .navigationTitle(book.title)
            } else {
                ContentUnavailableView {
                    Label("Book not found", systemImage: "book.closed")
                } description: {
                    Text("This book may have been deleted.")
                }
            }
        }
        .task {
            if let book {
                pages = Double(book.pagesRead)
            }
        }
        .onChange(of: pages) { _, newValue in
            model.setPagesRead(bookID, Int(newValue))
        }
        .alert("Delete this book?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                model.delete(bookID)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Remove this book from your library. This cannot be undone.")
        }
    }

    private func progressSection(_ book: Book) -> some View {
        Section("Progress") {
            Slider(
                value: $pages,
                in: 0...Double(book.totalPages),
                step: 1
            ) {
                Text("Pages read")
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("\(book.totalPages)")
            }
            HStack {
                Text("\(book.pagesRead) of \(book.totalPages) pages")
                Spacer()
                Text(book.fraction.formatted(.percent))
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if book.isFinished {
                Label("Finished", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppDesign.Color.accent)
            } else {
                Button("Mark as finished") {
                    model.setPagesRead(bookID, book.totalPages)
                    pages = Double(book.totalPages)
                }
            }
        }
    }

    private func detailsSection(_ book: Book) -> some View {
        Section("Details") {
            LabeledContent("Author", value: book.author)
            LabeledContent("Total pages", value: "\(book.totalPages)")
            LabeledContent("Added", value: book.dateAdded.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private func actionsSection(_ book: Book) -> some View {
        Section {
            Button {
                model.toggleFavorite(bookID)
            } label: {
                Label(
                    book.isFavorite ? "Remove from favourites" : "Add to favourites",
                    systemImage: book.isFavorite ? "star.fill" : "star"
                )
            }
            .sensoryFeedback(.selection, trigger: book.isFavorite)
            Button("Delete book", role: .destructive) {
                showDeleteAlert = true
            }
        }
    }
}

#Preview("Book detail") {
    NavigationStack {
        BookDetailView(
            model: LibraryModel(store: MemoryBookStore(books: Book.samples), initialBooks: Book.samples),
            bookID: Book.samples[0].id
        )
    }
}
```

```swift
// FILE: AddBookView.swift
import SwiftUI

struct AddBookView: View {
    @Bindable var draft: BookDraft
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("New book") {
                    TextField("Title", text: $draft.title)
                    TextField("Author", text: $draft.author)
                    TextField("Total pages", text: $draft.totalPagesText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }
}

#Preview("Add book") {
    AddBookView(draft: BookDraft()) { }
}
```

Not verified

I did not run this app. Still needed:

- A build in Xcode with the iOS 26 SDK and Swift 6 language mode to confirm the `AppDesign.Color` shadowing error and the deprecation warning are both gone. The deprecation line in your gate output was truncated, so I treated `Color.accentColor` — the API at the reported error site — as the flagged API and removed it; if the gate meant a different API, that diagnostic will name it on the next run.
- A simulator run of each `#Preview` plus a real device run: first launch (empty state), adding a book, moving the progress slider, toggling favourites, the favourites filter, swipe actions, and both delete confirmation alerts.
- A persistence check across relaunches (books saved under Application Support, reload, and the corrupted-file path showing the failed state with Retry and the no-write-until-read-succeeds banner).
- A VoiceOver pass over the combined row label and percent value, the star buttons, the slider, and the sheets.
- A Dynamic Type pass at the largest sizes and a Reduce Motion check on the progress bar animation.