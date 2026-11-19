Here's a complete, self-contained reading tracker for iOS 26 in SwiftUI (Apple frameworks only: SwiftUI, Observation, Foundation, Charts). It features add/edit books, per-book page progress with quick-log buttons, reading status, a favourites filter (plus swipe-to-favourite), search, reading history, a stats tab with a chart, and JSON persistence in the app's Documents directory. Create a new SwiftUI app in Xcode, set the deployment target to iOS 26, and drop these files in:

```swift
// FILE: BookTrackerApp.swift
import SwiftUI

@main
struct BookTrackerApp: App {
    @State private var store = BookStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
```

```swift
// FILE: ReadingStatus.swift
import Foundation
import SwiftUI

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case wantToRead = "Want to Read"
    case reading = "Reading"
    case finished = "Finished"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .wantToRead: "bookmark"
        case .reading: "book.open"
        case .finished: "checkmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .wantToRead: .orange
        case .reading: .blue
        case .finished: .green
        }
    }
}
```

```swift
// FILE: ReadingEntry.swift
import Foundation

struct ReadingEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var pages: Int
}
```

```swift
// FILE: Book.swift
import Foundation
import SwiftUI

struct Book: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var author: String
    var totalPages: Int
    var pagesRead: Int
    var status: ReadingStatus = .wantToRead
    var isFavourite: Bool = false
    var coverHue: Double = 0.58
    var notes: String = ""
    var dateAdded: Date = Date()
    var dateFinished: Date?
    var history: [ReadingEntry] = []

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(Double(pagesRead) / Double(totalPages), 1)
    }

    var coverColor: Color {
        Color(hue: coverHue, saturation: 0.55, brightness: 0.9)
    }

    var initials: String {
        let words = title.split(separator: " ").map(String.init)
        let letters = words.prefix(2).compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }
}
```

```swift
// FILE: LibraryFilter.swift
import Foundation

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favourites = "Favourites"
    case reading = "Reading"
    case wantToRead = "Want to Read"
    case finished = "Finished"

    var id: String { rawValue }

    var predicate: (Book) -> Bool {
        switch self {
        case .all:        { _ in true }
        case .favourites: { $0.isFavourite }
        case .reading:    { $0.status == .reading }
        case .wantToRead: { $0.status == .wantToRead }
        case .finished:   { $0.status == .finished }
        }
    }
}
```

```swift
// FILE: BookStore.swift
import Foundation

@Observable
final class BookStore {
    var books: [Book] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("books.json")
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        books = (try? decoder.decode([Book].self, from: data)) ?? []
    }

    private func save() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(books) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Lookup

    func book(with id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    func visibleBooks(filter: LibraryFilter, searchText: String) -> [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return books
            .filter(filter.predicate)
            .filter {
                query.isEmpty
                || $0.title.lowercased().contains(query)
                || $0.author.lowercased().contains(query)
            }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    // MARK: - Mutations

    func add(_ book: Book) {
        books.append(book)
        save()
    }

    func update(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index] = book
        save()
    }

    func delete(_ id: UUID) {
        books.removeAll { $0.id == id }
        save()
    }

    func delete(at offsets: IndexSet, from list: [Book]) {
        let ids = offsets.map { list[$0].id }
        books.removeAll { ids.contains($0.id) }
        save()
    }

    func toggleFavourite(_ id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].isFavourite.toggle()
        save()
    }

    func setStatus(_ status: ReadingStatus, for id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].status = status
        if status == .finished {
            books[index].dateFinished = Date()
            if books[index].totalPages > 0 {
                books[index].pagesRead = books[index].totalPages
            }
        }
        save()
    }

    func setPagesRead(_ pages: Int, for id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        let clamped = max(0, min(pages, books[index].totalPages))
        books[index].pagesRead = clamped
        if books[index].totalPages > 0 && clamped >= books[index].totalPages {
            books[index].status = .finished
            books[index].dateFinished = Date()
        } else if clamped > 0 && books[index].status == .wantToRead {
            books[index].status = .reading
        }
        save()
    }

    func addPages(_ pages: Int, to id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }), pages > 0 else { return }
        var book = books[index]
        var newValue = book.pagesRead + pages
        if book.totalPages > 0 {
            newValue = min(newValue, book.totalPages)
        }
        let delta = newValue - book.pagesRead
        guard delta > 0 else { return }
        book.pagesRead = newValue
        book.history.append(ReadingEntry(date: Date(), pages: delta))
        if book.totalPages > 0 && newValue >= book.totalPages {
            book.status = .finished
            book.dateFinished = Date()
        } else if book.status == .wantToRead {
            book.status = .reading
        }
        books[index] = book
        save()
    }

    func setNotes(_ notes: String, for id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].notes = notes
        save()
    }

    // MARK: - Stats

    var totalPagesRead: Int {
        books.reduce(0) { $0 + $1.pagesRead }
    }

    var pagesReadThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return books
            .flatMap(\.history)
            .filter { $0.date >= weekAgo }
            .reduce(0) { $0 + $1.pages }
    }

    var finishedCount: Int  { books.filter { $0.status == .finished }.count }
    var readingCount: Int   { books.filter { $0.status == .reading }.count }
    var favouriteCount: Int { books.filter(\.isFavourite).count }
}
```

```swift
// FILE: Formatters.swift
import Foundation

enum Formatters {
    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        return f
    }()

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    static func percentString(_ value: Double) -> String {
        percentFormatter.string(from: NSNumber(value: value)) ?? "0%"
    }

    static func pagesString(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
```

```swift
// FILE: CoverView.swift
import SwiftUI

struct CoverView: View {
    let book: Book
    var width: CGFloat = 48

    private var height: CGFloat { width * 1.45 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.09, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [book.coverColor, book.coverColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: width * 0.06) {
                Text(book.initials)
                    .font(.system(size: width * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(book.title)
                    .font(.system(size: max(width * 0.085, 8), weight: .semibold))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, width * 0.08)
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.18), radius: width * 0.06, y: width * 0.03)
    }
}
```

```swift
// FILE: BookProgressBar.swift
import SwiftUI

struct BookProgressBar: View {
    let progress: Double
    var color: Color = .accentColor
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: max(geo.size.width * CGFloat(min(max(progress, 0), 1)), height))
            }
        }
        .frame(height: height)
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                BookListView()
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar")
            }
        }
    }
}
```

```swift
// FILE: BookListView.swift
import SwiftUI

struct BookListView: View {
    @Environment(BookStore.self) private var store

    @State private var filter: LibraryFilter = .all
    @State private var searchText = ""
    @State private var showingAddBook = false

    private var books: [Book] {
        store.visibleBooks(filter: filter, searchText: searchText)
    }

    var body: some View {
        List {
            if books.isEmpty {
                ContentUnavailableView {
                    Label("No books found", systemImage: "book.closed")
                } description: {
                    Text(searchText.isEmpty
                         ? "Add a book to start tracking your reading."
                         : "No books match your search.")
                } actions: {
                    if searchText.isEmpty {
                        Button("Add Book") { showingAddBook = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            ForEach(books) { book in
                NavigationLink(value: book.id) {
                    BookRowView(book: book)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        store.toggleFavourite(book.id)
                    } label: {
                        Label(
                            book.isFavourite ? "Unfavourite" : "Favourite",
                            systemImage: book.isFavourite ? "star.slash" : "star.fill"
                        )
                    }
                    .tint(book.isFavourite ? .gray : .yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.delete(book.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                store.delete(at: offsets, from: books)
            }
        }
        .navigationTitle("My Library")
        .searchable(text: $searchText, prompt: "Search title or author")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Filter", selection: $filter) {
                    ForEach(LibraryFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddBook = true
                } label: {
                    Label("Add Book", systemImage: "plus")
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            if store.book(with: id) != nil {
                BookDetailView(bookID: id)
            } else {
                ContentUnavailableView("Book not found", systemImage: "questionmark.book")
            }
        }
        .sheet(isPresented: $showingAddBook) {
            BookFormView(mode: .add)
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
            CoverView(book: book, width: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(book.author.isEmpty ? "Unknown author" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(book.status.rawValue, systemImage: book.status.systemImage)
                        .font(.caption2)
                        .foregroundStyle(book.status.tint)
                    if book.isFavourite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 8) {
                    BookProgressBar(progress: book.progress, color: book.coverColor)
                    Text(Formatters.percentString(book.progress))
                        .font(.caption2)
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
```

```swift
// FILE: BookDetailView.swift
import SwiftUI

struct BookDetailView: View {
    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bookID: UUID

    @State private var editingBook: Book?
    @State private var confirmingDelete = false

    private var book: Book? { store.book(with: bookID) }

    var body: some View {
        if let book {
            List {
                Section {
                    HStack(spacing: 16) {
                        CoverView(book: book, width: 104)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.title)
                                .font(.title3.bold())
                                .lineLimit(3)
                            Text(book.author.isEmpty ? "Unknown author" : book.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let finished = book.dateFinished {
                                Label("Finished \(Formatters.shortDate.string(from: finished))",
                                      systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            Label("Added \(Formatters.shortDate.string(from: book.dateAdded))",
                                  systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section("Status") {
                    Picker("Status", selection: statusBinding(book)) {
                        ForEach(ReadingStatus.allCases) { s in
                            Label(s.rawValue, systemImage: s.systemImage).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: favouriteBinding(book)) {
                        Label("Favourite", systemImage: "star.fill")
                    }
                    .tint(.yellow)
                }

                Section("Progress") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("\(Formatters.pagesString(book.pagesRead)) of \(book.totalPages > 0 ? Formatters.pagesString(book.totalPages) : "unknown") pages")
                                .font(.subheadline)
                            Spacer()
                            Text(Formatters.percentString(book.progress))
                                .font(.subheadline.bold())
                                .foregroundStyle(book.coverColor)
                        }
                        BookProgressBar(progress: book.progress, color: book.coverColor, height: 10)

                        if book.totalPages > 0 {
                            Slider(value: pagesDoubleBinding(book), in: 0...Double(book.totalPages), step: 1) {
                                Text("Pages read")
                            }
                        } else {
                            Stepper("Pages read: \(book.pagesRead)", value: pagesBinding(book), in: 0...100_000)
                        }

                        HStack(spacing: 8) {
                            ForEach([1, 10, 25, 50], id: \.self) { amount in
                                Button("+\(amount)") {
                                    store.addPages(amount, to: book.id)
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                            Spacer()
                            Button("Finish") {
                                store.setStatus(.finished, for: book.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.caption)
                            .disabled(book.status == .finished)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: notesBinding(book))
                        .frame(minHeight: 110)
                }

                if !book.history.isEmpty {
                    Section("Reading history") {
                        ForEach(book.history.sorted { $0.date > $1.date }.prefix(10)) { entry in
                            HStack {
                                Text(Formatters.shortDate.string(from: entry.date))
                                Spacer()
                                Text("+\(entry.pages) pages")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete Book", systemImage: "trash")
                    }
                    .confirmationDialog(
                        "Delete “\(book.title)”?",
                        isPresented: $confirmingDelete,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            store.delete(book.id)
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.toggleFavourite(book.id)
                    } label: {
                        Image(systemName: book.isFavourite ? "star.fill" : "star")
                    }
                    .foregroundStyle(book.isFavourite ? .yellow : .primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingBook = book
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $editingBook) { book in
                BookFormView(mode: .edit(book))
            }
        } else {
            ContentUnavailableView("Book not found", systemImage: "questionmark.book")
        }
    }

    private func statusBinding(_ book: Book) -> Binding<ReadingStatus> {
        Binding(
            get: { store.book(with: book.id)?.status ?? book.status },
            set: { store.setStatus($0, for: book.id) }
        )
    }

    private func favouriteBinding(_ book: Book) -> Binding<Bool> {
        Binding(
            get: { store.book(with: book.id)?.isFavourite ?? false },
            set: { newValue in
                if (store.book(with: book.id)?.isFavourite ?? false) != newValue {
                    store.toggleFavourite(book.id)
                }
            }
        )
    }

    private func pagesBinding(_ book: Book) -> Binding<Int> {
        Binding(
            get: { store.book(with: book.id)?.pagesRead ?? 0 },
            set: { store.setPagesRead($0, for: book.id) }
        )
    }

    private func pagesDoubleBinding(_ book: Book) -> Binding<Double> {
        Binding(
            get: { Double(store.book(with: book.id)?.pagesRead ?? 0) },
            set: { store.setPagesRead(Int($0.rounded()), for: book.id) }
        )
    }

    private func notesBinding(_ book: Book) -> Binding<String> {
        Binding(
            get: { store.book(with: book.id)?.notes ?? "" },
            set: { store.setNotes($0, for: book.id) }
        )
    }
}
```

```swift
// FILE: StatsView.swift
import SwiftUI
import Charts

struct StatsView: View {
    @Environment(BookStore.self) private var store

    private var reading: [Book] {
        store.books.filter { $0.status == .reading }
    }

    var body: some View {
        Group {
            if store.books.isEmpty {
                ContentUnavailableView {
                    Label("No reading data yet", systemImage: "chart.bar")
                } description: {
                    Text("Add books and log your progress to see statistics here.")
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        statsGrid
                        if !reading.isEmpty { currentlyReading }
                        pagesChart
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Statistics")
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Books", value: "\(store.books.count)", systemImage: "books.vertical", color: .blue)
            StatCard(title: "Finished", value: "\(store.finishedCount)", systemImage: "checkmark.circle.fill", color: .green)
            StatCard(title: "Reading now", value: "\(store.readingCount)", systemImage: "book.open", color: .orange)
            StatCard(title: "Favourites", value: "\(store.favouriteCount)", systemImage: "star.fill", color: .yellow)
            StatCard(title: "Pages read", value: Formatters.pagesString(store.totalPagesRead), systemImage: "doc.text", color: .purple)
            StatCard(title: "Pages last 7 days", value: Formatters.pagesString(store.pagesReadThisWeek), systemImage: "calendar", color: .teal)
        }
    }

    private var currentlyReading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Currently reading")
                .font(.headline)
            ForEach(reading) { book in
                HStack(spacing: 10) {
                    CoverView(book: book, width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        BookProgressBar(progress: book.progress, color: book.coverColor, height: 5)
                    }
                    Spacer()
                    Text(Formatters.percentString(book.progress))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var pagesChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pages read per book")
                .font(.headline)
            Chart(store.books.sorted { $0.pagesRead > $1.pagesRead }) { book in
                BarMark(
                    x: .value("Pages", book.pagesRead),
                    y: .value("Book", book.title)
                )
                .foregroundStyle(book.coverColor)
            }
            .frame(height: CGFloat(60 + store.books.count * 30))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
```

Key points: `BookStore` is an `@Observable` model that persists to `books.json` in Documents on every mutation; the Library tab offers search, a filter menu (including **Favourites**), swipe actions for favourite/delete, and progress bars on every row; the detail screen lets you log pages via slider, steppers or +1/+10/+25/+50 quick buttons (each logged to a reading history), edit via the same form used for adding, and toggle the star; the Stats tab summarizes totals and charts pages read per book using Apple's Charts framework.