// FILE: TimerEngine.swift
import Foundation
import Observation

/// Date-based countdown engine. Remaining time is always derived from
/// `endDate`, so the ring stays accurate even if scheduled timers are
/// coalesced while the app is in the background.
@Observable
final class TimerEngine {
    enum State: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    var state: State = .idle
    var title: String = "Focus"
    var totalDuration: TimeInterval = 25 * 60
    var pausedRemaining: TimeInterval = 25 * 60
    private(set) var startedAt: Date?
    private(set) var endDate: Date?

    private var finishTimer: Timer?
    private var onFinish: ((TimeInterval) -> Void)?

    /// Time spent focusing so far.
    var elapsed: TimeInterval {
        min(totalDuration, max(0, totalDuration - remaining()))
    }

    /// Remaining time at a given moment (used by TimelineView for smooth rendering).
    func remaining(at date: Date = Date()) -> TimeInterval {
        switch state {
        case .idle, .paused, .finished:
            return pausedRemaining
        case .running:
            guard let endDate else { return pausedRemaining }
            return max(0, endDate.timeIntervalSince(date))
        }
    }

    func start(duration: TimeInterval, title: String, onFinish: @escaping (TimeInterval) -> Void) {
        totalDuration = duration
        pausedRemaining = duration
        self.title = title
        self.onFinish = onFinish
        startedAt = Date()
        beginRunning()
        state = .running
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = remaining()
        stopTimer()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        beginRunning()
        state = .running
    }

    func cancel() {
        stopTimer()
        state = .idle
        pausedRemaining = totalDuration
    }

    func reset() {
        stopTimer()
        state = .idle
        pausedRemaining = totalDuration
    }

    /// Change the duration while idle (duration picker).
    func selectDuration(_ duration: TimeInterval) {
        guard state == .idle else { return }
        totalDuration = duration
        pausedRemaining = duration
    }

    /// Pre-fill the idle screen from a past session.
    func prepareForRepeat(duration: TimeInterval, title: String) {
        guard state == .idle else { return }
        totalDuration = duration
        pausedRemaining = duration
        self.title = title
    }

    /// Call when the app becomes active again — finishes the session if the
    /// end date passed while the app was suspended.
    func refreshIfNeeded() {
        if state == .running, remaining() <= 0 {
            finish()
        }
    }

    // MARK: - Private

    private func beginRunning() {
        endDate = Date().addingTimeInterval(pausedRemaining)
        scheduleFinish(at: endDate!)
    }

    private func scheduleFinish(at date: Date) {
        finishTimer?.invalidate()
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.handleTimerFire()
        }
        RunLoop.main.add(timer, forMode: .common)
        finishTimer = timer
    }

    private func handleTimerFire() {
        if remaining() <= 0 {
            finish()
        } else {
            // Fired early (e.g. after background suspension) — reschedule.
            scheduleFinish(at: Date().addingTimeInterval(remaining()))
        }
    }

    private func finish() {
        stopTimer()
        pausedRemaining = 0
        state = .finished
        onFinish?(totalDuration)
    }

    private func stopTimer() {
        finishTimer?.invalidate()
        finishTimer = nil
        endDate = nil
    }
}
