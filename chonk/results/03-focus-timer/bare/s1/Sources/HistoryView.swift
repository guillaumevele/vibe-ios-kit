// FILE: HistoryView.swift
import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]
    @State private var confirmClear = false

    private var totalTime: TimeInterval {
        sessions.reduce(0) { $0 + $1.actualDuration }
    }

    private var weekTime: TimeInterval {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return sessions
            .filter { $0.startedAt >= weekStart }
            .reduce(0) { $0 + $1.actualDuration }
    }

    var body: some View {
        NavigationStack {
            List {
                if !sessions.isEmpty {
                    Section {
                        HStack(spacing: 0) {
                            stat("\(sessions.count)", "sessions")
                            Divider()
                            stat(Formatters.long(totalTime), "total")
                            Divider()
                            stat(Formatters.long(weekTime), "this week")
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("Past sessions") {
                    ForEach(sessions) { session in
                        SessionRowView(session: session)
                    }
                    .onDelete(perform: delete)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !sessions.isEmpty {
                        Button("Clear", role: .destructive) { confirmClear = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !sessions.isEmpty {
                        EditButton()
                    }
                }
            }
            .confirmationDialog(
                "Delete all \(sessions.count) sessions?",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) { clearAll() }
                Button("Cancel", role: .cancel) { }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "clock.badge.checkmark",
                        description: Text("Complete a focus session and it will appear here.")
                    )
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func delete(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(sessions[offset])
        }
    }

    private func clearAll() {
        for session in sessions {
            modelContext.delete(session)
        }
    }
}
