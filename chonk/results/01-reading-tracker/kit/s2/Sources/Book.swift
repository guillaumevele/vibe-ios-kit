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
