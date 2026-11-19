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
