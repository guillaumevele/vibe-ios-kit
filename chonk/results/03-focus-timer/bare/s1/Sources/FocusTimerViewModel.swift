// FILE: FocusTimerViewModel.swift
import Foundation
import Observation
import UIKit

@Observable
final class FocusTimerViewModel {
    enum Phase: Equatable {
        case idle, running, paused, finished
    }

    var phase: Phase = .idle
    var title: String = "Focus"
    var plannedDuration: TimeInterval = 25 * 60
    var remaining: TimeInterval = 25 * 60

    private var endDate: Date = .now
    private var timer: Timer?
    private var onSessionEnded: ((TimeInterval, Bool) -> Void)?
    private var foregroundObserver: NSObjectProtocol?

    /// Fraction of the ring that is still filled (1 = full, 0 = empty).
    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        return min(1, max(0, remaining / plannedDuration))
    }

    init() {
        // Re-sync against the wall clock when the app returns to the foreground,
        // since scheduled timers do not fire while backgrounded.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resync()
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        timer?.invalidate()
    }

    /// Called by the view to receive finished / ended-early sessions.
    func attach(onSessionEnded: @escaping (TimeInterval, Bool) -> Void) {
        self.onSessionEnded = onSessionEnded
    }

    func selectDuration(_ duration: TimeInterval) {
        guard phase == .idle else { return }
        plannedDuration = duration
        remaining = duration
    }

    func start() {
        guard phase == .idle || phase == .paused else { return }
        if phase == .idle {
            remaining = plannedDuration
        }
        endDate = Date().addingTimeInterval(remaining)
        phase = .running
        scheduleTimer()
    }

    func pause() {
        guard phase == .running else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        invalidateTimer()
        phase = .paused
    }

    /// End the session now and record it as incomplete.
    func endEarly() {
        guard phase == .running || phase == .paused else { return }
        let elapsed = max(1, plannedDuration - remaining)
        invalidateTimer()
        onSessionEnded?(elapsed, false)
        phase = .idle
        remaining = plannedDuration
    }

    /// Discard the current run without recording anything.
    func reset() {
        invalidateTimer()
        phase = .idle
        remaining = plannedDuration
    }

    /// Called after the celebration is dismissed.
    func dismissFinished() {
        phase = .idle
        remaining = plannedDuration
    }

    /// Recompute remaining time from the wall clock (background-safe).
    func resync() {
        guard phase == .running else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            complete()
        }
    }

    private func scheduleTimer() {
        invalidateTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            complete()
        }
    }

    private func complete() {
        invalidateTimer()
        remaining = 0
        phase = .finished
        onSessionEnded?(plannedDuration, true)
    }
}
