// FILE: FocusTimerApp.swift
import SwiftUI
import Observation

@main
struct FocusTimerApp: App {
    @State private var store: SessionStore
    @State private var timer: FocusTimerViewModel

    init() {
        let store = SessionStore()
        self._store = State(initialValue: store)
        self._timer = State(initialValue: FocusTimerViewModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(timer)
        }
    }
}
