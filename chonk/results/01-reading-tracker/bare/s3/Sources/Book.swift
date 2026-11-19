// FILE: Book.swift
import Foundation
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var totalPages: Int
    var currentPage: Int
    var isFavorite: Bool
    var dateAdded: Date
    var lastUpdated: Date

    init(
        title: String,
        author: String,
        totalPages: Int,
        currentPage: Int = 0,
        isFavorite: Bool = false
    ) {
        self.title = title
        self.author = author
        self.totalPages = max(0, totalPages)
        self.currentPage = min(max(0, currentPage), max(0, totalPages))
        self.isFavorite = isFavorite
        self.dateAdded = Date()
        self.lastUpdated = Date()
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(1, max(0, Double(currentPage) / Double(totalPages)))
    }

    var isFinished: Bool {
        totalPages > 0 && currentPage >= totalPages
    }

    var percentText: String {
        "\(Int(progress * 100))%"
    }

    func setProgress(page: Int) {
        currentPage = min(max(0, page), max(0, totalPages))
        lastUpdated = Date()
    }
}
