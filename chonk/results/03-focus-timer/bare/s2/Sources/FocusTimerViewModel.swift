// FILE: FocusTimerViewModel.swift
import Foundation
import Observation
import UIKit

enum TimerPhase: Equatable, Sendable {
    case idle
    case running
    case paused
    case finished
}

@Observable
final class FocusTimerViewModel {
    // MARK: - Configuration

    let presets: [TimeInterval] = [5, 10, 15, 25, 45, 60].map { $0 * 60 }

    var title: String = "Deep work"

    var selectedDuration: TimeInterval = 25 * 60 {
        didSet {
            if phase == .idle {
                remaining = selectedDuration
            }
        }
    }

    // MARK: - State

    private(set) var phase: TimerPhase = .idle
    private(set) var remaining: TimeInterval = 25 * 60

    // MARK: - Derived values

    var progress: Double {
        guard selectedDuration > 0 else { return 0 }
        return min(1, max(0, remaining / selectedDuration))
    }

    var isActive: Bool {
        phase == .running || phase == .paused
    }

    var timeText: String {
        FocusFormat.countdown(remaining)
    }

    var subtitle: String {
        switch phase {
        case .idle: return "\(Int(selectedDuration / 60)) min session"
        case .running: return "Stay focused"
        case .paused: return "Paused"
        case .finished: return "Done"
        }
    }

    // MARK: - Private

    private var endDate: Date?
    private var ticker: Timer?
    private let store: SessionStore
    private let notifications = FocusNotificationService()

    init(store: SessionStore) {
        self.store = store
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        ticker?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Controls

    func selectDuration(_ duration: TimeInterval) {
        selectedDuration = duration
    }

    func start() {
        remaining = selectedDuration
        begin()
    }

    func pause() {
        guard phase == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        phase = .paused
        stopTicker()
        notifications.cancel()
    }

    func resume() {
        guard phase == .paused else { return }
        begin()
    }

    func reset() {
        stopTicker()
        notifications.cancel()
        phase = .idle
        remaining = selectedDuration
        endDate = nil
    }

    /// Ends the session now and records the elapsed time as a partial session.
    func endEarly() {
        guard isActive else { return }
        recordSession(actual: selectedDuration - remaining, completed: false)
        finish()
    }

    func requestNotificationAuthorization() {
        notifications.requestAuthorization()
    }

    /// Recomputes remaining time from the wall clock (e.g. after returning from background).
    func syncWithClock() {
        guard phase == .running, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            complete()
        } else {
            remaining = left
        }
    }

    // MARK: - Private

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Focus session" : trimmed
    }

    private func begin() {
        phase = .running
        endDate = Date().addingTimeInterval(remaining)
        startTicker()
        notifications.scheduleCompletion(at: endDate!, title: resolvedTitle)
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard phase == .running, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            complete()
        } else {
            remaining = left
        }
    }

    private func complete() {
        stopTicker()
        notifications.cancel()
        recordSession(actual: selectedDuration, completed: true)
        finish()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func finish() {
        stopTicker()
        notifications.cancel()
        remaining = 0
        phase = .finished
        endDate = nil
    }

    private func recordSession(actual: TimeInterval, completed: Bool) {
        let now = Date()
        let elapsed = max(0, actual)
        store.add(FocusSession(
            title: resolvedTitle,
            plannedDuration: selectedDuration,
            actualDuration: elapsed,
            startedAt: now.addingTimeInterval(-elapsed),
            endedAt: now,
            completed: completed
        ))
    }

    @objc private func handleDidBecomeActive() {
        syncWithClock()
    }
}
