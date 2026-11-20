// FILE: ContentView.swift
import Foundation
import SwiftUI

enum Route: Hashable {
    case history
}

struct ContentView: View {
    @State private var model: AppModel
    @State private var path: [Route] = []

    init(model: AppModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack(path: $path) {
            TimerView(model: model)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: Route.history) {
                            Label("History", systemImage: "clock")
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .history:
                        HistoryView(model: model) {
                            path.removeAll()
                        }
                    }
                }
                .task {
                    await model.loadHistory()
                }
        }
    }
}

#Preview {
    ContentView(model: AppModel(store: InMemorySessionStore()))
}

#Preview("History with sessions") {
    let store = InMemorySessionStore(sessions: [
        FocusSession(
            id: UUID(),
            duration: 25 * 60,
            startedAt: Date().addingTimeInterval(-3 * 3600),
            endedAt: Date().addingTimeInterval(-2 * 3600 - 600),
            completed: true
        ),
        FocusSession(
            id: UUID(),
            duration: 15 * 60,
            startedAt: Date().addingTimeInterval(-26 * 3600),
            endedAt: Date().addingTimeInterval(-25 * 3600),
            completed: false
        )
    ])
    return ContentView(model: AppModel(store: store))
}
