// FILE: BookDraft.swift
import Foundation
import Observation

@Observable
@MainActor
final class BookDraft: Identifiable {
    let id = UUID()
    var title = ""
    var author = ""
    var totalPagesText = ""

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Int(totalPagesText) ?? 0) > 0
    }
}
