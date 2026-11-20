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
