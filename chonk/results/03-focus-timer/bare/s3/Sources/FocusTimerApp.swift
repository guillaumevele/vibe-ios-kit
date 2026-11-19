// FILE: FocusTimerApp.swift
import SwiftUI

@main
struct FocusTimerApp: App {
    @StateObject private var store: SessionStore
    @StateObject private var engine: TimerEngine

    init() {
        let store = SessionStore()
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: TimerEngine(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView(engine: engine, store: store)
        }
    }
}
