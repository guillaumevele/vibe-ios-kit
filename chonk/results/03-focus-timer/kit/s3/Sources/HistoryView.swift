// FILE: HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel
    let onStartSession: () -> Void
    @State private var showClearConfirmation = false

    init(model: AppModel, onStartSession: @escaping () -> Void) {
        self.model = model
        self.onStartSession = onStartSession
    }

    var body: some View {
        Group {
            switch model.historyState {
            case .loading:
                ProgressView("Loading history")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView {
                    Label("No sessions yet", systemImage: "clock")
                } description: {
                    Text("Finish a focus session and it will appear here.")
                } actions: {
                    Button("Start a session") {
                        onStartSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            case .failed(let error):
                ContentUnavailableView {
                    Label("Could not load history", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Your saved sessions were left untouched.")
                    Text(error.localizedDescription)
                        .font(.footnote)
                } actions: {
                    Button("Retry") {
                        Task { await model.loadHistory() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            case .content:
                List(model.sessions) { session in
                    SessionRow(session: session)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                model.sessionToDelete = session
                            }
                        }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("History")
        .task {
            await model.loadHistory()
        }
        .alert(item: $model.sessionToDelete) { session in
            Alert(
                title: Text("Delete this session?"),
                message: Text("This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await model.deleteSession(session) }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Clear all history?", isPresented: $showClearConfirmation) {
            Button("Clear all", role: .destructive) {
                Task { await model.clearHistory() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Every saved session will be deleted. This cannot be undone.")
        }
        .toolbar {
            if case .content = model.historyState {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
            }
        }
    }
}
