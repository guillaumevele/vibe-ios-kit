// FILE: App.swift
// Reference fixture: uses every API the brief names, and must pass every check.
import SwiftUI

struct Note: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var created: Date
}

protocol NoteStore: Sendable {
    func load() async throws -> [Note]
}

struct MemoryStore: NoteStore {
    func load() async throws -> [Note] { [] }
}

enum LoadState: Equatable {
    case loading
    case empty
    case failed(String)
    case content([Note])
}

@MainActor
@Observable
final class NotesModel {
    var state: LoadState = .loading
    var selection: Note.ID?
    private let store: any NoteStore

    init(store: any NoteStore) { self.store = store }

    func load() async {
        state = .loading
        do {
            let notes = try await store.load()
            state = notes.isEmpty ? .empty : .content(notes)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct NotesScreen: View {
    @State private var model = NotesModel(store: MemoryStore())
    @State private var editing: Note?
    @State private var pendingDelete: Note?
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Notes")
                .navigationDestination(for: Note.self) { note in
                    Text(note.title).font(.title2)
                }
                .toolbar {
                    Button("Add", systemImage: "plus") {
                        editing = Note(id: UUID(), title: "", created: .now)
                    }
                    Button {
                        Task { await model.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Reload")
                }
        }
        .task { await model.load() }
        .sheet(item: $editing) { note in
            Text(note.created.formatted(date: .abbreviated, time: .omitted))
        }
        .alert("Delete this note?", isPresented: .constant(pendingDelete != nil)) {
            Button("Delete", role: .destructive) { pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
        .sensoryFeedback(.selection, trigger: model.selection)
        .onChange(of: scenePhase) { _, phase in
            pulse = phase == .active && !reduceMotion
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading notes")
        case .empty:
            ContentUnavailableView {
                Label("No notes yet", systemImage: "book")
            } description: {
                Text("Add your first note to get started.")
            } actions: {
                Button("Add a note") { editing = Note(id: UUID(), title: "", created: .now) }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Could not load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await model.load() } }
            }
        case .content(let notes):
            List(notes) { note in
                NavigationLink(value: note) {
                    VStack(alignment: .leading) {
                        Text(note.title).font(.headline)
                        Text(note.created.formatted(.relative(presentation: .named)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .animation(reduceMotion ? nil : .default, value: notes)
        }
    }
}

struct Ring: View {
    var progress: Double
    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(.tint, lineWidth: 8)
            .frame(minWidth: 44, minHeight: 44)
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityValue(Text(progress.formatted(.percent)))
    }
}

@main
struct NotesApp: App {
    var body: some Scene {
        WindowGroup { NotesScreen() }
    }
}

#Preview { NotesScreen() }
