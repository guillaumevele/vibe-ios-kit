// FILE: StatsHeaderView.swift
import SwiftUI

struct StatsHeaderView: View {
    let books: [Book]

    private var finishedCount: Int {
        books.filter(\.isFinished).count
    }

    private var averageProgress: Double {
        guard !books.isEmpty else { return 0 }
        return books.reduce(0) { $0 + $1.progress } / Double(books.count)
    }

    var body: some View {
        HStack(spacing: 0) {
            stat(value: "\(books.count)", label: "Books")
            Divider()
            stat(value: "\(books.count - finishedCount)", label: "Reading")
            Divider()
            stat(value: "\(finishedCount)", label: "Finished")
            Divider()
            stat(value: "\(Int(averageProgress * 100))%", label: "Avg. progress")
        }
        .padding(.vertical, 8)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
