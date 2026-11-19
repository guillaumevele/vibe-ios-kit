// FILE: HistoryModel.swift
import Foundation

@Observable
@MainActor
final class HistoryModel {
    enum LoadState: Equatable {
        case loading
        case empty
        case failed(String)
        case loaded([FocusSession])
    }

    var state: LoadState = .loading
    var notice: String?

    let store: any SessionStore
    private var canWrite = true

    init(store: any SessionStore) {
        self.store = store
    }

    func load() async {
        state = .loading
        do {
            let sessions = try await store.load()
            canWrite = true
            notice = nil
            state = sessions.isEmpty ? .empty : .loaded(sessions.sorted { $0.startedAt > $1.startedAt })
        } catch {
            canWrite = false
            state = .failed("The saved history could not be read, so nothing was changed. Check that storage is available, then choose Retry.")
        }
    }

    func delete(_ session: FocusSession) async {
        guard canWrite, case .loaded(let sessions) = state else { return }
        await persist(sessions.filter { $0.id != session.id })
    }

    func clearAll() async {
        await persist([])
    }

    private func persist(_ sessions: [FocusSession]) async {
        guard canWrite else {
            notice = "Saving is paused until the history loads successfully. Choose Retry first."
            return
        }
        do {
            try await store.save(sessions)
            notice = nil
            state = sessions.isEmpty ? .empty : .loaded(sessions.sorted { $0.startedAt > $1.startedAt })
        } catch {
            notice = "The change could not be saved. The stored history was not modified."
        }
    }
}
