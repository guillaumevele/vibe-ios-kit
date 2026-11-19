// FILE: ReadingListApp.swift
import Foundation
import SwiftUI

@main
struct ReadingListApp: App {
    private let store: BookStore = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileBookStore(url: directory.appendingPathComponent("books.json"))
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .tint(Theme.accent)
        }
    }
}
