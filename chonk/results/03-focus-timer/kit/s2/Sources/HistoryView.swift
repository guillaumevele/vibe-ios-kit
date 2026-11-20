// FILE: HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var model: TimerModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: Session?

    var body: some View {
        Group {
            switch model.historyState {
            case .loading:
                loadingView
            case .empty:
                emptyView
            case .failed(let failure):
                failedView(failure)
            case .content(let sessions):
                contentView(sessions)
            }
        }
        .navigationTitle("History")
        .task {
            await model.loadHistoryIfNeeded()
        }
        .alert(
            "Delete this session?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in if !newValue { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { session in
            Button("Delete", role: .destructive) {
                Task { await model.delete(session) }
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { _ in
            Text("This cannot be undone.")
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView("Loading history")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No focus sessions yet", systemImage: "clock")
        } description: {
            Text("Complete a focus timer session and it will appear here.")
        } actions: {
            Button("Start a timer") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minHeight: 44)
        }
    }

    private func failedView(_ failure: HistoryFailure) -> some View {
        ContentUnavailableView {
            Label("History could not be loaded", systemImage: "exclamationmark.triangle")
        } description: {
            Text(failure.message)
        } actions: {
            Button("Retry") {
                Task { await model.loadHistory() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minHeight: 44)
        }
    }

    private func contentView(_ sessions: [Session]) -> some View {
        List {
            Section {
                ForEach(sessions) { session in
                    row(for: session)
                }
            } header: {
                Text("Total focus time: \(model.totalMinutes) minutes")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(for session: Session) -> some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: session.completedAt != nil ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(session.completedAt != nil ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(session.duration / 60)) minute focus session")
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(session.duration / 60)) minute focus session, \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                pendingDelete = session
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    let model = TimerModel(store: FileSessionStore.makePreview())
    model.historyState = .content([
        Session(id: UUID(), duration: 1500, startedAt: .now.addingTimeInterval(-3600), completedAt: .now.addingTimeInterval(-1800)),
        Session(id: UUID(), duration: 900, startedAt: .now.addingTimeInterval(-90000), completedAt: .now.addingTimeInterval(-89100))
    ])
    return NavigationStack {
        HistoryView(model: model)
    }
}
