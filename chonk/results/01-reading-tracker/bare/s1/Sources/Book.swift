// FILE: Book.swift
import Foundation
import SwiftData

/// A single book being tracked, persisted with SwiftData.
@Model
final class Book {
    var title: String
    var author: String
    var totalPages: Int
    var pagesRead: Int
    var isFavorite: Bool
    var notes: String
    var dateAdded: Date

    init(
        title: String,
        author: String = "",
        totalPages: Int,
        pagesRead: Int = 0,
        isFavorite: Bool = false,
        notes: String = "",
        dateAdded: Date = .now
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(totalPages, 1)
        self.pagesRead = min(max(pagesRead, 0), max(totalPages, 1))
        self.isFavorite = isFavorite
        self.notes = notes
        self.dateAdded = dateAdded
    }

    /// Reading progress from 0.0 to 1.0.
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(Double(pagesRead) / Double(totalPages), 1.0)
    }

    /// True when every page has been read.
    var isFinished: Bool {
        totalPages > 0 && pagesRead >= totalPages
    }
}
