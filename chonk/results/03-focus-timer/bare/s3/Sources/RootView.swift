// FILE: RootView.swift
import SwiftUI
import UIKit

enum RootTab: Hashable {
    case focus
    case history
}

struct RootView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var store: SessionStore
    @State private var selection: RootTab = .focus

    var body: some View {
        TabView(selection: $selection) {
            Tab("Focus", systemImage: "timer", value: RootTab.focus) {
                ContentView(engine: engine) {
                    selection = .history
                }
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: RootTab.history) {
                HistoryView()
            }
        }
        .environmentObject(store)
        .onAppear { engine.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // The countdown is end-date based, so it stays correct across backgrounding;
            // this just completes an overdue timer as soon as we're active again.
            engine.refresh()
        }
    }
}
