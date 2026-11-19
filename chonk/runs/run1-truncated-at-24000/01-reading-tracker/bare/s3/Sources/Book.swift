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
    var notes: String?

    init(
        title: String,
        author: String,
        totalPages: Int,
        pagesRead: Int = 0,
        isFavorite: Bool = false,
        dateAdded: Date = .now,
        notes: String? = nil
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(1, totalPages)
        self.pagesRead = min(max(0, pagesRead), self.totalPages)
        self.isFavorite = isFavorite
        self.dateAdded = dateAdded
        self.notes = notes
    }

    /// Reading progress in the range 0...1.
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesRead) / Double(totalPages)
    }

    var isFinished: Bool {
        totalPages > 0 && pagesRead >= totalPages
    }

    var percentText: String {
        "\(Int(progress * 100))%"
    }
}
