// FILE: App.swift
// Negative witness: every check in the rubric must fail on this file. 🎉
import SwiftUI

class Model: ObservableObject {
    @Published var items: [String] = []
    func load() {
        DispatchQueue.main.async {
            let data = try! Data(contentsOf: URL(string: "https://example.com")!)
            self.items = [String(data: data, encoding: .utf8) ?? ""]
        }
    }
    func save() {
        do { try "x".write(toFile: "/tmp/x", atomically: true, encoding: .utf8) }
        catch { print(error) }
    }
}

struct ContentView: View {
    @StateObject var model = Model()
    @State var spin = false
    var body: some View {
        NavigationView {
            List(model.items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 17))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .toolbar {
                Button(action: { model.load() }) {
                    Image(systemName: "arrow.sparkle.refresh")
                }
            }
            .overlay {
                TimelineView(.animation) { _ in
                    Image(systemName: "gear").rotationEffect(.degrees(spin ? 360 : 0))
                }
            }
            .onAppear {
                withAnimation(.linear.repeatForever(autoreverses: false)) { spin = true }
                undefinedFunction()
            }
        }
    }
}

@main
struct BadApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
