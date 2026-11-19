// FILE: ReadingListApp.swift
import Foundation
import SwiftUI

@main
struct ReadingListApp: App {
    @State private var store: BookStore

    init() {
        let directory = FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = directory.appendingPathComponent("books.json")
        _store = State(initialValue: BookStore(repository: FileBookRepository(fileURL: fileURL)))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .tint(Theme.accent)
        }
    }
}
