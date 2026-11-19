// FILE: ReadingStatus.swift
import Foundation
import SwiftUI

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case wantToRead = "Want to Read"
    case reading = "Reading"
    case finished = "Finished"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .wantToRead: "bookmark"
        case .reading: "book.open"
        case .finished: "checkmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .wantToRead: .orange
        case .reading: .blue
        case .finished: .green
        }
    }
}
