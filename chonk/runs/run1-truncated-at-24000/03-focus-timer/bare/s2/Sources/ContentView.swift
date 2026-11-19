// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var engine = TimerEngine()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerView(engine: $engine)
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(0)

            HistoryView { duration, title in
                engine.prepareForRepeat(duration: duration, title: title)
                selectedTab = 0
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(1)
        }
        .tint(Theme.accent)
    }
}
