// FILE: AppModel.swift
import Foundation
import SwiftUI

@Observable
@MainActor
final class AppModel {
    enum Phase: Equatable, Sendable {
        case idle
        case running
        case paused
        case finished(completed: Bool)
    }

    enum HistoryState {
        case loading
        case empty
        case failed(Error)
        case content
    }

    // MARK: - Timer state

    var phase: Phase = .idle
    var durationMinutes: Int = 25
    var duration: TimeInterval = 25 * 60
    var remaining: TimeInterval = 25 * 60
    var progress: Double = 1
    private(set) var endDate: Date = Date().addingTimeInterval(25 * 60)
    private var startedAt: Date = Date()
    private var tickerTask: Task<Void, Never>?

    // MARK: - History state

    var sessions: [FocusSession] = []
    var historyState: HistoryState = .loading
    var sessionToDelete: FocusSession?
    private var historyLoaded = false

    private let store: SessionStore

    init(store: SessionStore) {
        self.store = store
    }

    // MARK: - Timer actions

    func applyDuration(_ minutes: Int) {
        guard case .idle = phase else { return }
        duration = TimeInterval(minutes) * 60
        remaining = duration
        progress = 1
    }

    func start() {
        switch phase {
        case .idle, .finished:
            startedAt = Date()
            endDate = Date().addingTimeInterval(duration)
            remaining = duration
            progress = 1
            phase = .running
            startTicker()
        case .running, .paused:
            break
        }
    }

    func pause() {
        guard case .running = phase else { return }
        applyRemaining()
        tickerTask?.cancel()
        phase = .paused
    }

    func resume() {
        guard case .paused = phase else { return }
        endDate = Date().addingTimeInterval(remaining)
        phase = .running
        startTicker()
    }

    func endSession(completed: Bool) {
        switch phase {
        case .running, .paused:
            tickerTask?.cancel()
            if completed {
                remaining = 0
                progress = 0
            } else {
                applyRemaining()
            }
            phase = .finished(completed: completed)
            Task { await recordSession(completed: completed) }
        case .idle, .finished:
            break
        }
    }

    func resetToIdle() {
        tickerTask?.cancel()
        phase = .idle
        remaining = duration
        progress = 1
    }

    // MARK: - Scene lifecycle

    func handleAppear() {
        if case .running = phase {
            startTicker()
        }
    }

    func handleDisappear() {
        tickerTask?.cancel()
    }

    func handleScenePhase(_ newPhase: ScenePhase) {
        if newPhase == .active {
            if case .running = phase {
                applyRemaining()
                if remaining <= 0 {
                    endSession(completed: true)
                } else {
                    startTicker()
                }
            }
        } else {
            tickerTask?.cancel()
            if case .running = phase {
                applyRemaining()
            }
        }
    }

    // MARK: - History

    func loadHistory() async {
        historyState = .loading
        do {
            let loaded = try await store.load()
            sessions = loaded.sorted { $0.startedAt > $1.startedAt }
            historyLoaded = true
            historyState = sessions.isEmpty ? .empty : .content
        } catch {
            historyLoaded = false
            historyState = .failed(error)
        }
    }

    func deleteSession(_ session: FocusSession) async {
        sessionToDelete = nil
        guard historyLoaded else { return }
        await persist(sessions.filter { $0.id != session.id })
    }

    func clearHistory() async {
        guard historyLoaded else { return }
        await persist([])
    }

    // MARK: - Private

    private func applyRemaining() {
        remaining = max(0, endDate.timeIntervalSinceNow)
        progress = duration > 0 ? remaining / duration : 0
    }

    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task {
            while !Task.isCancelled {
                tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func tick() {
        guard case .running = phase else { return }
        applyRemaining()
        if remaining <= 0 {
            endSession(completed: true)
        }
    }

    private func persist(_ updated: [FocusSession]) async {
        do {
            try await store.save(updated)
            sessions = updated
            historyState = updated.isEmpty ? .empty : .content
        } catch {
            historyState = .failed(error)
        }
    }

    private func recordSession(completed: Bool) async {
        if !historyLoaded {
            do {
                let loaded = try await store.load()
                sessions = loaded.sorted { $0.startedAt > $1.startedAt }
                historyLoaded = true
            } catch {
                // Refuse to write when the store could not be read.
                historyState = .failed(error)
                return
            }
        }
        let session = FocusSession(
            id: UUID(),
            duration: duration,
            startedAt: startedAt,
            endedAt: Date(),
            completed: completed
        )
        var updated = sessions
        updated.insert(session, at: 0)
        await persist(updated)
    }
}
