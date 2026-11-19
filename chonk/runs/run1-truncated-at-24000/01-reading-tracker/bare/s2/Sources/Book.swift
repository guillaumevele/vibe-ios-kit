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
        totalPages: Int,
        pagesRead: Int = 0,
        isFavorite: Bool = false,
        notes: String = ""
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(1, totalPages)
        self.pagesRead = min(max(0, pagesRead), self.totalPages)
        self.isFavorite = isFavorite
        self.dateAdded = Date()
        self.notes = notes
    }

    /// Progress as a value between 0 and 1.
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesRead) / Double(totalPages)
    }

    /// Progress as a whole-number percentage (0–100).
    var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    var status: BookStatus {
        if pagesRead <= 0 { return .notStarted }
        if pagesRead >= totalPages { return .finished }
        return .reading
    }
}
