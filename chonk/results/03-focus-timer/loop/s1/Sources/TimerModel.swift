// FILE: TimerModel.swift
import Foundation

@Observable
@MainActor
final class TimerModel {
    enum Phase: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    var selectedMinutes = 25
    var phase: Phase = .idle
    var remaining: TimeInterval = 0
    var endDate: Date?
    var notice: String?

    private let store: any SessionStore
    private var startedAt: Date?
    private var plannedDuration: TimeInterval = 0
    private var ticker: Task<Void, Never>?

    init(store: any SessionStore) {
        self.store = store
        self.remaining = totalDuration
    }

    var totalDuration: TimeInterval {
        Double(selectedMinutes) * 60
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, 1 - remaining / totalDuration))
    }

    var remainingDescription: String {
        Duration.seconds(remaining).formatted(.units(allowed: [.minutes, .seconds]))
    }

    func syncDuration() {
        if phase == .idle {
            remaining = totalDuration
        }
    }

    func start() {
        startedAt = Date.now
        plannedDuration = totalDuration
        remaining = totalDuration
        endDate = Date.now + totalDuration
        phase = .running
        notice = nil
        startTicker()
    }

    func pause() {
        guard phase == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        phase = .paused
        stopTicker()
    }

    func resume() {
        guard phase == .paused else { return }
        endDate = Date.now + remaining
        phase = .running
        startTicker()
    }

    func reset() {
        stopTicker()
        phase = .idle
        endDate = nil
        startedAt = nil
        remaining = totalDuration
    }

    func endEarly() {
        guard phase == .running else { return }
        stopTicker()
        Task { await self.record(completed: false) }
        phase = .idle
        endDate = nil
        remaining = totalDuration
    }

    func setSceneActive(_ isActive: Bool) {
        if isActive {
            if phase == .running {
                startTicker()
                tick()
            }
        } else {
            stopTicker()
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                await self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard phase == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            stopTicker()
            endDate = nil
            phase = .finished
            Task { await self.record(completed: true) }
        }
    }

    private func record(completed: Bool) async {
        guard let startedAt else { return }
        let session = FocusSession(
            id: UUID(),
            startedAt: startedAt,
            plannedDuration: plannedDuration,
            completed: completed,
            endedAt: Date.now
        )
        do {
            let existing = try await store.load()
            try await store.save(existing + [session])
            notice = nil
        } catch {
            notice = "The session finished but could not be saved to history. Open History and choose Retry to reload."
        }
    }
}
