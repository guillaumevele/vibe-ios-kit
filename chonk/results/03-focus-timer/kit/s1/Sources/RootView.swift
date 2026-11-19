// FILE: RootView.swift
import SwiftUI

enum Route: Hashable {
    case history
}

struct RootView: View {
    @State private var timer: TimerModel
    @State private var history: HistoryModel
    @State private var path = NavigationPath()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = FileSessionStore.default
        _timer = State(initialValue: TimerModel(store: store))
        _history = State(initialValue: HistoryModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            TimerView(model: timer, path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .history:
                        HistoryView(model: history)
                    }
                }
                .navigationDestination(for: FocusSession.self) { session in
                    SessionDetailView(session: session)
                }
        }
        .task {
            timer.setSceneActive(scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, newPhase in
            timer.setSceneActive(newPhase == .active)
        }
    }
}
