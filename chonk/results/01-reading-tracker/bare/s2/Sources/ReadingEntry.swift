// FILE: ReadingEntry.swift
import Foundation

struct ReadingEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var pages: Int
}
