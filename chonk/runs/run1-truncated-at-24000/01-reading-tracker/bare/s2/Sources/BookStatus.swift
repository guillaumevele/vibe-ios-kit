// FILE: BookStatus.swift
import SwiftUI

enum BookStatus: String, CaseIterable {
    case notStarted = "Not started"
    case reading = "Reading"
    case finished = "Finished"

    var icon: String {
        switch self {
        case .notStarted: "circle"
        case .reading: "book.fill"
        case .finished: "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: .secondary
        case .reading: .blue
        case .finished: .green
        }
    }
}
