// FILE: ReadingListApp.swift
import SwiftUI

@main
struct ReadingListApp: App {
    var body: some Scene {
        WindowGroup {
            BookListView(model: LibraryModel())
        }
    }
}
