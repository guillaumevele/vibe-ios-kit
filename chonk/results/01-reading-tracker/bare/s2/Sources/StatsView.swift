// FILE: StatsView.swift
import SwiftUI
import Charts

struct StatsView: View {
    @Environment(BookStore.self) private var store

    private var reading: [Book] {
        store.books.filter { $0.status == .reading }
    }

    var body: some View {
        Group {
            if store.books.isEmpty {
                ContentUnavailableView {
                    Label("No reading data yet", systemImage: "chart.bar")
                } description: {
                    Text("Add books and log your progress to see statistics here.")
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        statsGrid
                        if !reading.isEmpty { currentlyReading }
                        pagesChart
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Statistics")
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Books", value: "\(store.books.count)", systemImage: "books.vertical", color: .blue)
            StatCard(title: "Finished", value: "\(store.finishedCount)", systemImage: "checkmark.circle.fill", color: .green)
            StatCard(title: "Reading now", value: "\(store.readingCount)", systemImage: "book.open", color: .orange)
            StatCard(title: "Favourites", value: "\(store.favouriteCount)", systemImage: "star.fill", color: .yellow)
            StatCard(title: "Pages read", value: Formatters.pagesString(store.totalPagesRead), systemImage: "doc.text", color: .purple)
            StatCard(title: "Pages last 7 days", value: Formatters.pagesString(store.pagesReadThisWeek), systemImage: "calendar", color: .teal)
        }
    }

    private var currentlyReading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Currently reading")
                .font(.headline)
            ForEach(reading) { book in
                HStack(spacing: 10) {
                    CoverView(book: book, width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        BookProgressBar(progress: book.progress, color: book.coverColor, height: 5)
                    }
                    Spacer()
                    Text(Formatters.percentString(book.progress))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var pagesChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pages read per book")
                .font(.headline)
            Chart(store.books.sorted { $0.pagesRead > $1.pagesRead }) { book in
                BarMark(
                    x: .value("Pages", book.pagesRead),
                    y: .value("Book", book.title)
                )
                .foregroundStyle(book.coverColor)
            }
            .frame(height: CGFloat(60 + store.books.count * 30))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
