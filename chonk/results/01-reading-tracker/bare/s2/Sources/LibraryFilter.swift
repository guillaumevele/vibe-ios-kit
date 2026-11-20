// FILE: LibraryFilter.swift
import Foundation

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favourites = "Favourites"
    case reading = "Reading"
    case wantToRead = "Want to Read"
    case finished = "Finished"

    var id: String { rawValue }

    var predicate: (Book) -> Bool {
        switch self {
        case .all:        { _ in true }
        case .favourites: { $0.isFavourite }
        case .reading:    { $0.status == .reading }
        case .wantToRead: { $0.status == .wantToRead }
        case .finished:   { $0.status == .finished }
        }
    }
}
