// FILE: LibrarySummaryView.swift
import SwiftUI

struct LibrarySummaryView: View {
    let books: [Book]

    private var readingCount: Int {
        books.filter { $0.status == .reading }.count
    }

    private var finishedCount: Int {
        books.filter { $0.status == .finished }.count
    }

    private var averageProgress: Int {
        guard !books.isEmpty else { return 0 }
        let total = books.reduce(0.0) { $0 + $1.progress }
        return Int((total / Double(books.count) * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 0) {
            stat(value: "\(books.count)", label: "Books")
            stat(value: "\(readingCount)", label: "Reading")
            stat(value: "\(finishedCount)", label: "Finished")
            stat(value: "\(averageProgress)%", label: "Avg. progress")
        }
        .padding(.vertical, 4)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
