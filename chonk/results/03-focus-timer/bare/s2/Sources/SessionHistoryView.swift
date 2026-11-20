// FILE: SessionHistoryView.swift
import SwiftUI
import Observation

struct SessionHistoryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    HistoryStat(title: "Today", value: FocusFormat.duration(store.totalToday))
                    HistoryStat(title: "Week", value: FocusFormat.duration(store.totalThisWeek))
                    HistoryStat(title: "All time", value: FocusFormat.duration(store.totalDuration))
                }
                .listRowBackground(Color.clear)
            }

            ForEach(grouped, id: \.day) { group in
                Section(header: Text(sectionTitle(for: group.day))) {
                    ForEach(group.sessions) { session in
                        HistoryRowView(session: session)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.delete(session)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !store.sessions.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            store.clear()
                        } label: {
                            Label("Clear all", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .overlay {
            if store.sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "clock.badge.checkmark",
                    description: Text("Finish a focus session and it will appear here.")
                )
            }
        }
    }

    private var grouped: [(day: Date, sessions: [FocusSession])] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: store.sessions) { calendar.startOfDay(for: $0.endedAt) }
        return byDay
            .map { (day: $0.key, sessions: $0.value.sorted { $1.endedAt < $0.endedAt }) }
            .sorted { $0.day > $1.day }
    }

    private func sectionTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct HistoryStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
