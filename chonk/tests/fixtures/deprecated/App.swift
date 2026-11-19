// FILE: App.swift
// Compiles, but uses the one-parameter onChange deprecated in iOS 17.
import SwiftUI

struct Counter: View {
    @State private var count = 0
    @State private var doubled = 0
    var body: some View {
        Button("Count \(count)") { count += 1 }
            .onChange(of: count) { newValue in doubled = newValue * 2 }
    }
}

@main
struct CounterApp: App {
    var body: some Scene { WindowGroup { Counter() } }
}
