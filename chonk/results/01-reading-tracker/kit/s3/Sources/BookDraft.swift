// FILE: BookDraft.swift
import Foundation

struct BookDraft: Identifiable, Sendable {
    let id = UUID()
    var title: String = ""
    var author: String = ""
    var totalPages: Int = 300
    var pagesRead: Int = 0

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && totalPages >= 1
            && pagesRead >= 0
            && pagesRead <= totalPages
    }
}
