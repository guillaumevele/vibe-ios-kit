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
