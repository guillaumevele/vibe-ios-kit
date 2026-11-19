// FILE: ContentView.swift
import SwiftUI

enum Spacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 32
}

enum Route: Hashable, Sendable {
    case history
}

struct ContentView: View {
    @State private var model: TimerModel
    @Environment(\.scenePhase) private var scenePhase

    @MainActor
    init() {
        _model = State(initialValue: TimerModel(store: FileSessionStore.makeDefault()))
    }

    var body: some View {
        NavigationStack {
            TimerView(model: model)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .history:
                        HistoryView(model: model)
                    }
                }
        }
        .task {
            await model.loadHistoryIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.handleScenePhase(newPhase)
        }
    }
}

#Preview {
    ContentView()
}
