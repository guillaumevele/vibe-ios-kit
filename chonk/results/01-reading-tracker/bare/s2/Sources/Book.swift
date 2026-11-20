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
