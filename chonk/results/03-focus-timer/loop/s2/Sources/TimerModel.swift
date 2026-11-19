// FILE: TimerModel.swift
import Foundation
import Observation
import SwiftUI

enum HistoryState: Sendable {
    case loading
    case empty
    case failed(HistoryFailure)
    case content([Session])
}

struct HistoryFailure: Sendable, Equatable {
    let message: String
}

struct DurationOption: Identifiable, Hashable, Sendable {
    let minutes: Int

    var id: Int { minutes }

    var label: String { "\(minutes) min" }

    static let all: [DurationOption] = [15, 25, 45, 60].map { DurationOption(minutes: $0) }
}

@Observable
@MainActor
final class TimerModel {
    enum Phase: Sendable {
        case idle
        case running
        case paused
        case finished
    }

    var phase: Phase = .idle
    var selectedMinutes = 25
    var duration: TimeInterval = 25 * 60
    var remaining: TimeInterval = 25 * 60
    var endDate: Date?
    var completedCount = 0
    var notice: String?
    var historyState: HistoryState = .loading

    private(set) var sessions: [Session] = []
    private var startDate: Date = .now
    private var ticker: Task<Void, Never>?
    private let store: SessionStoring
    private var hasLoaded = false
    private var storeReadable = false

    init(store: SessionStoring) {
        self.store = store
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    var remainingDescription: String {
        let total = max(0, Int(remaining.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes) minutes and \(seconds) seconds"
        }
        return "\(seconds) seconds"
    }

    var totalMinutes: Int {
        sessions.reduce(0) { $0 + Int($1.duration / 60) }
    }

    // MARK: Timer controls

    func start() {
        guard phase == .idle || phase == .finished else { return }
        duration = TimeInterval(selectedMinutes * 60)
        remaining = duration
        startDate = .now
        endDate = .now.addingTimeInterval(duration)
        notice = nil
        phase = .running
        startTicker()
    }

    func pause() {
        guard phase == .running else { return }
        if let end = endDate {
            remaining = max(0, end.timeIntervalSince(.now))
        }
        stopTicker()
        endDate = nil
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        endDate = .now.addingTimeInterval(remaining)
        phase = .running
        startTicker()
    }

    func reset() {
        stopTicker()
        phase = .idle
        endDate = nil
        remaining = TimeInterval(selectedMinutes * 60)
        duration = remaining
    }

    func handleScenePhase(_ newPhase: ScenePhase) {
        if newPhase == .active {
            if phase == .running && ticker == nil {
                endDate = .now.addingTimeInterval(remaining)
                startTicker()
            }
        } else if phase == .running {
            if let end = endDate {
                remaining = max(0, end.timeIntervalSince(.now))
            }
            stopTicker()
            endDate = nil
        }
    }

    // MARK: History

    func loadHistoryIfNeeded() async {
        guard !hasLoaded else { return }
        await loadHistory()
    }

    func loadHistory() async {
        historyState = .loading
        do {
            let loaded = try await store.load()
            storeReadable = true
            hasLoaded = true
            sessions = loaded.sorted { $0.startedAt > $1.startedAt }
            historyState = sessions.isEmpty ? .empty : .content(sessions)
        } catch {
            storeReadable = false
            hasLoaded = true
            historyState = .failed(HistoryFailure(message: "Past sessions could not be read from storage. Nothing was changed or deleted."))
        }
    }

    func delete(_ session: Session) async {
        sessions.removeAll { $0.id == session.id }
        historyState = sessions.isEmpty ? .empty : .content(sessions)
        await persist()
    }

    // MARK: Private

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard phase == .running else { return }
        if let end = endDate {
            remaining = max(0, end.timeIntervalSince(.now))
        }
        if remaining <= 0 {
            complete()
        }
    }

    private func complete() {
        stopTicker()
        endDate = nil
        remaining = 0
        phase = .finished
        completedCount += 1
        Task {
            await recordSession()
        }
    }

    private func recordSession() async {
        let session = Session(id: UUID(), duration: duration, startedAt: startDate, completedAt: .now)
        sessions.insert(session, at: 0)
        historyState = sessions.isEmpty ? .empty : .content(sessions)
        await persist()
    }

    private func persist() async {
        guard storeReadable else {
            notice = "This session finished, but it could not be saved because the history has not been read successfully yet. Open History and retry to re-enable saving."
            return
        }
        do {
            try await store.save(sessions)
        } catch {
            storeReadable = false
            notice = "This session finished, but saving the history failed. Saving stays disabled until the history loads successfully."
            historyState = .failed(HistoryFailure(message: "The history could not be saved. Use Retry to reload it, then the change can be saved again."))
        }
    }
}
