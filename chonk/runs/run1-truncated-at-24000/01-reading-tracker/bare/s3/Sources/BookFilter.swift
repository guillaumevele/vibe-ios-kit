// FILE: BookFilter.swift
import Foundation

enum BookFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: "books.vertical"
        case .favorites: "star.fill"
        }
    }
}
