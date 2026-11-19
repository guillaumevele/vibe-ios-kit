// FILE: HistoryView.swift
import SwiftUI
import Foundation

struct HistoryView: View {
    @Bindable var model: HistoryModel
    @Environment(\.dismiss) private var dismiss
    @State private var showClearAlert = false

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView("Loading history")
            case .empty:
                ContentUnavailableView {
                    Label("No focus sessions yet", systemImage: "clock")
                } description: {
                    Text("Finish a focus session and it will appear here.")
                } actions: {
                    Button("Back to timer") {
                        dismiss()
                    }
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("History could not be loaded", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry", systemImage: "arrow.clockwise") {
                        Task { await model.load() }
                    }
                }
            case .loaded(let sessions):
                sessionList(sessions)
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .loaded = model.state {
                    Button("Clear", role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert("Clear all history?", isPresented: $showClearAlert) {
            Button("Clear", role: .destructive) {
                Task { await model.clearAll() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Every saved session will be removed and this cannot be undone.")
        }
        .task {
            await model.load()
        }
    }

    private func sessionList(_ sessions: [FocusSession]) -> some View {
        List {
            if let notice = model.notice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .listRowBackground(Color.clear)
            }
            ForEach(sessions) { session in
                NavigationLink(value: session) {
                    SessionRow(session: session)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await model.delete(session) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(session.completed ? .green : .secondary)
                .accessibilityLabel(Text(session.completed ? "Completed" : "Ended early"))
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(Duration.seconds(session.plannedDuration).formatted(.units(allowed: [.minute])))
                    .font(.headline)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Duration.seconds(session.actualDuration).formatted(.units(allowed: [.minute, .second])))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryPreviewRoot: View {
    @State private var model: HistoryModel

    init() {
        let samples = [
            FocusSession(
                id: UUID(),
                startedAt: Date.now.addingTimeInterval(-3900),
                plannedDuration: 25 * 60,
                completed: true,
                endedAt: Date.now.addingTimeInterval(-1400)
            ),
            FocusSession(
                id: UUID(),
                startedAt: Date.now.addingTimeInterval(-90000),
                plannedDuration: 45 * 60,
                completed: false,
                endedAt: Date.now.addingTimeInterval(-89280)
            )
        ]
        _model = State(initialValue: HistoryModel(store: MemorySessionStore(sessions: samples)))
    }

    var body: some View {
        NavigationStack {
            HistoryView(model: model)
        }
    }
}

#Preview("History") {
    HistoryPreviewRoot()
}
